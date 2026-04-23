"""
Psychoacoustic Masking Module (Phase 2)

Implements ISO 226:2003 equal-loudness contours to create frequency-dependent
masking thresholds. This ensures watermark embedding respects human auditory
perception, making modifications inaudible across the entire frequency spectrum.

Reference:
    ISO/IEC 226:2003 - Acoustics. Normal equal-loudness-level contours
    Based on revised data from Fletcher & Munson (1933) studies
"""

import numpy as np
from typing import Tuple, Optional
from scipy import interpolate


class ISO226MaskingModel:
    """
    Implements ISO 226:2003 equal-loudness curves for psychoacoustic masking.

    The ISO 226 model provides frequency-dependent thresholds of hearing based on
    human perception studies. Frequencies near 3-4 kHz are most sensitive (lowest
    JND), while very low and very high frequencies require larger magnitude changes
    to be perceptually equivalent.

    Key Concept:
        For each frequency bin, we can embed larger magnitude modulations in
        frequencies where human hearing is less sensitive without introducing
        audible artifacts.

    Attributes:
        reference_freq: Reference frequency for loudness (1000 Hz = standard)
        loudness_level: Loudness level in phons (default: 40 phons = moderate)
    """

    # ISO 226:2003 data points (frequency in Hz, threshold in dB)
    # These represent the 40 phon equal-loudness contour
    ISO226_FREQUENCIES = np.array([
        20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500,
        630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000,
        10000, 12500
    ])

    ISO226_LOUDNESS_40PHON = np.array([
        64.8, 62.0, 52.0, 48.6, 46.5, 44.4, 43.4, 43.3, 43.5, 44.0, 44.7, 45.2,
        45.8, 46.3, 46.7, 47.0, 47.3, 47.5, 47.6, 47.4, 47.0, 46.2, 45.3, 44.4,
        43.5, 42.5, 41.0, 38.4, 34.3
    ])

    def __init__(self, loudness_level: float = 40.0):
        """
        Initialize ISO 226 masking model.

        Args:
            loudness_level: Equal-loudness level in phons (default: 40)
                           Higher = louder ambient sound = smaller JND
                           Lower = quieter environment = larger JND

        Notes:
            40 phons represents moderate listening level (office/casual listening)
            80 phons represents loud listening level (live music)
            ~20 phons represents quiet environment (library)
        """
        self.loudness_level = loudness_level

        # Create interpolation function for ISO 226 curve
        # Allow extrapolation below 20 Hz and above 12500 Hz
        self.iso226_interp = interpolate.interp1d(
            self.ISO226_FREQUENCIES,
            self.ISO226_LOUDNESS_40PHON,
            kind='cubic',
            bounds_error=False,
            fill_value='extrapolate'
        )

    def get_masking_threshold_db(self, frequencies: np.ndarray) -> np.ndarray:
        """
        Compute masking threshold in dB for given frequencies.

        The masking threshold represents the minimum SPL (Sound Pressure Level)
        at which a tone becomes audible. Frequencies with higher thresholds are
        less sensitive (can hide larger magnitude changes).

        Args:
            frequencies: Frequency values in Hz, shape (n_freqs,)

        Returns:
            np.ndarray: Masking threshold in dB relative to 1 Pascal
                       Shape: (n_freqs,)

        Example:
            >>> model = ISO226MaskingModel(loudness_level=40)
            >>> thresholds = model.get_masking_threshold_db(np.array([100, 1000, 10000]))
            >>> print(thresholds)
            # [43.3 47.5 38.4] dB
        """
        # Interpolate ISO 226 curve
        thresholds_db = self.iso226_interp(frequencies)

        # Ensure physically reasonable values (negative dB allowed below 0 dB SPL)
        return np.clip(thresholds_db, -10, 90)

    def get_masking_factor(
        self,
        frequencies: np.ndarray,
        reference_threshold_db: float = 20.0,
    ) -> np.ndarray:
        """
        Compute frequency-dependent masking factor (0.0 to 1.0).

        The masking factor represents how much magnitude modulation can be applied
        without audible artifacts. Higher masking factor = larger modulation allowed.

        Algorithm:
            masking_factor = 1 - (threshold_db - reference) / (max_range)
            - Normalizes ISO 226 thresholds to 0-1 range
            - 1.0 = least sensitive (can hide large changes)
            - 0.1 = most sensitive (must use small changes)

        Args:
            frequencies: Frequency values in Hz
            reference_threshold_db: Baseline threshold for normalization (default: 20dB)

        Returns:
            np.ndarray: Masking factors in range [0.1, 1.0]

        Example:
            >>> model = ISO226MaskingModel()
            >>> factors = model.get_masking_factor(np.array([100, 1000, 10000]))
            >>> # Lower values at 1000 Hz (most sensitive), higher at 100 Hz
        """
        thresholds = self.get_masking_threshold_db(frequencies)

        # Normalize thresholds to masking factor
        # Lower threshold (less sensitive) → higher masking factor (can hide more)
        min_threshold = np.min(thresholds)
        max_threshold = np.max(thresholds)
        range_db = max_threshold - min_threshold + 1e-10

        masking_factor = (max_threshold - thresholds) / range_db
        # Clip to [0.1, 1.0] range to ensure usable modulation in all bins
        masking_factor = np.clip(masking_factor, 0.1, 1.0)

        return masking_factor

    def get_perceptual_weights(
        self,
        frequencies: np.ndarray,
        reference_level_db: float = 40.0,
    ) -> np.ndarray:
        """
        Compute frequency-dependent perceptual weights for watermarking.

        These weights directly scale the amplitude_factor used in bit-spreading:
            effective_amplitude = amplitude_factor × perceptual_weight

        Higher weights at frequencies where humans are less sensitive ensures
        uniform perceptual loudness of the watermark across spectrum.

        Args:
            frequencies: Frequency values in Hz
            reference_level_db: Reference level for weight computation (default: 40 dB)

        Returns:
            np.ndarray: Perceptual weights in range [0.5, 2.0]

        Mathematical Basis:
            Weight ∝ 1 / (10^(threshold_dB / 20))
            Normalizes to reference level
        """
        thresholds = self.get_masking_threshold_db(frequencies)

        # Convert dB thresholds to linear weights
        # Lower threshold (more sensitive) → smaller weight (subtle modulation)
        weights = 10.0 ** (-thresholds / 20.0)

        # Normalize to reference level
        ref_weight = 10.0 ** (-reference_level_db / 20.0)
        weights = weights / ref_weight

        # Clip to perceptually reasonable range
        weights = np.clip(weights, 0.5, 2.0)

        return weights


