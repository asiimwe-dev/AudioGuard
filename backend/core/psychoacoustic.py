"""
Psychoacoustic Masking (ISO 226:2003)

Provides per-frequency-bin masking factors derived from the 40-phon
equal-loudness contour.  Higher masking factor = less sensitive = larger
watermark amplitude allowed.

Keeping this as a thin, dependency-free module so it can be swapped for
a full perceptual model without touching the core encoder.
"""

from __future__ import annotations

import numpy as np
from scipy.interpolate import interp1d

# ISO 226:2003  40-phon equal-loudness data
_ISO_FREQS = np.array([
    20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500,
    630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000,
    10000, 12500,
], dtype=np.float32)

_ISO_DB_40 = np.array([
    64.8, 62.0, 52.0, 48.6, 46.5, 44.4, 43.4, 43.3, 43.5, 44.0, 44.7, 45.2,
    45.8, 46.3, 46.7, 47.0, 47.3, 47.5, 47.6, 47.4, 47.0, 46.2, 45.3, 44.4,
    43.5, 42.5, 41.0, 38.4, 34.3,
], dtype=np.float32)


class AdaptiveMasking:
    """Computes frequency-dependent masking factors for the watermarker."""

    def __init__(self, loudness_phon: float = 40.0):
        self._interp = interp1d(
            _ISO_FREQS, _ISO_DB_40,
            kind="cubic",
            bounds_error=False,
            fill_value="extrapolate",
        )

    def masking_factors(self, freqs: np.ndarray) -> np.ndarray:
        """
        Returns per-bin masking factor in [0.1, 1.0].

        Higher value → less perceptually sensitive → larger modulation allowed.

        Args:
            freqs: Frequency array (Hz), shape (n_freqs,)

        Returns:
            np.ndarray: Masking factors, shape (n_freqs,)
        """
        thresholds = np.clip(self._interp(freqs.astype(float)), -10, 90).astype(np.float32)
        t_min, t_max = thresholds.min(), thresholds.max()
        # Invert: high threshold (less sensitive) → factor near 1.0
        factors = (t_max - thresholds) / (t_max - t_min + 1e-8)
        return np.clip(factors, 0.1, 1.0)
