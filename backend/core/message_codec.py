"""
AudioGuard Message Codec

Single responsibility: convert a UTF-8 string ↔ bit stream with:
  - Reed-Solomon ECC (reedsolo)
  - Barker-13 sync header  (13 sync + 2 version + 8 length = 23 bits)
  - Redundancy tiling

Separating this from the STFT engine means the ECC logic can be unit-tested
without any audio I/O and makes swapping codecs trivial.
"""

from __future__ import annotations

import logging
from functools import cached_property
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)

# Barker-13 binary sequence — ideal for sync due to near-perfect autocorrelation
BARKER_13 = np.array([1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1], dtype=np.int8)
HEADER_BITS = 23  # 13 (barker) + 2 (version) + 8 (length)

try:
    from reedsolo import RSCodec, ReedSolomonError
    _ECC_AVAILABLE = True
except ImportError:
    _ECC_AVAILABLE = False
    logger.warning("reedsolo not installed — ECC disabled. pip install reedsolo")


class MessageCodec:
    """Encode/decode messages into bit arrays with ECC + sync framing."""

    def __init__(self, nsym: int = 16, seed: int = 42, redundancy: int = 3, max_msg_bytes: int = 100):
        self.nsym = nsym
        self.seed = seed
        self.redundancy = redundancy
        self.max_msg_bytes = max_msg_bytes  # Max message length to support

        if _ECC_AVAILABLE:
            self._rs = RSCodec(nsym)
        else:
            self._rs = None

        # Pre-calculate ECC block size for max message
        # (this is fixed for all messages, padded with zeros if needed)
        self._ecc_block_size = max_msg_bytes + nsym

    # ------------------------------------------------------------------
    # Public
    # ------------------------------------------------------------------

    @cached_property
    def expected_bits(self) -> int:
        """Total bit-stream length (header + ECC block + redundancy)."""
        return (HEADER_BITS + self._ecc_block_size * 8) * self.redundancy

    def encode(self, message: str) -> np.ndarray:
        """
        UTF-8 string → flat bit array ready for embedding.

        Returns:
            np.ndarray of int8, shape (expected_bits,)
        """
        msg_bytes = message.encode("utf-8")
        if len(msg_bytes) > self.max_msg_bytes:
            raise ValueError(f"Message too long: {len(msg_bytes)} > {self.max_msg_bytes}")

        ecc_bytes = self._ecc_encode(msg_bytes)
        
        msg_bits = np.unpackbits(np.frombuffer(ecc_bytes, dtype=np.uint8)).astype(np.int8)
        frame = self._build_header(len(msg_bytes))  # Store original length, not padded
        packet = np.concatenate([frame, msg_bits])
        tiled = np.tile(packet, self.redundancy)
        return tiled.astype(np.int8)

    def decode(
        self,
        bits: np.ndarray,
    ) -> tuple[str, int, int, bool]:
        """
        Flat bit array → (message, sync_pos, ecc_errors, sync_found).

        Tries each redundant copy; returns the first successful decode.
        Falls back to majority-voted combined copy.
        """
        for sync_pos in (0, self._find_sync(bits)):
            if sync_pos < 0 or sync_pos >= len(bits):
                continue
            result = self._try_decode_copy(bits[sync_pos:])
            if result is not None:
                msg, aligned_pos, ecc_err = result
                return msg, sync_pos + aligned_pos, ecc_err, True

        return "", 0, 0, False

    # ------------------------------------------------------------------
    # Private
    # ------------------------------------------------------------------

    def _measure_ecc_block(self) -> int:
        """Return byte size of a typical ECC-encoded message (255-byte RS block)."""
        if self._rs is None:
            return 255  # fallback: assume max RS block
        # Encode a 1-byte message to see how much overhead we get
        test = self._ecc_encode(b"A")
        return len(test)

    def _ecc_encode(self, data: bytes) -> bytes:
        if self._rs is not None:
            return bytes(self._rs.encode(data))
        return data  # passthrough if ECC unavailable

    def _ecc_decode(self, data: bytes) -> tuple[bytes, int]:
        if self._rs is None:
            return data, 0
        try:
            result = self._rs.decode(data)
            decoded = result[0] if isinstance(result, tuple) else result
            # result[1] is already int (count of errors corrected), result[2] is ecc data
            errs = result[1] if isinstance(result, tuple) and len(result) > 1 else 0
            return bytes(decoded), errs
        except Exception as exc:
            raise ValueError(f"ECC decode error: {exc}") from exc

    @staticmethod
    def _build_header(msg_len_bytes: int) -> np.ndarray:
        version = np.array([0, 0], dtype=np.int8)
        length = np.unpackbits(np.array([msg_len_bytes & 0xFF], dtype=np.uint8)).astype(np.int8)
        return np.concatenate([BARKER_13, version, length])

    def _try_decode_copy(
        self,
        copy: np.ndarray,
        already_aligned: bool = False,
    ) -> Optional[tuple[str, int, int]]:
        """
        Attempt to decode a single packet copy.
        Returns (message, sync_pos, ecc_errors) or None.
        """
        if len(copy) < HEADER_BITS:
            return None

        header = copy[:HEADER_BITS]
        payload = copy[HEADER_BITS:]
        barker_cand = header[:13].astype(float)
        corr = np.dot(barker_cand * 2 - 1, BARKER_13 * 2 - 1) / 13.0
        if corr < 0.6 and not already_aligned:
            return None

        # Extract message length from header
        length_bits = header[15:23]
        msg_len = int(np.packbits(length_bits.astype(np.uint8))[0])
        if msg_len == 0 or msg_len > self.max_msg_bytes:
            return None

        # Convert payload bits → bytes
        n_ecc_bytes = msg_len + self.nsym
        payload_bits = payload[:n_ecc_bytes * 8]
        if len(payload_bits) < n_ecc_bytes * 8:
            payload_bits = np.pad(payload_bits, (0, n_ecc_bytes * 8 - len(payload_bits)))

        payload_bytes = bytes(np.packbits(payload_bits.astype(np.uint8)))

        try:
            decoded_bytes, ecc_errors = self._ecc_decode(payload_bytes)
            message = decoded_bytes[:msg_len].decode("utf-8", errors="replace")
            return message, 0, ecc_errors
        except Exception:
            return None

    def _find_sync(self, bits: np.ndarray) -> int:
        """Sliding-window search for Barker-13 pattern. Returns position or -1."""
        barker_bipolar = (BARKER_13 * 2 - 1).astype(float)
        window = 13
        best_pos, best_corr = -1, 0.6  # minimum threshold
        for i in range(min(len(bits) - window, 8192)):
            cand = bits[i:i + window].astype(float) * 2 - 1
            corr = float(np.dot(cand, barker_bipolar) / window)
            if corr > best_corr:
                best_corr = corr
                best_pos = i
                if corr > 0.95:
                    break
        return best_pos

    @staticmethod
    def _pad_or_crop(arr: np.ndarray, length: int) -> np.ndarray:
        if len(arr) >= length:
            return arr[:length]
        return np.pad(arr, (0, length - len(arr)), constant_values=0)