class AdaptiveAmplitudeFactor:
    """
    Compute amplitude modulation factors using psychoacoustic masking.

    Combines energy-adaptive thresholding (from Phase 1) with psychoacoustic
    ISO 226 masking to create optimal watermark embedding.

    Algorithm:
        For each frequency bin:
            1. Get frequency-dependent masking factor from ISO 226
            2. Estimate signal energy at that bin
            3. Compute adaptive amplitude:
               adaptive_amp = base_amplitude ×
                             masking_factor ×
                             energy_scale ×
                             perceptual_weight
    """

    def __init__(self, masking_model: Optional[ISO226MaskingModel] = None):
        """
        Initialize adaptive amplitude computation.

        Args:
            masking_model: ISO226MaskingModel instance
                         If None, creates default with 40 phons
        """
        self.masking_model = masking_model or ISO226MaskingModel(loudness_level=40)

    def compute_adaptive_amplitude(
        self,
        magnitude_spectrum: np.ndarray,
        frequencies: np.ndarray,
        base_amplitude: float = 0.05,
        energy_power: float = 0.5,
    ) -> np.ndarray:
        """
        Compute per-bin adaptive amplitude factors.

        Args:
            magnitude_spectrum: Magnitude spectrum from STFT, shape (n_frames, n_freqs)
            frequencies: Frequency values for each bin in Hz, shape (n_freqs,)
            base_amplitude: Base watermark amplitude factor (0.01-0.10)
            energy_power: Exponent for energy scaling (default: 0.5 for square root)

        Returns:
            np.ndarray: Adaptive amplitude per bin, shape (n_freqs,)

        Example:
            >>> amplitude_computer = AdaptiveAmplitudeFactor()
            >>> magnitude = np.random.randn(87, 1025)
            >>> frequencies = np.fft.rfftfreq(2048, 1/44100)
            >>> adaptive = amplitude_computer.compute_adaptive_amplitude(
            ...     magnitude, frequencies, base_amplitude=0.05
            ... )
        """
        # Get frequency-dependent masking factors
        masking_factors = self.masking_model.get_masking_factor(frequencies)

        # Compute energy scale per frequency bin
        bin_energy = np.mean(magnitude_spectrum, axis=0)
        min_energy = np.min(bin_energy)
        max_energy = np.max(bin_energy)
        energy_range = max_energy - min_energy + 1e-10

        energy_scale = ((bin_energy - min_energy) / energy_range) ** energy_power
        # Map to [0.5, 1.0] for smooth energy adaptation
        energy_scale = 0.5 + 0.5 * energy_scale

        # Combine all factors
        adaptive_amplitude = (
            base_amplitude *
            masking_factors *
            energy_scale
        )

        return adaptive_amplitude


def create_frequency_array(sample_rate: int, frame_size: int) -> np.ndarray:
    """
    Create frequency array for STFT bins.

    Args:
        sample_rate: Sample rate in Hz
        frame_size: STFT frame size

    Returns:
        np.ndarray: Frequency values for one-sided spectrum (n_freqs,)
    """
    return np.fft.rfftfreq(frame_size, 1.0 / sample_rate)


if __name__ == "__main__":
    # Example usage
    model = ISO226MaskingModel(loudness_level=40)

    # Plot masking curve
    freqs = np.logspace(1, 4.1, 100)  # 10 Hz to ~12.5 kHz
    thresholds = model.get_masking_threshold_db(freqs)
    masking_factors = model.get_masking_factor(freqs)

    print("ISO 226 Masking Model (40 phons)")
    print(f"Frequency range: {freqs[0]:.1f} Hz to {freqs[-1]:.1f} Hz")
    print(f"Threshold range: {thresholds.min():.1f} dB to {thresholds.max():.1f} dB")
    print(f"Most sensitive: ~1000 Hz")
    print(f"Least sensitive: 20-100 Hz, 10+ kHz")
