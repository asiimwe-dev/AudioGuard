"""
AudioGuard Command-Line Interface (Phase 4)

Production-ready CLI tool for encoding, decoding, verifying, and analyzing watermarked audio.
Integrates Phase 1 (Encoder), Phase 2 (Decoder, ISO226), and Phase 3 (CNN fallback).

Usage:
    audioguard encode -i input.wav -o output.wav -m "AUTHOR_ID"
    audioguard decode -i watermarked.wav
    audioguard verify -i watermarked.wav
    audioguard analyze -i watermarked.wav
    audioguard batch -d ./audio_dir -m "MSG" --output-dir ./watermarked
    audioguard config --api-key YOUR_KEY --api-url https://api.audioguard.io
"""

import click
import json
import sys
import time
from pathlib import Path
from typing import Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime
import logging

import soundfile as sf
import numpy as np

from engine import AudioGuardEncoder, AudioGuardDecoder

try:
    from engine import CNNWatermarkDecoder
    CNN_AVAILABLE = True
except ImportError:
    CNN_AVAILABLE = False

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# Colored output
class Colors:
    """ANSI color codes."""
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


def print_success(msg: str):
    """Print success message."""
    click.echo(f"{Colors.GREEN}✓{Colors.RESET} {msg}")


def print_error(msg: str):
    """Print error message."""
    click.echo(f"{Colors.RED}✗{Colors.RESET} {msg}")


def print_info(msg: str):
    """Print info message."""
    click.echo(f"{Colors.BLUE}ℹ{Colors.RESET} {msg}")


def print_warning(msg: str):
    """Print warning message."""
    click.echo(f"{Colors.YELLOW}⚠{Colors.RESET} {msg}")


@dataclass
class EncodeResult:
    """Encoding result data class."""
    success: bool
    input_file: str
    output_file: str
    message: str
    message_length: int
    duration: float
    sample_rate: int
    amplitude_factor: float
    processing_time_ms: float


@dataclass
class DecodeResult:
    """Decoding result data class."""
    success: bool
    file: str
    message: Optional[str]
    confidence: float
    method: str
    snr_db: Optional[float]
    processing_time_ms: float


@dataclass
class VerifyResult:
    """Verification result data class."""
    success: bool
    file: str
    watermark_detected: bool
    confidence: float
    processing_time_ms: float


@click.group()
@click.version_option(version="1.0.0", prog_name="AudioGuard")
def cli():
    """
    AudioGuard: High-Fidelity Audio Watermarking for AI Attribution

    Embed, detect, and verify digital signatures in audio files.
    Survives compression, noise, and typical audio processing.
    """
    pass


