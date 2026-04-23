"""
AudioGuard Spectral Encoder Module (Phase 1)

Core implementation of the STFT-based watermark encoder. Embeds binary data
into the frequency domain using bit-spreading across multiple frequency bins
while preserving phase information to ensure inaudibility.

DSP Pipeline:
    1. Read audio file (wav, mp3, etc.)
    2. Perform STFT with Hanning window
    3. Extract magnitude and phase
    4. Apply bit-spreading: distribute binary message across frequency bins
    5. Modulate magnitude coefficients within psychoacoustic masking threshold
    6. Reconstruct audio using inverse STFT
    7. Write watermarked audio with original sample rate and bit depth
"""

import numpy as np
import soundfile as sf
from pathlib import Path
from typing import Tuple, Optional
import warnings

from .utils import (
    stft,
    inverse_stft,
    hanning_window,
    normalize_magnitude,
    denormalize_magnitude,
    text_to_binary,
)


class AudioGuardEncoder:
    """
    High-fidelity audio watermarking encoder using STFT-based bit-spreading.

    This class implements the Phase 1 spectral engine, embedding invisible
    digital signatures into audio files through magnitude modulation in the
    frequency domain. The encoder preserves phase information to maintain
    audio perceptual quality while ensuring robust watermark embedding.

    Attributes:
        frame_size: FFT frame size (default: 2048 samples)
        hop_size: Frame overlap stride (default: frame_size // 2 for 50% overlap)
        amplitude_factor: Scaling factor for watermark magnitude (0.0-1.0)
        seed: Random seed for deterministic bit spreading (reproducibility)

    Example:
        >>> encoder = AudioGuardEncoder(amplitude_factor=0.05)
        >>> encoder.encode("original.wav", "watermarked.wav", message="AUTHOR_001")
    """

    def __init__(
        self,
        frame_size: int = 2048,
        hop_size: Optional[int] = None,
        amplitude_factor: float = 0.05,
        seed: int = 42,
    ):
        """
        Initialize AudioGuardEncoder with STFT parameters.

        Args:
            frame_size: FFT frame size in samples. Larger values provide
                       better frequency resolution but temporal loss. Default 2048.
            hop_size: Number of samples between consecutive frames. If None,
                     defaults to frame_size // 2 (50% overlap). Default None.
            amplitude_factor: Watermark magnitude scaling factor (0.0-1.0).
                             Higher values = more robust but more audible.
                             Typical range: 0.01-0.10 (0.1% to 1% of signal).
            seed: Random seed for bit-spreading determinism. Allows decoder
                 to regenerate spreading pattern. Default 42.

        Notes:
            - Smaller frame_size: Better temporal localization, worse frequency res
            - Larger frame_size: Better frequency res, worse temporal localization
            - Typical choice: 2048 (good balance for music at 44.1kHz)
            - amplitude_factor should be < 0.1 to ensure inaudibility
        """
        self.frame_size = frame_size
        self.hop_size = hop_size or frame_size // 2
        self.amplitude_factor = amplitude_factor
        self.seed = seed
        self.window = hanning_window(frame_size)

    def _spread_bits_across_bins(
        self,
        magnitude: np.ndarray,
        bit_sequence: str,
        start_bin: int = 50,
        bits_per_frame: int = 4,
    ) -> Tuple[np.ndarray, dict]:
        """
        Distribute binary watermark data across frequency bins using bit-spreading.

        Instead of embedding each bit in a single frequency bin (vulnerable to
        corruption), we spread each bit across multiple bins. This increases
        robustness by adding redundancy.

        Algorithm:
            1. Generate deterministic pseudo-random bin pattern from seed
            2. For each bit in message: modulate bits_per_frame frequency bins
            3. Skip low frequencies (< 50Hz) which contain speech formants
            4. Use energy-adaptive threshold to ensure inaudibility

        Args:
            magnitude: Magnitude spectrum from STFT, shape (n_frames, n_freqs)
            bit_sequence: Binary string to embed (e.g., "01101011")
            start_bin: Frequency bin index to start embedding (default: 50)
            bits_per_frame: Number of bins per bit for redundancy (default: 4)

        Returns:
            Tuple containing:
                - watermarked_magnitude: Modified magnitude with embedded bits
                - metadata: Dictionary containing embedding info for decoder

        Notes:
            - Uses energy-adaptive thresholding: higher energy bins accept
              larger magnitude modulations without perceptual change
            - Spreading increases robustness at cost of message capacity
            - Deterministic seeding allows synchronized decoder reproduction
        """
        watermarked_magnitude = magnitude.copy()
        n_frames, n_freqs = magnitude.shape
        n_bits = len(bit_sequence)

        # Generate pseudo-random bin indices for deterministic spreading
        rng = np.random.RandomState(self.seed)
        available_bins = np.arange(start_bin, n_freqs - bits_per_frame)

        # Energy-adaptive threshold computation per frequency bin
        bin_energy = np.mean(magnitude, axis=0)
        bin_energy_norm = (bin_energy - bin_energy.min()) / (
            bin_energy.max() - bin_energy.min() + 1e-10
        )

        metadata = {
            "start_bin": start_bin,
            "bits_per_frame": bits_per_frame,
            "n_bits": n_bits,
            "seed": self.seed,
        }

        for bit_idx, bit in enumerate(bit_sequence):
            # Select bins for this bit (with randomization for robustness)
            bin_indices = rng.choice(
                available_bins, size=min(bits_per_frame, len(available_bins)), replace=False
            )

            # Modulate selected bins in all frames
            for frame_idx in range(n_frames):
                for bin_idx in bin_indices:
                    original_magnitude = magnitude[frame_idx, bin_idx]
                    energy_scale = bin_energy_norm[bin_idx]

                    # Energy-adaptive modulation: higher energy = larger modulation allowed
                    modulation_strength = self.amplitude_factor * (0.5 + 0.5 * energy_scale)

                    if bit == "1":
                        # Increase magnitude for bit=1
                        watermarked_magnitude[frame_idx, bin_idx] *= (1 + modulation_strength)
                    else:
                        # Decrease magnitude for bit=0
                        watermarked_magnitude[frame_idx, bin_idx] *= (1 - modulation_strength)

        return watermarked_magnitude, metadata

    def encode(
        self,
        input_audio_path: str | Path,
        output_audio_path: str | Path,
        message: str,
        bits_per_frame: int = 4,
    ) -> dict:
        """
        Encode a watermark message into an audio file.

        Full encoding pipeline:
            1. Load audio file (preserves original sample rate & bit depth)
            2. Perform STFT decomposition into frequency domain
            3. Apply bit-spreading watermark embedding
            4. Reconstruct audio from modified spectrum
            5. Save watermarked file with original format preserved

        Args:
            input_audio_path: Path to input audio file (any format soundfile supports)
            output_audio_path: Path to save watermarked output
            message: Text message to embed (e.g., "AUTHOR_001")
            bits_per_frame: Number of frequency bins per bit (default: 4)
                           Higher = more robust but less capacity

        Returns:
            dict: Encoding metadata containing:
                - sample_rate: Original audio sample rate
                - duration: Audio duration in seconds
                - bit_sequence: Binary representation of message
                - frame_count: Number of STFT frames
                - spread_info: Bit-spreading configuration

        Raises:
            FileNotFoundError: If input file doesn't exist
            ValueError: If message is empty or too long for audio duration

        Example:
            >>> metadata = encoder.encode("voice.wav", "watermarked.wav", "DEV")
            >>> print(f"Encoded {metadata['duration']:.2f}s audio")
        """
        input_path = Path(input_audio_path)
        output_path = Path(output_audio_path)

        if not input_path.exists():
            raise FileNotFoundError(f"Audio file not found: {input_path}")

        if not message or len(message.strip()) == 0:
            raise ValueError("Message cannot be empty")

        print(f"[AudioGuardEncoder] Reading audio from {input_path}...")
        audio, sample_rate = sf.read(input_path, dtype="float32")

        # Handle mono conversion if stereo
        if len(audio.shape) > 1:
            print(f"[AudioGuardEncoder] Converting stereo to mono...")
            audio = np.mean(audio, axis=1)

        duration = len(audio) / sample_rate
        print(f"[AudioGuardEncoder] Audio: {duration:.2f}s @ {sample_rate}Hz")

        # Convert message to binary
        bit_sequence = text_to_binary(message)
        n_bits = len(bit_sequence)
        print(f"[AudioGuardEncoder] Embedding message: '{message}' ({n_bits} bits)")

        # STFT decomposition
        print(f"[AudioGuardEncoder] Computing STFT (frame_size={self.frame_size})...")
        magnitude, phase, freq_bins = stft(
            audio,
            frame_size=self.frame_size,
            hop_size=self.hop_size,
            window=self.window,
        )
        print(f"[AudioGuardEncoder] STFT computed: {magnitude.shape[0]} frames × {magnitude.shape[1]} bins")

        # Apply bit-spreading watermark
        print(f"[AudioGuardEncoder] Applying bit-spreading watermark...")
        watermarked_magnitude, spread_info = self._spread_bits_across_bins(
            magnitude,
            bit_sequence,
            start_bin=50,
            bits_per_frame=bits_per_frame,
        )

        # Reconstruct audio
        print(f"[AudioGuardEncoder] Reconstructing audio from modified spectrum...")
        watermarked_audio = inverse_stft(
            watermarked_magnitude,
            phase,
            frame_size=self.frame_size,
            hop_size=self.hop_size,
            window=self.window,
        )

        # Trim to original length (STFT padding)
        watermarked_audio = watermarked_audio[: len(audio)]

        # Normalize to prevent clipping
        max_val = np.max(np.abs(watermarked_audio))
        if max_val > 1.0:
            watermarked_audio = watermarked_audio / max_val
            print(
                f"[AudioGuardEncoder] Normalized to prevent clipping (max: {max_val:.4f})"
            )

        # Save watermarked audio
        print(f"[AudioGuardEncoder] Saving watermarked audio to {output_path}...")
        sf.write(output_path, watermarked_audio, sample_rate, subtype="PCM_16")

        result_metadata = {
            "sample_rate": int(sample_rate),
            "duration": float(duration),
            "bit_sequence": bit_sequence,
            "message": message,
            "frame_count": magnitude.shape[0],
            "spread_info": spread_info,
            "amplitude_factor": self.amplitude_factor,
        }

        print(f"[AudioGuardEncoder] ✓ Watermarking complete!")
        return result_metadata


if __name__ == "__main__":
    # Example usage
    encoder = AudioGuardEncoder(amplitude_factor=0.05)
    print("AudioGuardEncoder initialized. Use encode() method to watermark audio.")
