"""
AudioGuard Synchronization Module

Implements frame-level synchronization using Barker codes.
Enables robust frame detection and alignment for watermark extraction.

Barker codes are binary sequences with special autocorrelation properties:
- Peak correlation at zero lag
- Low correlation at other lags (minimizes false positives)

Used for: Frame alignment, robustness to time-shifting, attack detection
"""

import numpy as np
from typing import List, Tuple, Optional


class BarkerCodes:
    """Barker codes for frame synchronization."""
    
    # Standard Barker codes (all lengths up to 13)
    BARKER_13 = np.array([1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1])
    BARKER_7 = np.array([1, 1, 1, 0, 0, 1, 0])
    BARKER_5 = np.array([1, 1, 1, 0, 0])
    BARKER_3 = np.array([1, 1, 0])
    BARKER_2 = np.array([1, 0])
    
    # Convert to bipolar (-1, +1) for correlation
    BARKER_13_BIPOLAR = 2 * BARKER_13 - 1
    BARKER_7_BIPOLAR = 2 * BARKER_7 - 1
    BARKER_5_BIPOLAR = 2 * BARKER_5 - 1


class SyncDetector:
    """Detects Barker code synchronization patterns in magnitude spectrum."""
    
    def __init__(self, code_type: str = "barker_13"):
        """
        Initialize sync detector.
        
        Args:
            code_type: Which Barker code to use ("barker_13", "barker_7", etc.)
        """
        if code_type == "barker_13":
            self.code = BarkerCodes.BARKER_13_BIPOLAR
        elif code_type == "barker_7":
            self.code = BarkerCodes.BARKER_7_BIPOLAR
        elif code_type == "barker_5":
            self.code = BarkerCodes.BARKER_5_BIPOLAR
        else:
            raise ValueError(f"Unknown code_type: {code_type}")
        
        self.code_length = len(self.code)
        self.code_type = code_type
    
    def detect_sync_in_sequence(
        self,
        bit_sequence: np.ndarray,
        threshold: float = 0.8,
    ) -> Tuple[bool, float]:
        """
        Detect Barker code at start of bit sequence.
        
        Args:
            bit_sequence: Extracted bit sequence (1D array of 0/1)
            threshold: Correlation threshold (0-1) for sync detection
        
        Returns:
            Tuple of (sync_detected, correlation_value)
        """
        if len(bit_sequence) < self.code_length:
            return False, 0.0
        
        # Extract first code_length bits
        candidate = bit_sequence[:self.code_length]
        
        # Convert to bipolar
        candidate_bipolar = 2 * candidate - 1
        
        # Compute correlation
        correlation = np.mean(candidate_bipolar * self.code)
        
        # Normalize to [0, 1]
        correlation = (correlation + 1) / 2
        
        detected = correlation >= threshold
        return detected, float(correlation)
    
    def detect_sync_frames(
        self,
        magnitude_spectrum: np.ndarray,
        bits_per_frame: int = 4,
        start_bin: int = 50,
        threshold: float = 0.8,
    ) -> List[Tuple[int, float]]:
        """
        Detect sync patterns in multiple frames.
        
        Args:
            magnitude_spectrum: STFT magnitude (n_frames, n_bins)
            bits_per_frame: Bits embedded per frame
            start_bin: Starting frequency bin for embedding
            threshold: Correlation threshold for detection
        
        Returns:
            List of (frame_idx, correlation) tuples where sync detected
        """
        n_frames = magnitude_spectrum.shape[0]
        sync_frames = []
        
        for frame_idx in range(n_frames - self.code_length + 1):
            # Extract bits from this frame sequence
            bits = []
            for i in range(self.code_length):
                frame = magnitude_spectrum[frame_idx + i]
                # Simple energy detection (can be improved)
                energy = np.mean(np.abs(frame[start_bin:start_bin+100]))
                bit = 1 if energy > np.median(frame[start_bin:start_bin+100]) else 0
                bits.append(bit)
            
            # Detect sync in this sequence
            detected, correlation = self.detect_sync_in_sequence(
                np.array(bits),
                threshold=threshold
            )
            
            if detected:
                sync_frames.append((frame_idx, correlation))
        
        return sync_frames
    
    @staticmethod
    def embed_barker_code(
        bit_sequence: np.ndarray,
        code: Optional[np.ndarray] = None,
    ) -> np.ndarray:
        """
        Embed Barker code at start of bit sequence.
        
        Args:
            bit_sequence: Original bit sequence
            code: Barker code to embed (default: BARKER_13)
        
        Returns:
            Augmented bit sequence (barker_code + original_bits)
        """
        if code is None:
            code = BarkerCodes.BARKER_13
        
        # Combine barker code + message
        augmented = np.concatenate([code, bit_sequence])
        return augmented


def create_sync_header(message_bits: np.ndarray) -> np.ndarray:
    """
    Create header with Barker code + version + message length.
    
    Format:
    - Barker-13 (13 bits): Sync marker
    - Version (2 bits): Protocol version (00 = v0)
    - Message length (8 bits): Number of message bytes
    - Message bits (variable)
    
    Args:
        message_bits: Original message as bit sequence
    
    Returns:
        Header + message bits combined
    """
    barker = BarkerCodes.BARKER_13
    version = np.array([0, 0])  # Version 0
    
    # Message length in bytes (estimate from bits)
    msg_len_bytes = (len(message_bits) + 7) // 8
    msg_len_bits = np.unpackbits(np.array([msg_len_bytes], dtype=np.uint8))[0:8]
    
    # Combine all
    header = np.concatenate([barker, version, msg_len_bits, message_bits])
    return header


def parse_sync_header(
    header_bits: np.ndarray,
    min_header_size: int = 13 + 2 + 8,
) -> Tuple[bool, Optional[int]]:
    """
    Parse sync header to extract message length.
    
    Args:
        header_bits: Received header bits
        min_header_size: Minimum expected header size
    
    Returns:
        Tuple of (sync_valid, message_length_bytes)
    """
    if len(header_bits) < min_header_size:
        return False, None
    
    # Check Barker code
    barker_candidate = header_bits[:13]
    barker = BarkerCodes.BARKER_13
    
    if not np.array_equal(barker_candidate, barker):
        return False, None
    
    # Check version
    version_bits = header_bits[13:15]
    if not np.array_equal(version_bits, [0, 0]):
        # Version mismatch, but try to decode anyway
        pass
    
    # Extract message length
    msg_len_bits = header_bits[15:23]
    msg_len_bytes = int(''.join(map(str, msg_len_bits)), 2)
    
    return True, msg_len_bytes
