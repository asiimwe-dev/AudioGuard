"""
AudioGuard CLI

Usage examples:
  audioguard encode -i music.wav -o watermarked.wav -m "ARTIST_001"
  audioguard decode -i watermarked.wav
  audioguard verify -i watermarked.wav
  audioguard analyse -i unknown.wav
  audioguard batch -d ./tracks -m "LABEL_2025" --output-dir ./out
"""

from __future__ import annotations

import json
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional

import click
import numpy as np
import soundfile as sf


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _ok(msg: str) -> None:  click.echo(f"\033[92m✓\033[0m {msg}")
def _err(msg: str) -> None: click.echo(f"\033[91m✗\033[0m {msg}", err=True)
def _info(msg: str) -> None: click.echo(f"\033[94mℹ\033[0m {msg}")
def _warn(msg: str) -> None: click.echo(f"\033[93m⚠\033[0m {msg}")


def _emit(data: dict, as_json: bool) -> None:
    if as_json:
        click.echo(json.dumps(data, indent=2, default=str))


# ---------------------------------------------------------------------------
# CLI group
# ---------------------------------------------------------------------------

@click.group()
@click.version_option("2.0.0", prog_name="AudioGuard")
def cli():
    """AudioGuard — High-fidelity audio watermarking."""


# ---------------------------------------------------------------------------
# encode
# ---------------------------------------------------------------------------

@cli.command()
@click.option("-i", "--input",  "src",  required=True, help="Input audio file")
@click.option("-o", "--output", "dst",  required=True, help="Output watermarked file")
@click.option("-m", "--message",        required=True, help="Message to embed (1-200 chars)")
@click.option("-a", "--amplitude", default=0.08, type=float, show_default=True,
              help="Watermark strength (0.01-1.0)")
@click.option("--seed", default=42, type=int, show_default=True)
@click.option("--redundancy", default=3, type=int, show_default=True,
              help="Number of redundant copies embedded")
@click.option("--json", "as_json", is_flag=True, help="Machine-readable output")
def encode(src, dst, message, amplitude, seed, redundancy, as_json):
    """Embed a watermark into an audio file."""
    from core.watermarker import Watermarker, WatermarkConfig

    if not Path(src).exists():
        _err(f"Input not found: {src}")
        sys.exit(1)
    if not (1 <= len(message.strip()) <= 200):
        _err("Message must be 1-200 non-whitespace characters")
        sys.exit(1)

    if not as_json:
        _info(f"Encoding '{message}' → {dst}")

    wm = Watermarker(WatermarkConfig(
        amplitude_factor=amplitude, seed=seed, redundancy=redundancy,
    ))
    result = wm.encode(src, dst, message)

    if as_json:
        _emit(asdict(result), True)
        sys.exit(0 if result.success else 1)

    if result.success:
        _ok(f"Watermark embedded  SNR={result.snr_db:.1f} dB  ({result.processing_time_ms:.0f} ms)")
        _info(f"Output: {dst}")
    else:
        _err(f"Encoding failed: {result.error}")
        sys.exit(1)


# ---------------------------------------------------------------------------
# decode
# ---------------------------------------------------------------------------

@cli.command()
@click.option("-i", "--input", "src", required=True)
@click.option("--seed", default=42, type=int, show_default=True)
@click.option("--json", "as_json", is_flag=True)
def decode(src, seed, as_json):
    """Extract watermark from an audio file."""
    from core.watermarker import Watermarker, WatermarkConfig

    if not Path(src).exists():
        _err(f"Input not found: {src}")
        sys.exit(1)

    wm = Watermarker(WatermarkConfig(seed=seed))
    result = wm.decode(src)

    if as_json:
        _emit(asdict(result), True)
        sys.exit(0 if result.success else 1)

    if result.success:
        _ok(f"Message: '{result.message}'")
        _info(f"Confidence: {result.confidence:.1%}  BER: {result.ber_estimate:.1%}  "
              f"SNR: {result.snr_db:.1f} dB  ({result.processing_time_ms:.0f} ms)")
    else:
        _warn("No watermark detected")
        _info(f"Confidence: {result.confidence:.1%}  ({result.processing_time_ms:.0f} ms)")
        sys.exit(1)


# ---------------------------------------------------------------------------
# verify
# ---------------------------------------------------------------------------

@cli.command()
@click.option("-i", "--input", "src", required=True)
@click.option("--threshold", default=0.60, type=float, show_default=True,
              help="Confidence threshold for positive detection")
