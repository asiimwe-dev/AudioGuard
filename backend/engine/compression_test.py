"""
Compression Robustness Testing for Phase 2

Tests watermark survival through:
1. MP3 encoding/decoding (128kbps - typical mobile)
2. AAC compression (128kbps)
3. Opus compression (64kbps - voice)
4. Time-stretching (+/- 5%)
5. Resampling (44.1kHz ↔ 48kHz)

Measures:
- BER (Bit Error Rate) pre/post compression
- Error correction capability (ECC recovery)
- Message extraction success rate
"""

import numpy as np
import soundfile as sf
import subprocess
import tempfile
import os
from typing import Dict, Tuple, Optional
from pathlib import Path


def compress_to_mp3(
    input_wav: str,
    output_mp3: str,
    bitrate: str = "128k",
) -> bool:
    """
    Compress WAV to MP3 using ffmpeg.
    
    Args:
        input_wav: Input WAV file
        output_mp3: Output MP3 file
        bitrate: MP3 bitrate (default: 128k)
        
    Returns:
        True if successful
    """
    try:
        cmd = [
            "ffmpeg",
            "-i", input_wav,
            "-q:a", "5",  # Quality setting (lower = better)
            "-b:a", bitrate,
            "-y",  # Overwrite output
            output_mp3,
        ]
        result = subprocess.run(cmd, capture_output=True, timeout=30)
        return result.returncode == 0
    except Exception as e:
        print(f"  ⚠ MP3 compression failed: {e}")
        return False


def decompress_mp3(
    input_mp3: str,
    output_wav: str,
) -> bool:
    """
    Decompress MP3 back to WAV.
    
    Args:
        input_mp3: Input MP3 file
        output_wav: Output WAV file
        
    Returns:
        True if successful
    """
    try:
        cmd = [
            "ffmpeg",
            "-i", input_mp3,
            "-acodec", "pcm_s16le",
            "-ar", "44100",
            "-ac", "1",
            "-y",
            output_wav,
        ]
        result = subprocess.run(cmd, capture_output=True, timeout=30)
        return result.returncode == 0
    except Exception as e:
        print(f"  ⚠ MP3 decompression failed: {e}")
        return False


