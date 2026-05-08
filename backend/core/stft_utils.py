"""
AudioGuard STFT Utilities

Multi-resolution STFT engine (1024 / 2048 / 4096).
Uses vectorised stride-tricks + np.fft.rfft — no librosa dependency in hot path.
75% overlap (hop = frame // 4) for redundancy + robustness.
"""

from __future__ import annotations

from typing import Dict, Tuple

import numpy as np

# Resolution name → FFT frame size
RESOLUTIONS: Dict[str, int] = {
    "fine_time": 1024,   # 23 ms  @ 44.1 kHz
    "balanced":  2048,   # 46 ms
    "fine_freq": 4096,   # 93 ms
}


def _hanning(n: int) -> np.ndarray:
    return np.hanning(n).astype(np.float32)


def _forward_single(
    audio: np.ndarray,
    frame_size: int,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Single-resolution STFT. Returns (magnitude, phase, freq_bins)."""
    hop = frame_size // 4
    window = _hanning(frame_size)
    sr = 44100  # freq_bins label only; not used for signal math

    # Pad so we get complete frames
    n_frames = max(1, int(np.ceil(len(audio) / hop)))
    pad_len = n_frames * hop + frame_size - len(audio)
    padded = np.pad(audio.astype(np.float32), (0, max(0, pad_len)))

    # Strided frame extraction (zero-copy view)
    frames = np.lib.stride_tricks.as_strided(
        padded,
        shape=(n_frames, frame_size),
        strides=(hop * padded.strides[0], padded.strides[0]),
    )
    windowed = frames * window  # (n_frames, frame_size)

    spec = np.fft.rfft(windowed, axis=1)   # (n_frames, frame_size//2+1)
    magnitude = np.abs(spec).astype(np.float32)
    phase = np.angle(spec).astype(np.float32)
    freq_bins = np.fft.rfftfreq(frame_size, 1.0 / 44100).astype(np.float32)

    return magnitude, phase, freq_bins


def _inverse_single(
    magnitude: np.ndarray,
    phase: np.ndarray,
    frame_size: int,
) -> np.ndarray:
    """Inverse STFT via overlap-add with Hanning normalisation."""
    hop = frame_size // 4
    window = _hanning(frame_size)
    n_frames = magnitude.shape[0]
    n_samples = (n_frames - 1) * hop + frame_size

    complex_spec = magnitude * np.exp(1j * phase)
    frames = np.fft.irfft(complex_spec, n=frame_size, axis=1).astype(np.float32)
    frames *= window

    audio = np.zeros(n_samples, dtype=np.float32)
    win_sq_sum = np.zeros(n_samples, dtype=np.float32)

    # Vectorised overlap-add using np.add.at
    indices = np.arange(n_frames)[:, None] * hop + np.arange(frame_size)[None, :]  # (n_frames, frame_size)
    np.add.at(audio, indices, frames)
    np.add.at(win_sq_sum, indices, window[None, :] ** 2)

    win_sq_sum = np.where(win_sq_sum < 1e-8, 1.0, win_sq_sum)
    return audio / win_sq_sum


class MultiResSTFT:
    """Compute and invert multi-resolution STFTs."""

    def forward(
        self,
        audio: np.ndarray,
    ) -> Dict[str, Tuple[np.ndarray, np.ndarray, np.ndarray]]:
        """
        Returns dict: res_name → (magnitude, phase, freq_bins).
        All arrays are float32.
        """
        return {
            name: _forward_single(audio, frame_size)
            for name, frame_size in RESOLUTIONS.items()
        }

    def inverse(
        self,
        stfts: Dict[str, Tuple[np.ndarray, np.ndarray]],
    ) -> np.ndarray:
        """
        Average overlap-add from all available resolutions.
        Input: dict res_name → (magnitude, phase)  [phase kept from encode].
        """
        signals = []
        for name in RESOLUTIONS:
            if name not in stfts:
                continue
            mag, phase = stfts[name]
            sig = _inverse_single(mag, phase, RESOLUTIONS[name])
            signals.append(sig)

        if not signals:
            raise ValueError("No STFT data to invert")

        max_len = max(len(s) for s in signals)
        padded = [np.pad(s, (0, max_len - len(s))) for s in signals]
        return np.mean(padded, axis=0).astype(np.float32)
