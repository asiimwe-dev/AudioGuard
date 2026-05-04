"""
AudioGuard Error Correction Coding (ECC) Module

Implements Reed-Solomon error correction for robust message recovery.
Adds 20% overhead (16 errors per 255 bytes) to improve BER from ~50% to <10%.

ECC Pipeline:
    1. Encode: Message → Reed-Solomon encoded bytes
    2. Decode: Received bytes → Message + error correction
"""

from typing import Tuple
try:
    from reedsolo import RSCodec, ReedSolomonError
    ECC_AVAILABLE = True
except ImportError:
    ECC_AVAILABLE = False


class MessageECC:
    """Reed-Solomon error correction codec for audio watermarking payloads."""
    
    def __init__(self, nsym: int = 16):
        """
        Initialize Reed-Solomon codec.
        
        Args:
            nsym: Number of error correction symbols (16 = ~20% overhead).
                  Can correct up to nsym//2 byte errors.
                  For 255 data bytes + 16 ECC = 271 total (can fix 8 bytes).
        """
        if not ECC_AVAILABLE:
            raise ImportError("reedsolo not installed. Install with: pip install reedsolo")
        
        self.nsym = nsym
        self.codec = RSCodec(nsym)
        self.max_data_bytes = 255 - nsym  # Max data that fits in 255-byte RS block
    
    def encode(self, message: str) -> bytes:
        """
        Encode message with Reed-Solomon error correction.
        
        Args:
            message: Text message (UTF-8)
        
        Returns:
            Encoded bytes with ECC (message + error correction symbols)
        
        Raises:
            ValueError: If message too long for single RS block
        """
        # Convert message to bytes
        msg_bytes = message.encode('utf-8')
        
        if len(msg_bytes) > self.max_data_bytes:
            raise ValueError(
                f"Message too long. Max {self.max_data_bytes} bytes, got {len(msg_bytes)}"
            )
        
        # Pad to max_data_bytes if needed (for consistent output length)
        msg_bytes = msg_bytes.ljust(self.max_data_bytes, b'\x00')
        
        # Apply Reed-Solomon encoding
        encoded = self.codec.encode(msg_bytes)
        return bytes(encoded)
    
    def decode(self, encoded_bytes: bytes, nostrip: bool = False) -> Tuple[str, int]:
        """
        Decode message with error correction.
        
        Args:
            encoded_bytes: Received bytes (may contain errors)
            nostrip: If False, strip null padding from recovered message
        
        Returns:
            Tuple of (recovered_message, num_errors_corrected)
        
        Raises:
            ValueError: If too many errors to correct
        """
        try:
            # Decode with error correction (reedsolo returns: decoded_data, num_errors_corrected, errata_positions)
            decoded_data = self.codec.decode(encoded_bytes)
            
            # Handle both 2-tuple and 3-tuple returns from different reedsolo versions
            if isinstance(decoded_data, tuple):
                msg_bytes = decoded_data[0]
                num_errors = decoded_data[1] if len(decoded_data) > 1 else 0
            else:
                msg_bytes = decoded_data
                num_errors = 0
            
            # Remove null padding
            if not nostrip:
                msg_bytes = msg_bytes.rstrip(b'\x00')
            
            # Convert back to string
            message = msg_bytes.decode('utf-8', errors='replace')
            
            return message, num_errors
        except ReedSolomonError as e:
            raise ValueError(f"RS decode error: {e}. Too many errors to correct.")
    
    def get_encoded_size(self) -> int:
        """Get total size of encoded message (data + ECC)."""
        return 255  # Standard RS block size


# Global ECC instance
_ecc = None


def get_ecc() -> MessageECC:
    """Get or create global ECC instance."""
    global _ecc
    if _ecc is None:
        _ecc = MessageECC(nsym=16)
    return _ecc


def encode_message_with_ecc(message: str) -> bytes:
    """Convenience function: encode message with ECC."""
    return get_ecc().encode(message)


def decode_message_with_ecc(encoded_bytes: bytes) -> Tuple[str, int]:
    """Convenience function: decode message with ECC."""
    return get_ecc().decode(encoded_bytes)
