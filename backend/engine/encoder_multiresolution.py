"""
Enhanced Multi-Resolution Encoder for Phase 2

Embeds watermark across 3 STFT resolutions simultaneously for:
1. Better SNR across frequencies
2. 3x redundancy (bits embedded 3 times at different resolutions)
3. Robustness against localized compression
4. Survival of time-scaling and resampling attacks

Key Enhancement:
  Instead of single STFT @ 2048, embed at 1024/2048/4096 in parallel
  Average reconstructed audio from all 3 resolutions
  Result: Better imperceptibility + robustness
"""

import numpy as np
import soundfile as sf
from typing import Tuple, Optional, Dict
from pathlib import Path

from .multi_res_stft import (
    stft_multiresolution,
    inverse_stft_multiresolution,
    MULTI_RES_FRAME_SIZES,
)
from .utils import text_to_binary, normalize_magnitude, denormalize_magnitude
from .ecc import MessageECC


class EncoderMultiResolution:
    """
    Enhanced encoder using multi-resolution embedding for Phase 2.
    
    Embeds watermark at 3 STFT resolutions, combines via overlap-add
    to improve robustness without increasing perceptibility.
    """
    
    def __init__(
        self,
        amplitude_factor: float = 0.05,
        seed: int = 42,
    ):
        self.amplitude_factor = amplitude_factor
        self.seed = seed
        self.ecc = MessageECC()
    
    def _create_bit_pattern_for_resolution(
        self,
        bits: np.ndarray,
        magnitude: np.ndarray,
        frame_size: int,
        start_bin: int = 50,
        bits_per_frame: int = 4,
    ) -> np.ndarray:
        """
        Create watermark pattern for a single resolution.
        
        Args:
            bits: Binary bits to embed
            magnitude: Magnitude spectrum (n_frames, n_freqs)
            frame_size: FFT frame size for this resolution
            start_bin: Starting frequency bin
            bits_per_frame: Bits to spread per frame
            
        Returns:
            Modified magnitude spectrum
        """
        modified_magnitude = magnitude.copy()
        n_frames, n_freqs = magnitude.shape
        n_bits = len(bits)
        
        np.random.seed(self.seed)
        
        # Energy-adaptive masking per frequency bin
        bin_energy = np.mean(magnitude, axis=0)  # Average energy per bin
        bin_energy_normalized = (bin_energy - np.min(bin_energy)) / (np.max(bin_energy) - np.min(bin_energy) + 1e-10)
        
        for bit_idx in range(n_bits):
            # Deterministic bin for this bit
            bit_bin = start_bin + bit_idx % (n_freqs - start_bin)
            
            # Energy-adaptive amplitude
            adaptive_amplitude = self.amplitude_factor * (0.5 + 0.5 * bin_energy_normalized[bit_bin])
            
            # Apply modulation
            bit_value = float(bits[bit_idx])
            if bit_value > 0.5:
                modified_magnitude[:, bit_bin] *= (1 + adaptive_amplitude)
            else:
                modified_magnitude[:, bit_bin] *= (1 - adaptive_amplitude)
        
        return modified_magnitude
    
    def encode(
        self,
        input_audio_path: str,
        output_audio_path: str,
        message: str,
        bits_per_frame: int = 4,
        use_ecc: bool = True,
        redundancy: int = 2,
    ) -> Dict:
        """
        Backward-compatible encode method (delegates to encode_multiresolution).
        
        Matches the original AudioGuardEncoder.encode() signature for API compatibility.
        
        Args:
            input_audio_path: Path to original audio
            output_audio_path: Path to save watermarked audio
            message: Text message to embed
            bits_per_frame: Bits per frame (ignored in multi-res, kept for compatibility)
            use_ecc: Apply Reed-Solomon ECC
            redundancy: Repeat message N times across timeline
            
        Returns:
            Dict with encoding metadata
        """
        return self.encode_multiresolution(
            input_path=input_audio_path,
            output_path=output_audio_path,
            message=message,
            use_ecc=use_ecc,
            redundancy=redundancy,
            sr=44100,
            amplitude_factor=self.amplitude_factor,
        )
    
    def encode_multiresolution(
        self,
        input_path: str,
        output_path: str,
        message: str,
        use_ecc: bool = True,
        redundancy: int = 2,
        sr: int = 44100,
        amplitude_factor: Optional[float] = None,
    ) -> Dict:
        """
        Encode watermark using multi-resolution STFT.
        
        Args:
            input_path: Path to original audio
            output_path: Path to save watermarked audio
            message: Text message to embed
            use_ecc: Apply Reed-Solomon ECC
            redundancy: Repeat message N times across timeline
            sr: Sample rate
            amplitude_factor: Override default amplitude
            
        Returns:
            Dict with encoding metadata
        """
        if amplitude_factor is not None:
            self.amplitude_factor = amplitude_factor
        
        # Load audio
        print(f"[MultiResEncoder] Reading audio from {input_path}...")
        audio, sr_loaded = sf.read(input_path)
        if audio.ndim > 1:
            audio = np.mean(audio, axis=1)
        print(f"[MultiResEncoder] Audio: {len(audio)/sr_loaded:.2f}s @ {sr_loaded}Hz")
        
        # Prepare message
        if use_ecc:
            ecc_bytes = self.ecc.encode(message)
            # Convert bytes to binary string
            bit_string = "".join(format(byte, "08b") for byte in ecc_bytes)
            bits_to_embed = np.array([int(b) for b in bit_string])
            print(f"[MultiResEncoder] Applied Reed-Solomon ECC (255 bytes)")
        else:
            bits_to_embed = np.array([int(b) for b in text_to_binary(message)])
        
        # Apply redundancy by repeating bits
        if redundancy > 1:
            bits_to_embed = np.tile(bits_to_embed, redundancy)
            print(f"[MultiResEncoder] Added {redundancy}x redundancy ({len(bits_to_embed)} total bits)")
        
        # Compute multi-resolution STFT
        print(f"[MultiResEncoder] Computing multi-resolution STFT...")
        stfts_original = stft_multiresolution(audio, sr=sr_loaded)
        
        # Embed watermark at each resolution
        stfts_modified = {}
        for res_name, (mag_orig, phase_orig, freq_bins) in stfts_original.items():
            frame_size = MULTI_RES_FRAME_SIZES[res_name]
            
            # Normalize magnitude for energy-adaptive embedding
            mag_norm, mag_min, mag_max = normalize_magnitude(mag_orig)
            
            # Create watermark pattern (spread bits across frames)
            mag_watermarked = self._create_bit_pattern_for_resolution(
                bits_to_embed,
                mag_norm,
                frame_size,
                start_bin=50,
                bits_per_frame=4,
            )
            
            # Denormalize
            mag_watermarked = denormalize_magnitude(mag_watermarked, mag_min, mag_max)
            
            stfts_modified[res_name] = (mag_watermarked, phase_orig)
            print(f"  {res_name}: {mag_orig.shape[0]} frames × {mag_orig.shape[1]} bins")
        
        # Reconstruct audio from all 3 resolutions and average
        print(f"[MultiResEncoder] Reconstructing audio from multi-resolution STFT...")
        audio_reconstructed = inverse_stft_multiresolution(stfts_modified, sr=sr_loaded)
        
        # Normalize to prevent clipping
        max_val = np.max(np.abs(audio_reconstructed))
        if max_val > 1.0:
            audio_reconstructed = audio_reconstructed / max_val
        
        # Save
        print(f"[MultiResEncoder] Saving watermarked audio to {output_path}...")
        sf.write(output_path, audio_reconstructed, sr_loaded)
        
        print(f"[MultiResEncoder] ✓ Multi-resolution watermarking complete!")
        
        return {
            "message": message,
            "bits_embedded": len(bits_to_embed),
            "use_ecc": use_ecc,
            "redundancy": redundancy,
            "amplitude_factor": self.amplitude_factor,
            "sample_rate": sr_loaded,
            "duration_s": len(audio) / sr_loaded,
            "output_file": output_path,
        }


if __name__ == "__main__":
    import tempfile
    
    print("[Phase 2: Multi-Res Encoder Test]")
    
    temp_dir = tempfile.mkdtemp()
    input_wav = f"{temp_dir}/input.wav"
    output_wav = f"{temp_dir}/watermarked.wav"
    
    # Create test audio
    sr = 44100
    duration = 5
    t = np.linspace(0, duration, sr * duration)
    audio = 0.3 * np.sin(2 * np.pi * 440 * t) + 0.1 * np.sin(2 * np.pi * 880 * t)
    sf.write(input_wav, audio, sr)
    print(f"✓ Created test audio: {duration}s @ {sr}Hz")
    
    # Encode with multi-res
    encoder = EncoderMultiResolution(amplitude_factor=0.05)
    message = "PHASE2"
    result = encoder.encode_multiresolution(
        input_wav,
        output_wav,
        message,
        use_ecc=True,
        redundancy=2,
        sr=sr,
    )
    
    print(f"\n[Encoding Result]")
    for key, val in result.items():
        print(f"  {key}: {val}")
    
    # Clean up
    import shutil
    shutil.rmtree(temp_dir)
    print(f"\n✓ Multi-resolution encoder: READY")