@cli.command()
@click.option("-i", "--input", "input_file", required=True, help="Input audio file")
@click.option("-o", "--output", "output_file", required=True, help="Output watermarked file")
@click.option("-m", "--message", required=True, help="Message to embed (1-255 chars)")
@click.option("-a", "--amplitude", default=0.05, type=float, help="Watermark strength (0.01-1.0)")
@click.option("--frame-size", default=2048, type=int, help="STFT frame size")
@click.option("--bits-per-frame", default=4, type=int, help="Redundancy factor")
@click.option("--seed", default=42, type=int, help="Random seed for reproducibility")
@click.option("--json", "output_json", is_flag=True, help="Output result as JSON")
def encode(input_file, output_file, message, amplitude, frame_size, bits_per_frame, seed, output_json):
    """Embed watermark in audio file."""
    try:
        # Validate inputs
        input_path = Path(input_file)
        if not input_path.exists():
            print_error(f"Input file not found: {input_file}")
            sys.exit(1)

        if not (1 <= len(message) <= 255):
            print_error("Message length must be 1-255 characters")
            sys.exit(1)

        if not (0.01 <= amplitude <= 1.0):
            print_error("Amplitude must be between 0.01 and 1.0")
            sys.exit(1)

        # Show progress
        if not output_json:
            print_info(f"Encoding '{message}' into {input_file}...")

        start_time = time.time()

        # Encode
        encoder = AudioGuardEncoder(
            frame_size=frame_size,
            amplitude_factor=amplitude,
            seed=seed,
        )

        metadata = encoder.encode(
            str(input_path),
            str(output_file),
            message,
            bits_per_frame=bits_per_frame,
        )

        processing_time = (time.time() - start_time) * 1000

        # Load audio to get metadata
        audio_data, sr = sf.read(str(input_path))
        duration = len(audio_data) / sr

        result = EncodeResult(
            success=True,
            input_file=str(input_path),
            output_file=str(output_file),
            message=message,
            message_length=len(message),
            duration=duration,
            sample_rate=sr,
            amplitude_factor=amplitude,
            processing_time_ms=processing_time,
        )

        if output_json:
            click.echo(json.dumps(asdict(result), indent=2))
        else:
            print_success(f"Watermark embedded successfully")
            print_info(f"Output: {output_file}")
            print_info(f"Message: {message} ({len(message)} chars)")
            print_info(f"Duration: {duration:.2f}s @ {sr}Hz")
            print_info(f"Strength: {amplitude:.3f} (amplitude factor)")
            print_info(f"Time: {processing_time:.1f}ms")

    except Exception as e:
        if output_json:
            click.echo(json.dumps({
                "success": False,
                "error": str(e),
            }, indent=2))
        else:
            print_error(f"Encoding failed: {str(e)}")
        sys.exit(1)


@cli.command()
@click.option("-i", "--input", "input_file", required=True, help="Watermarked audio file")
@click.option("-l", "--message-length", "message_length", type=int, default=None, help="Expected message length (optional)")
@click.option("--use-cnn", is_flag=True, help="Use CNN decoder for degraded audio")
@click.option("--json", "output_json", is_flag=True, help="Output result as JSON")
def decode(input_file, message_length, use_cnn, output_json):
    """Extract watermark from audio file."""
    try:
        input_path = Path(input_file)
        if not input_path.exists():
            print_error(f"Input file not found: {input_file}")
            sys.exit(1)

        if not output_json:
            print_info(f"Decoding watermark from {input_file}...")

        start_time = time.time()

        # If message_length not provided, try all reasonable lengths (1-32)
        if message_length is None:
            best_message = None
            best_confidence = 0.0
            best_snr = None
            method = "classical"

            decoder = AudioGuardDecoder()
            for length in range(1, 33):
                try:
                    result = decoder.decode(str(input_path), length)
                    if result["confidence"] > best_confidence:
                        best_message = result["message"]
                        best_confidence = result["confidence"]
                        best_snr = result["snr_db"]
                except Exception:
                    continue

            message = best_message
            confidence = best_confidence
            snr = best_snr
        else:
            # Decode with specified message length
            decoder = AudioGuardDecoder()
            result = decoder.decode(str(input_path), message_length)
            message = result.get("message")
            confidence = result.get("confidence", 0.0)
            snr = result.get("snr_db")
            method = "classical"

        # Fallback to CNN if requested and classical failed
        if use_cnn and CNN_AVAILABLE and (message is None or confidence < 0.5):
            if not output_json:
                print_info("Classical decoder failed, trying CNN...")
            try:
                cnn_decoder = CNNWatermarkDecoder()
                message, confidence = cnn_decoder.decode(str(input_path))
                method = "cnn"
                snr = None
            except Exception as e:
                logger.warning(f"CNN decoding failed: {str(e)}")

        processing_time = (time.time() - start_time) * 1000

        result = DecodeResult(
            success=message is not None,
            file=str(input_path),
            message=message,
            confidence=confidence,
            method=method,
            snr_db=snr,
            processing_time_ms=processing_time,
        )

        if output_json:
            click.echo(json.dumps(asdict(result), indent=2))
        else:
            if message:
                print_success(f"Watermark detected: '{message}'")
                print_info(f"Confidence: {confidence:.1%}")
                print_info(f"Method: {method}")
                if snr is not None:
                    print_info(f"SNR: {snr:.2f} dB")
            else:
                print_warning(f"No watermark detected")
                print_info(f"Confidence: {confidence:.1%}")
            print_info(f"Time: {processing_time:.1f}ms")

    except Exception as e:
        if output_json:
            click.echo(json.dumps({
                "success": False,
                "error": str(e),
            }, indent=2))
        else:
            print_error(f"Decoding failed: {str(e)}")
        sys.exit(1)


