"""
AudioGuard DSP Utilities Module

Provides core signal processing utilities for STFT analysis, windowing, and
frequency-domain operations. All operations use NumPy vectorization for
computational efficiency.

Mathematical Foundation:
- STFT: Converts time-domain audio into time-frequency representation
- Window Function: Hanning window minimizes spectral leakage
- Overlap: 50% overlap enables smooth frame transitions
"""

import numpy as np
from typing import Tuple, Optional
from scipy import signal


def hanning_window(frame_size: int) -> np.ndarray:
    """
    Generate a Hanning (raised cosine) window function.

    The Hanning window reduces spectral leakage by tapering frame edges,
    ensuring smooth frequency transitions between STFT frames.

    Args:
        frame_size: Length of the window in samples

    Returns:
        np.ndarray: Hanning window coefficients of shape (frame_size,)

    Mathematical Definition:
        w[n] = 0.5 * (1 - cos(2π*n / (N-1))) for n = 0, 1, ..., N-1
    """
    return np.hanning(frame_size)


def stft(
    audio: np.ndarray,
    frame_size: int = 2048,
    hop_size: Optional[int] = None,
    window: Optional[np.ndarray] = None,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Compute the Short-Time Fourier Transform using Hanning window.

    Decomposes the audio signal into overlapping frames in the frequency
    domain, preserving both magnitude and phase information. Uses 50% overlap
    by default for smooth reconstruction.

    Args:
        audio: Input audio signal of shape (n_samples,)
        frame_size: FFT frame size in samples (default: 2048)
        hop_size: Number of samples between successive frames (default: frame_size // 2)
        window: Pre-computed window function. If None, Hanning is used.

    Returns:
        Tuple containing:
            - magnitude: Magnitude spectrum of shape (n_frames, n_freqs)
            - phase: Phase spectrum of shape (n_frames, n_freqs)
            - freq_bins: Frequency values in Hz (shape: (n_freqs,))

    Notes:
        - n_freqs = frame_size // 2 + 1 (one-sided spectrum)
        - n_frames depends on audio length and hop_size
    """
    if hop_size is None:
        hop_size = frame_size // 2

    if window is None:
        window = hanning_window(frame_size)

    # Pad audio to ensure complete frames
    n_frames = int(np.ceil(len(audio) / hop_size))
    padded_length = n_frames * hop_size + frame_size
    padded_audio = np.pad(audio, (0, padded_length - len(audio)), mode="constant")

    # Extract frames and apply window
    frames = np.lib.stride_tricks.as_strided(
        padded_audio,
        shape=(n_frames, frame_size),
        strides=(hop_size * audio.itemsize, audio.itemsize),
    )
    windowed_frames = frames * window[np.newaxis, :]

    # Compute FFT
    fft_result = np.fft.rfft(windowed_frames, axis=1)
    magnitude = np.abs(fft_result)
    phase = np.angle(fft_result)

    # Frequency bins (one-sided spectrum)
    freq_bins = np.fft.rfftfreq(frame_size)

    return magnitude, phase, freq_bins


def inverse_stft(
    magnitude: np.ndarray,
    phase: np.ndarray,
    frame_size: int = 2048,
    hop_size: Optional[int] = None,
    window: Optional[np.ndarray] = None,
) -> np.ndarray:
    """
    Reconstruct audio from STFT magnitude and phase using inverse FFT.

    Converts the time-frequency representation back into a time-domain signal.
    Uses overlap-add method to reconstruct audio from overlapping frames.

    Args:
        magnitude: Magnitude spectrum of shape (n_frames, n_freqs)
        phase: Phase spectrum of shape (n_frames, n_freqs)
        frame_size: FFT frame size in samples (must match encoding)
        hop_size: Number of samples between frames (default: frame_size // 2)
        window: Pre-computed window function. If None, Hanning is used.

    Returns:
        np.ndarray: Reconstructed audio signal

    Notes:
        - Reconstruction uses overlap-add with Hanning window (Constant Overlap-Add)
        - Window normalization ensures perfect reconstruction at 50% overlap
    """
    if hop_size is None:
        hop_size = frame_size // 2

    if window is None:
        window = hanning_window(frame_size)

    n_frames = magnitude.shape[0]
    n_samples = (n_frames - 1) * hop_size + frame_size

    # Reconstruct complex spectrum
    complex_spectrum = magnitude * np.exp(1j * phase)

    # Inverse FFT to time domain
    windowed_frames = np.fft.irfft(complex_spectrum, n=frame_size, axis=1)

    # Apply window for reconstruction
    windowed_frames *= window[np.newaxis, :]

    # Overlap-add reconstruction
    audio = np.zeros(n_samples)
    for i in range(n_frames):
        start = i * hop_size
        end = start + frame_size
        audio[start:end] += windowed_frames[i]

    # Normalize for Hanning window at 50% overlap (perfect reconstruction)
    window_sum = np.zeros(n_samples)
    for i in range(n_frames):
        start = i * hop_size
        end = start + frame_size
        window_sum[start:end] += window**2

    # Avoid division by zero
    window_sum[window_sum < 1e-10] = 1.0
    audio /= window_sum

    return audio


def normalize_magnitude(
    magnitude: np.ndarray,
    epsilon: float = 1e-10,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Normalize magnitude spectrum for energy-adaptive watermarking.

    Computes normalization statistics (min, max, mean) per frequency bin
    to enable energy-adaptive bit embedding. Higher energy bins can hide
    larger magnitude perturbations without audible artifacts.

    Args:
        magnitude: Magnitude spectrum of shape (n_frames, n_freqs)
        epsilon: Small constant to avoid division by zero

    Returns:
        Tuple containing:
            - norm_magnitude: Normalized magnitude (0-1 range)
            - mag_min: Minimum per frequency bin, shape (n_freqs,)
            - mag_max: Maximum per frequency bin, shape (n_freqs,)
    """
    mag_min = np.min(magnitude, axis=0, keepdims=True)
    mag_max = np.max(magnitude, axis=0, keepdims=True)

    mag_range = mag_max - mag_min + epsilon
    norm_magnitude = (magnitude - mag_min) / mag_range

    return norm_magnitude, mag_min.squeeze(), mag_max.squeeze()


def denormalize_magnitude(
    norm_magnitude: np.ndarray,
    mag_min: np.ndarray,
    mag_max: np.ndarray,
) -> np.ndarray:
    """
    Reverse normalization on magnitude spectrum.

    Args:
        norm_magnitude: Normalized magnitude spectrum
        mag_min: Minimum values per frequency bin
        mag_max: Maximum values per frequency bin

    Returns:
        np.ndarray: Denormalized magnitude spectrum
    """
    mag_range = mag_max - mag_min
    return norm_magnitude * mag_range + mag_min


def text_to_binary(text: str) -> str:
    """
    Convert text string to binary representation.

    Each character is encoded as its 8-bit ASCII value, concatenated
    into a continuous binary string.

    Args:
        text: Input text (e.g., "dev")

    Returns:
        str: Binary representation (e.g., "011001000110010101110110" for "dev")

    Example:
        >>> text_to_binary("A")
        '01000001'
    """
    return "".join(format(ord(char), "08b") for char in text)


def binary_to_text(binary_str: str) -> str:
    """
    Convert binary string back to text.

    Args:
        binary_str: Binary representation (must be multiple of 8 bits)

    Returns:
        str: Decoded text

    Raises:
        ValueError: If binary string length is not a multiple of 8
    """
    if len(binary_str) % 8 != 0:
        raise ValueError(
            f"Binary string length must be multiple of 8, got {len(binary_str)}"
        )
    return "".join(chr(int(binary_str[i : i + 8], 2)) for i in range(0, len(binary_str), 8))