@click.option("--json", "as_json", is_flag=True)
def verify(src, threshold, as_json):
    """Quick binary watermark presence check."""
    from core.watermarker import Watermarker, WatermarkConfig

    if not Path(src).exists():
        _err(f"Input not found: {src}")
        sys.exit(1)

    wm = Watermarker(WatermarkConfig())
    result = wm.decode(src)
    detected = result.sync_found and result.confidence >= threshold
    verdict = "watermarked" if detected else (
        "possibly_tampered" if result.sync_found else "not_watermarked"
    )

    if as_json:
        _emit({"verdict": verdict, "confidence": result.confidence,
               "watermark_detected": detected}, True)
        sys.exit(0 if detected else 1)

    if detected:
        _ok(f"Watermark detected  ({result.confidence:.0%} confidence)")
    elif result.sync_found:
        _warn(f"Sync found but confidence low — possibly tampered")
    else:
        _warn("No watermark detected")


# ---------------------------------------------------------------------------
# analyse
# ---------------------------------------------------------------------------

@cli.command()
@click.option("-i", "--input", "src", required=True)
@click.option("--json", "as_json", is_flag=True)
def analyse(src, as_json):
    """Full spectral + watermark analysis report."""
    from core.watermarker import Watermarker, WatermarkConfig

    if not Path(src).exists():
        _err(f"Input not found: {src}")
        sys.exit(1)

    audio, sr = sf.read(src, dtype="float32")
    if audio.ndim > 1:
        audio = audio.mean(axis=1)

    rms = float(np.sqrt(np.mean(audio ** 2)))
    peak = float(np.max(np.abs(audio)))

    wm = Watermarker(WatermarkConfig())
    decode_result = wm.decode(src)

    report = {
        "file": src,
        "duration_s": len(audio) / sr,
        "sample_rate": sr,
        "rms": rms,
        "peak_db": float(20 * np.log10(peak + 1e-10)),
        "dynamic_range_db": float(20 * np.log10(peak / (rms + 1e-10))),
        "watermark_detected": decode_result.sync_found,
        "watermark_message": decode_result.message if decode_result.success else None,
        "watermark_confidence": decode_result.confidence,
        "estimated_snr_db": decode_result.snr_db,
    }

    if as_json:
        _emit(report, True)
        return

    _info(f"File:          {src}")
    _info(f"Duration:      {report['duration_s']:.2f}s  @  {sr} Hz")
    _info(f"Peak:          {report['peak_db']:.1f} dBFS")
    _info(f"Dynamic range: {report['dynamic_range_db']:.1f} dB")
    if decode_result.sync_found:
        _ok(f"Watermark: '{decode_result.message}'  ({decode_result.confidence:.0%} confidence)")
    else:
        _warn("No watermark detected")


# ---------------------------------------------------------------------------
# batch
# ---------------------------------------------------------------------------

@cli.command()
@click.option("-d", "--directory", required=True)
@click.option("-m", "--message",   required=True)
@click.option("--output-dir", default="./watermarked", show_default=True)
@click.option("-a", "--amplitude", default=0.08, type=float, show_default=True)
@click.option("--json", "as_json", is_flag=True)
def batch(directory, message, output_dir, amplitude, as_json):
    """Process multiple audio files in parallel."""
    from core.watermarker import Watermarker, WatermarkConfig
    from concurrent.futures import ThreadPoolExecutor, as_completed

    dir_path = Path(directory)
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    AUDIO_EXTS = {".wav", ".mp3", ".flac", ".ogg", ".m4a"}
    files = [f for f in dir_path.rglob("*") if f.suffix.lower() in AUDIO_EXTS]

    if not files:
        _warn(f"No audio files found in {directory}")
        sys.exit(0)

    wm = Watermarker(WatermarkConfig(amplitude_factor=amplitude))
    results = []

    def process(f: Path):
        out = out_dir / f"wm_{f.stem}.wav"
        r = wm.encode(str(f), str(out), message)
        return {"input": str(f), "output": str(out), "success": r.success,
                "snr_db": r.snr_db, "error": r.error}

    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(process, f): f for f in files}
        for i, fut in enumerate(as_completed(futures), 1):
            res = fut.result()
            results.append(res)
            if not as_json:
                status = "✓" if res["success"] else "✗"
                click.echo(f"[{i}/{len(files)}] {status} {Path(res['input']).name}")

    if as_json:
        _emit(results, True)
    else:
        ok = sum(1 for r in results if r["success"])
        _ok(f"Batch complete: {ok}/{len(results)} successful")


if __name__ == "__main__":
    cli()