@cli.command()
@click.option("-i", "--input", "input_file", required=True, help="Audio file to verify")
@click.option("--json", "output_json", is_flag=True, help="Output result as JSON")
def verify(input_file, output_json):
    """Check if audio contains watermark (binary classification)."""
    try:
        input_path = Path(input_file)
        if not input_path.exists():
            print_error(f"Input file not found: {input_file}")
            sys.exit(1)

        if not output_json:
            print_info(f"Verifying watermark in {input_file}...")

        start_time = time.time()

        # Use CNN if available, else classical
        if CNN_AVAILABLE:
            try:
                detector = CNNWatermarkDecoder()
                _, confidence = detector.decode(str(input_path))
                watermark_detected = confidence > 0.5
            except Exception:
                decoder = AudioGuardDecoder()
                message, confidence, _ = decoder.decode(str(input_path))
                watermark_detected = message is not None
        else:
            decoder = AudioGuardDecoder()
            message, confidence, _ = decoder.decode(str(input_path))
            watermark_detected = message is not None

        processing_time = (time.time() - start_time) * 1000

        result = VerifyResult(
            success=True,
            file=str(input_path),
            watermark_detected=watermark_detected,
            confidence=confidence,
            processing_time_ms=processing_time,
        )

        if output_json:
            click.echo(json.dumps(asdict(result), indent=2))
        else:
            if watermark_detected:
                print_success(f"Watermark detected")
            else:
                print_warning(f"No watermark detected")
            print_info(f"Confidence: {confidence:.1%}")
            print_info(f"Time: {processing_time:.1f}ms")

    except Exception as e:
        if output_json:
            click.echo(json.dumps({
                "success": False,
                "error": str(e),
            }, indent=2))
        else:
            print_error(f"Verification failed: {str(e)}")
        sys.exit(1)


@cli.command()
@click.option("-i", "--input", "input_file", required=True, help="Audio file to analyze")
@click.option("--json", "output_json", is_flag=True, help="Output result as JSON")
def analyze(input_file, output_json):
    """Analyze audio file properties and watermark presence."""
    try:
        input_path = Path(input_file)
        if not input_path.exists():
            print_error(f"Input file not found: {input_file}")
            sys.exit(1)

        # Load audio
        audio_data, sr = sf.read(str(input_path))
        duration = len(audio_data) / sr

        # Mono conversion
        if len(audio_data.shape) > 1:
            audio_mono = audio_data.mean(axis=1)
        else:
            audio_mono = audio_data

        # Statistics
        rms = np.sqrt(np.mean(audio_mono ** 2))
        peak = np.max(np.abs(audio_mono))
        crest_factor = peak / rms if rms > 0 else 0

        result = {
            "file": str(input_path),
            "duration_seconds": duration,
            "sample_rate": sr,
            "channels": 1 if len(audio_data.shape) == 1 else audio_data.shape[1],
            "samples": len(audio_data),
            "rms": float(rms),
            "peak": float(peak),
            "crest_factor": float(crest_factor),
            "dynamic_range_db": float(20 * np.log10(peak / rms)) if rms > 1e-6 else 0,
        }

        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            print_info(f"File: {input_file}")
            print_info(f"Duration: {duration:.2f}s")
            print_info(f"Sample Rate: {sr}Hz")
            channels = 1 if len(audio_data.shape) == 1 else audio_data.shape[1]
            print_info(f"Channels: {channels}")
            print_info(f"RMS Level: {rms:.4f}")
            print_info(f"Peak Level: {peak:.4f}")
            print_info(f"Crest Factor: {crest_factor:.2f}")
            print_info(f"Dynamic Range: {20 * np.log10(peak / rms) if rms > 1e-6 else 0:.1f}dB")

    except Exception as e:
        if output_json:
            click.echo(json.dumps({
                "success": False,
                "error": str(e),
            }, indent=2))
        else:
            print_error(f"Analysis failed: {str(e)}")
        sys.exit(1)


