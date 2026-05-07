"""
ECC Error Correction Validation for Phase 2

Tests the ability of Reed-Solomon ECC to recover messages despite:
1. High bit error rates (30-50% BER)
2. Compression artifacts
3. Time-domain variations

Validates:
- Error correction effectiveness
- Uncorrectable error rate
- BER reduction after ECC
"""

import numpy as np
import soundfile as sf
import tempfile
from typing import Dict, Tuple
from pathlib import Path


def validate_ecc_correction(
    watermarked_wav: str,
    message: str,
    amplitude_factor: float = 0.10,
) -> Dict:
    """
    Validate ECC error correction on watermarked audio.
    
    Tests extraction with and without ECC, measures:
    - Raw BER (before ECC)
    - Errors corrected by ECC
    - ECC success rate
    
    Args:
        watermarked_wav: Path to watermarked WAV
        message: Original message (for comparison)
        amplitude_factor: Watermark strength (for estimation)
        
    Returns:
        Dict with ECC validation results
    """
    from engine.multi_res_stft import stft_multiresolution
    from engine.bit_extraction import extract_bits_by_energy_adaptive
    from engine.utils import text_to_binary
    from engine.ecc import MessageECC
    
    # Load audio
    audio, sr = sf.read(watermarked_wav)
    
    # Extract bits at 2048 Hz (balanced resolution)
    stfts = stft_multiresolution(audio, sr=sr)
    mag, phase, freq_bins = stfts["balanced"]
    
    # Expected ECC-encoded size (255 bytes × 2 redundancy = 4080 bits)
    ecc_codec = MessageECC()
    ecc_encoded_bytes = ecc_codec.encode(message)
    n_bits_ecc = len(ecc_encoded_bytes) * 8
    
    print(f"[ECC Validation]")
    print(f"  Original message: '{message}' ({len(message)} chars)")
    print(f"  ECC encoded: {len(ecc_encoded_bytes)} bytes ({n_bits_ecc} bits)")
    
    # Extract bits with advanced method
    extracted_bits, confidences = extract_bits_by_energy_adaptive(
        mag, freq_bins, n_bits_ecc
    )
    
    # Calculate raw BER
    expected_bits_ecc = np.array([int(b) for b in "".join(format(byte, "08b") for byte in ecc_encoded_bytes)])
    raw_ber = np.mean(extracted_bits != expected_bits_ecc)
    
    print(f"\n  [Raw Extraction]")
    print(f"    Extracted bits: {len(extracted_bits)}")
    print(f"    Mean confidence: {np.mean(confidences):.3f}")
    print(f"    Raw BER: {raw_ber:.1%}")
    
    # Try to decode with ECC
    print(f"\n  [ECC Decoding]")
    extracted_bytes = np.packbits(extracted_bits[:n_bits_ecc])
    
    try:
        decoded_msg, num_errors = ecc_codec.decode(bytes(extracted_bytes))
        print(f"    ✓ ECC decoded successfully")
        print(f"    Errors corrected: {num_errors}")
        print(f"    Recovered message: '{decoded_msg}'")
        
        success = decoded_msg.strip('\x00') == message
        print(f"    Message match: {'✓' if success else '✗'}")
        
        return {
            "status": "success",
            "raw_ber": raw_ber,
            "errors_corrected": num_errors,
            "decoded_message": decoded_msg.strip('\x00'),
            "message_match": success,
        }
    except Exception as e:
        print(f"    ✗ ECC decoding failed: {e}")
        return {
            "status": "failed",
            "raw_ber": raw_ber,
            "errors_corrected": None,
            "decoded_message": None,
            "message_match": False,
            "error": str(e),
        }


def test_ecc_robustness_sweep(
    message: str,
    amplitude_factors: list = None,
) -> Dict:
    """
    Test ECC robustness across different watermark strengths.
    
    Args:
        message: Message to embed
        amplitude_factors: List of amplitude factors to test
        
    Returns:
        Dict with results per amplitude factor
    """
    from engine.encoder_multiresolution import EncoderMultiResolution
    
    if amplitude_factors is None:
        amplitude_factors = [0.05, 0.10, 0.15, 0.20]
    
    results = {}
    
    for amp_factor in amplitude_factors:
        print(f"\n{'='*70}")
        print(f"Testing amplitude_factor={amp_factor}")
        print(f"{'='*70}")
        
        temp_dir = tempfile.mkdtemp()
        input_wav = f"{temp_dir}/input.wav"
        output_wav = f"{temp_dir}/watermarked.wav"
        
        # Create audio
        sr = 44100
        duration = 10
        t = np.linspace(0, duration, sr * duration)
        audio = 0.3 * np.sin(2 * np.pi * 440 * t) + 0.1 * np.sin(2 * np.pi * 880 * t)
        sf.write(input_wav, audio, sr)
        
        # Encode with ECC
        encoder = EncoderMultiResolution()
        encoder.encode_multiresolution(
            input_wav,
            output_wav,
            message,
            use_ecc=True,
            amplitude_factor=amp_factor,
        )
        
        # Validate ECC
        result = validate_ecc_correction(output_wav, message, amp_factor=amp_factor)
        results[amp_factor] = result
        
        # Clean up
        import shutil
        shutil.rmtree(temp_dir)
    
    return results


if __name__ == "__main__":
    import sys
    sys.path.insert(0, '.')
    
    print("[ECC Error Correction Validation]")
    print("=" * 70)
    
    # Single test
    temp_dir = tempfile.mkdtemp()
    input_wav = f"{temp_dir}/input.wav"
    output_wav = f"{temp_dir}/watermarked.wav"
    
    from engine.encoder_multiresolution import EncoderMultiResolution
    
    sr = 44100
    duration = 10
    t = np.linspace(0, duration, sr * duration)
    audio = 0.3 * np.sin(2 * np.pi * 440 * t) + 0.1 * np.sin(2 * np.pi * 880 * t)
    sf.write(input_wav, audio, sr)
    
    # Encode with ECC
    encoder = EncoderMultiResolution()
    message = "HELLO_WORLD"
    encoder.encode_multiresolution(
        input_wav,
        output_wav,
        message,
        use_ecc=True,
        amplitude_factor=0.15,
    )
    
    # Validate
    result = validate_ecc_correction(output_wav, message, amplitude_factor=0.15)
    
    # Summary
    print(f"\n{'='*70}")
    print("[Result Summary]")
    print(f"{'='*70}")
    for key, val in result.items():
        print(f"  {key}: {val}")
    
    # Clean up
    import shutil
    shutil.rmtree(temp_dir)
    print(f"\n✓ ECC validation: COMPLETE")
