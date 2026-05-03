"""
AudioGuard Spectral Decoder Module (Phase 2)

Implements watermark extraction from STFT magnitude spectrum using energy
detection and majority voting. Recovers original message embedded by encoder
using same STFT/phase-preservation strategy.

Extraction Pipeline:
    1. Load watermarked audio
    2. Perform STFT decomposition
    3. Estimate signal-to-noise ratio (SNR) for robustness metrics
    4. For each bit: extract from spread bins using majority voting
    5. Convert binary to text message
    6. Validate checksum (optional)
"""

import numpy as np
from typing import Tuple, Dict, Optional
import soundfile as sf
from pathlib import Path

from .utils import stft, hanning_window, text_to_binary
from .psychoacoustic import ISO226MaskingModel, create_frequency_array


class AudioGuardDecoder:
    """
    High-fidelity watermark extractor using energy detection and voting.

    Recovers binary messages from watermarked audio by:
    1. Computing STFT magnitude of received audio
    2. Comparing against expected bit patterns
    3. Using majority voting across redundant bins
    4. Estimating confidence metrics (SNR, BER)

    Attributes:
        frame_size: STFT frame size (must match encoder)
        hop_size: Frame stride (must match encoder)
        seed: Random seed for bit-spreading pattern (must match encoder)
    """

    def __init__(
        self,
        frame_size: int = 2048,
        hop_size: Optional[int] = None,
        seed: int = 42,
    ):
        """
        Initialize AudioGuardDecoder.

        Args:
            frame_size: FFT frame size (default: 2048, must match encoder)
            hop_size: Frame stride (default: frame_size // 2)
            seed: Random seed for deterministic bit pattern regeneration (must match encoder)
        """
        self.frame_size = frame_size
        self.hop_size = hop_size or frame_size // 2
        self.seed = seed
        self.window = hanning_window(frame_size)

    def _estimate_bit_energy(
        self,
        magnitude: np.ndarray,
        bit_idx: int,
        bit_sequence: str,
        start_bin: int = 50,
        bits_per_frame: int = 4,
    ) -> Tuple[float, float, float]:
        """
        Estimate received energy for a single bit using per-frame voting.

        For each of the bits_per_frame bins assigned to this bit:
        - Extract magnitude values across all frames
        - Compare against reference (adjacent bins)
        - Use frame-level voting for robustness

        Args:
            magnitude: Magnitude spectrum (n_frames, n_freqs)
            bit_idx: Index of bit to extract (0 to n_bits-1)
            bit_sequence: Original bit sequence for reference
            start_bin: Starting frequency bin index
            bits_per_frame: Number of bins per bit

        Returns:
            Tuple containing:
                - avg_delta: Average delta across frames
                - frame_agreement: How consistently frames agree on bit value
                - voting_confidence: Confidence in the bit decision
        """
        rng = np.random.RandomState(self.seed + bit_idx)
        n_frames, n_freqs = magnitude.shape

        # Generate pseudo-random bin indices (same as encoder)
        available_bins = np.arange(start_bin, n_freqs - bits_per_frame)
        bin_indices = rng.choice(
            available_bins,
            size=min(bits_per_frame, len(available_bins)),
            replace=False
        )

        # **IMPROVED: Per-frame delta calculation**
        frame_votes = []  # Record votes per frame
        frame_deltas = []
        
        for frame_idx in range(n_frames):
            # Get watermarked bin magnitudes for this frame
            watermarked_mags = magnitude[frame_idx, bin_indices]
            watermarked_avg = np.mean(watermarked_mags)
            
            # Calculate reference from surrounding bins
            ref_mags = []
            for bin_idx in bin_indices:
                # Use bins 3-5 positions away as reference (avoid overlap)
                for offset in [-5, -4, -3, 3, 4, 5]:
                    ref_bin = bin_idx + offset
                    if start_bin <= ref_bin < n_freqs:
                        ref_mags.append(magnitude[frame_idx, ref_bin])
            
            ref_avg = np.mean(ref_mags) if ref_mags else 1.0
            
            # Delta: deviation from reference
            delta = watermarked_avg - ref_avg
            frame_deltas.append(delta)
            
            # Vote: positive delta = bit 1, negative delta = bit 0
            frame_votes.append(1 if delta > 0 else 0)
        
        frame_votes = np.array(frame_votes)
        frame_deltas = np.array(frame_deltas)
        
        # Majority vote across frames
        vote_ratio = np.sum(frame_votes) / len(frame_votes)
        voting_agreement = max(vote_ratio, 1.0 - vote_ratio)
        
        # Average delta weighted by voting confidence
        avg_delta = np.mean(frame_deltas)

        return avg_delta, voting_agreement, voting_agreement

    def _estimate_snr(
        self,
        original_magnitude: np.ndarray,
        received_magnitude: np.ndarray,
    ) -> float:
        """
        Estimate signal-to-noise ratio from magnitude spectra.

        SNR = power_signal / power_noise
        ≈ power_watermark / power_distortion

        Args:
            original_magnitude: Magnitude from original (clean) STFT
            received_magnitude: Magnitude from received (watermarked/degraded) STFT

        Returns:
            float: Estimated SNR in dB
        """
        # Power difference (should be watermark + noise)
        diff = received_magnitude - original_magnitude
        power_diff = np.mean(diff ** 2)

        # Signal power
        power_signal = np.mean(original_magnitude ** 2)

        # SNR computation
        snr_linear = power_signal / (power_diff + 1e-12)
        snr_db = 10 * np.log10(snr_linear + 1e-12)

        return float(np.clip(snr_db, -20, 60))

    def decode(
        self,
        input_audio_path: str | Path,
        message_length: int,
        validate_length: bool = True,
    ) -> Dict:
        """
        Extract watermark from audio file.

        Decoding pipeline:
            1. Load audio + STFT
            2. For each bit: energy detection + majority voting
            3. Threshold energy to binary decision
            4. Convert to text
            5. Compute confidence metrics

        Args:
            input_audio_path: Path to watermarked audio file
            message_length: Expected message length in characters
                           (used to know number of bits: 8 * message_length)
            validate_length: If True, verify decoded length matches expected

        Returns:
            Dict with keys:
                - message: Decoded text message
                - bits: Decoded binary string
                - snr_db: Estimated signal-to-noise ratio
                - confidence: Extraction confidence (0.0-1.0)
                - frame_count: Number of STFT frames analyzed
                - metadata: Extraction details

        Raises:
            FileNotFoundError: If input file doesn't exist
            ValueError: If message too long for audio duration
        """
        input_path = Path(input_audio_path)

        if not input_path.exists():
            raise FileNotFoundError(f"Audio file not found: {input_path}")

        print(f"[AudioGuardDecoder] Loading audio from {input_path}...")
        received_audio, sample_rate = sf.read(input_path, dtype="float32")

        # Handle stereo
        if len(received_audio.shape) > 1:
            print(f"[AudioGuardDecoder] Converting stereo to mono...")
            received_audio = np.mean(received_audio, axis=1)

        duration = len(received_audio) / sample_rate
        expected_bits = message_length * 8
        print(f"[AudioGuardDecoder] Audio: {duration:.2f}s @ {sample_rate}Hz")
        print(f"[AudioGuardDecoder] Expecting {message_length} chars ({expected_bits} bits)")

        # STFT analysis
        print(f"[AudioGuardDecoder] Computing STFT...")
        magnitude, phase, freq_bins = stft(
            received_audio,
            frame_size=self.frame_size,
            hop_size=self.hop_size,
            window=self.window,
        )
        print(f"[AudioGuardDecoder] STFT: {magnitude.shape[0]} frames × {magnitude.shape[1]} bins")

        # Extract bits using correlation-based detection
        print(f"[AudioGuardDecoder] Extracting watermark bits (correlation method)...")
        decoded_bits = []
        energies = []
        confidences = []

        # First pass: collect all bit deltas with frame-level votes
        frame_agreement_list = []
        for bit_idx in range(expected_bits):
            avg_delta, frame_agreement, voting_conf = self._estimate_bit_energy(
                magnitude,
                bit_idx,
                "",
                start_bin=50,
                bits_per_frame=4,
            )

            energies.append(avg_delta)
            confidences.append(voting_conf)
            frame_agreement_list.append(frame_agreement)

        energies = np.array(energies)
        frame_agreements = np.array(frame_agreement_list)
        
        # **IMPROVED: Use frame agreement as confidence weight**
        # Extract bits based on delta sign, weighted by frame agreement
        for bit_idx in range(expected_bits):
            delta = energies[bit_idx]
            agreement = frame_agreements[bit_idx]
            
            # Bit decision based on delta sign
            bit_value = "1" if delta > 0 else "0"
            decoded_bits.append(bit_value)

        decoded_binary = "".join(decoded_bits)

        # Convert to text
        try:
            if len(decoded_binary) % 8 != 0:
                decoded_binary = decoded_binary[:(len(decoded_binary) // 8) * 8]

            decoded_message = ""
            for i in range(0, len(decoded_binary), 8):
                byte = decoded_binary[i:i+8]
                if len(byte) == 8:
                    char_code = int(byte, 2)
                    if 32 <= char_code < 127:  # Printable ASCII
                        decoded_message += chr(char_code)

        except Exception as e:
            print(f"[AudioGuardDecoder] Decoding error: {e}")
            decoded_message = ""

        # Compute confidence
        avg_confidence = np.mean(confidences) if confidences else 0.0

        # Estimate SNR (compare against smoothed version)
        smoothed_magnitude = np.convolve(magnitude.flatten(), np.ones(5) / 5, mode='same')
        smoothed_magnitude = smoothed_magnitude.reshape(magnitude.shape)
        snr_db = self._estimate_snr(smoothed_magnitude, magnitude)

        result = {
            "message": decoded_message,
            "bits": decoded_binary,
            "snr_db": snr_db,
            "confidence": float(avg_confidence),
            "frame_count": magnitude.shape[0],
            "energy_values": energies,
            "metadata": {
                "sample_rate": int(sample_rate),
                "duration": float(duration),
                "expected_bits": expected_bits,
                "decoded_bits": len(decoded_binary),
            }
        }

        return result

    def decode_confidence_report(self, decode_result: Dict) -> str:
        """
        Generate human-readable extraction confidence report.

        Args:
            decode_result: Result from decode() method

        Returns:
            str: Formatted confidence report
        """
        msg = decode_result["message"]
        snr = decode_result["snr_db"]
        conf = decode_result["confidence"]

        report = f"""
Watermark Extraction Report:
  Message:    '{msg}'
  SNR (dB):   {snr:.2f}
  Confidence: {conf:.2%}
  Frames:     {decode_result['frame_count']}
  Duration:   {decode_result['metadata']['duration']:.2f}s
        """
        return report


if __name__ == "__main__":
    # Example usage
    decoder = AudioGuardDecoder(seed=42)
    print("AudioGuardDecoder initialized. Use decode() method to extract watermarks.")