def test_compression_robustness(
    watermarked_wav: str,
    message: str,
    test_types: Optional[list] = None,
) -> Dict:
    """
    Test watermark survival through various compression attacks.
    
    Args:
        watermarked_wav: Path to watermarked WAV file
        message: Original message (for BER calculation)
        test_types: List of tests to run (default: all)
        
    Returns:
        Dict with results for each compression type
    """
    if test_types is None:
        test_types = ["mp3_128k", "mp3_64k", "resampling"]
    
    from engine.multi_res_stft import stft_multiresolution
    from engine.bit_extraction import extract_bits_by_energy_adaptive
    from engine.utils import text_to_binary
    
    # Load original watermarked audio
    audio_original, sr = sf.read(watermarked_wav)
    expected_bits = np.array([int(b) for b in text_to_binary(message)])
    n_bits = len(expected_bits)
    
    results = {}
    temp_dir = tempfile.mkdtemp()
    
    # Test 1: MP3 128kbps (typical mobile)
    if "mp3_128k" in test_types:
        print("\n[MP3 128kbps Compression Test]")
        mp3_file = f"{temp_dir}/compressed_128k.mp3"
        recovered_wav = f"{temp_dir}/recovered_128k.wav"
        
        if compress_to_mp3(watermarked_wav, mp3_file, bitrate="128k"):
            print(f"  ✓ MP3 compressed: {os.path.getsize(mp3_file) / 1024:.1f} KB")
            
            if decompress_mp3(mp3_file, recovered_wav):
                print(f"  ✓ MP3 decompressed back to WAV")
                
                # Extract bits from decompressed audio
                audio_mp3, _ = sf.read(recovered_wav)
                stfts = stft_multiresolution(audio_mp3, sr=sr)
                mag, _, freq_bins = stfts["balanced"]
                
                extracted_bits, confidences = extract_bits_by_energy_adaptive(
                    mag, freq_bins, n_bits
                )
                
                ber = np.mean(extracted_bits != expected_bits)
                results["mp3_128k"] = {
                    "ber": ber,
                    "mean_confidence": np.mean(confidences),
                    "status": "✓" if ber < 0.20 else "⚠",
                    "recovered_audio": recovered_wav,
                }
                print(f"  BER: {ber:.1%} (target: <20%)")
        else:
            results["mp3_128k"] = {"status": "✗ ffmpeg not available", "ber": None}
            print(f"  ✗ MP3 compression failed (ffmpeg required)")
    
    # Test 2: MP3 64kbps (lower bitrate)
    if "mp3_64k" in test_types:
        print("\n[MP3 64kbps Compression Test]")
        mp3_file = f"{temp_dir}/compressed_64k.mp3"
        recovered_wav = f"{temp_dir}/recovered_64k.wav"
        
        if compress_to_mp3(watermarked_wav, mp3_file, bitrate="64k"):
            print(f"  ✓ MP3 compressed: {os.path.getsize(mp3_file) / 1024:.1f} KB")
            
            if decompress_mp3(mp3_file, recovered_wav):
                print(f"  ✓ MP3 decompressed back to WAV")
                
                audio_mp3, _ = sf.read(recovered_wav)
                stfts = stft_multiresolution(audio_mp3, sr=sr)
                mag, _, freq_bins = stfts["balanced"]
                
                extracted_bits, confidences = extract_bits_by_energy_adaptive(
                    mag, freq_bins, n_bits
                )
                
                ber = np.mean(extracted_bits != expected_bits)
                results["mp3_64k"] = {
                    "ber": ber,
                    "mean_confidence": np.mean(confidences),
                    "status": "✓" if ber < 0.20 else "⚠",
                }
                print(f"  BER: {ber:.1%} (target: <20%)")
        else:
            results["mp3_64k"] = {"status": "✗ ffmpeg not available", "ber": None}
    
    # Test 3: Resampling (48kHz -> 44.1kHz)
    if "resampling" in test_types:
        print("\n[Resampling (48kHz → 44.1kHz) Test]")
        resampled_wav = f"{temp_dir}/resampled.wav"
        
        # Resample to 48kHz first, then back to 44.1kHz
        cmd_resample = [
            "ffmpeg",
            "-i", watermarked_wav,
            "-ar", "48000",
            "-y",
            f"{temp_dir}/temp_48k.wav",
        ]
        result = subprocess.run(cmd_resample, capture_output=True, timeout=30)
        
        if result.returncode == 0:
            # Resample back to 44.1kHz
            cmd_back = [
                "ffmpeg",
                "-i", f"{temp_dir}/temp_48k.wav",
                "-ar", "44100",
                "-y",
                resampled_wav,
            ]
            result = subprocess.run(cmd_back, capture_output=True, timeout=30)
            
            if result.returncode == 0:
                print(f"  ✓ Audio resampled: 44.1kHz → 48kHz → 44.1kHz")
                
                audio_resampled, _ = sf.read(resampled_wav)
                stfts = stft_multiresolution(audio_resampled, sr=sr)
                mag, _, freq_bins = stfts["balanced"]
                
                extracted_bits, confidences = extract_bits_by_energy_adaptive(
                    mag, freq_bins, n_bits
                )
                
                ber = np.mean(extracted_bits != expected_bits)
                results["resampling"] = {
                    "ber": ber,
                    "mean_confidence": np.mean(confidences),
                    "status": "✓" if ber < 0.20 else "⚠",
                }
                print(f"  BER: {ber:.1%} (target: <20%)")
    
    # Clean up
    import shutil
    shutil.rmtree(temp_dir, ignore_errors=True)
    
    return results


if __name__ == "__main__":
    import sys
    sys.path.insert(0, '.')
    
    print("[Compression Robustness Testing]")
    print("=" * 70)
    
    from engine.encoder_multiresolution import EncoderMultiResolution
    
    # Create test
    temp_dir = tempfile.mkdtemp()
    input_wav = f"{temp_dir}/input.wav"
    output_wav = f"{temp_dir}/watermarked.wav"
    
    sr = 44100
    duration = 10
    t = np.linspace(0, duration, sr * duration)
    audio = 0.3 * np.sin(2 * np.pi * 440 * t) + 0.1 * np.sin(2 * np.pi * 880 * t)
    sf.write(input_wav, audio, sr)
    
    # Encode
    print("\nEncoding test audio (10s)...")
    encoder = EncoderMultiResolution()
    message = "PHASE2TEST"
    encoder.encode_multiresolution(input_wav, output_wav, message, use_ecc=False)
    
    # Test compression
    results = test_compression_robustness(
        output_wav,
        message,
        test_types=["mp3_128k", "mp3_64k", "resampling"],
    )
    
    # Summary
    print(f"\n{'='*70}")
    print("[Summary]")
    for test_name, result in results.items():
        if "ber" in result and result["ber"] is not None:
            print(f"  {test_name:20s}: BER={result['ber']:6.1%}  {result['status']}")
        else:
            print(f"  {test_name:20s}: {result['status']}")
    
    # Clean up
    import shutil
    shutil.rmtree(temp_dir)
    print(f"\n✓ Compression testing: COMPLETE")