@cli.command()
@click.option("-d", "--directory", required=True, help="Directory with audio files")
@click.option("-m", "--message", required=True, help="Message to embed")
@click.option("--output-dir", default="./watermarked", help="Output directory")
@click.option("-a", "--amplitude", default=0.05, type=float, help="Watermark strength")
@click.option("--json", "output_json", is_flag=True, help="Output results as JSON")
def batch(directory, message, output_dir, amplitude, output_json):
    """Process multiple audio files in batch."""
    try:
        dir_path = Path(directory)
        if not dir_path.is_dir():
            print_error(f"Directory not found: {directory}")
            sys.exit(1)

        out_dir = Path(output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)

        # Find audio files
        audio_extensions = {".wav", ".mp3", ".flac", ".ogg"}
        audio_files = [
            f for f in dir_path.rglob("*")
            if f.suffix.lower() in audio_extensions
        ]

        if not audio_files:
            print_warning(f"No audio files found in {directory}")
            sys.exit(0)

        results = []
        encoder = AudioGuardEncoder(amplitude_factor=amplitude)

        for i, input_file in enumerate(audio_files, 1):
            try:
                output_file = out_dir / f"watermarked_{input_file.stem}.wav"

                if not output_json:
                    print_info(f"[{i}/{len(audio_files)}] Processing {input_file.name}...")

                encoder.encode(str(input_file), str(output_file), message)

                audio_data, sr = sf.read(str(input_file))
                duration = len(audio_data) / sr

                results.append({
                    "input": str(input_file),
                    "output": str(output_file),
                    "duration": duration,
                    "success": True,
                })

                if not output_json:
                    print_success(f"Processed {input_file.name}")

            except Exception as e:
                results.append({
                    "input": str(input_file),
                    "success": False,
                    "error": str(e),
                })
                if not output_json:
                    print_error(f"Failed to process {input_file.name}: {str(e)}")

        if output_json:
            click.echo(json.dumps(results, indent=2))
        else:
            success = sum(1 for r in results if r.get("success"))
            print_success(f"Batch processing complete: {success}/{len(results)} successful")

    except Exception as e:
        if output_json:
            click.echo(json.dumps({
                "success": False,
                "error": str(e),
            }, indent=2))
        else:
            print_error(f"Batch processing failed: {str(e)}")
        sys.exit(1)


@cli.command()
@click.option("--api-key", help="API key for remote verification")
@click.option("--api-url", help="API URL for remote service")
@click.option("--show", is_flag=True, help="Show current configuration")
def config(api_key, api_url, show):
    """Manage configuration."""
    config_dir = Path.home() / ".audioguard"
    config_file = config_dir / "config.json"

    if show:
        if config_file.exists():
            with open(config_file) as f:
                cfg = json.load(f)
            click.echo(json.dumps(cfg, indent=2))
        else:
            print_warning("No configuration found")
    else:
        config_dir.mkdir(exist_ok=True)

        cfg = {}
        if config_file.exists():
            with open(config_file) as f:
                cfg = json.load(f)

        if api_key:
            cfg["api_key"] = api_key
        if api_url:
            cfg["api_url"] = api_url

        with open(config_file, "w") as f:
            json.dump(cfg, f, indent=2)

        print_success("Configuration saved")


if __name__ == "__main__":
    cli()
