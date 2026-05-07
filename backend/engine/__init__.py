"""
AudioGuard Spectral Engine
Professional digital watermarking suite using multi-resolution STFT and Reed-Solomon ECC.
"""

# Core Engines
from .encoder_multiresolution import EncoderMultiResolution
from .decoder_multiresolution import MultiResolutionDecoder

# Components
from .multi_res_stft import stft_multiresolution, inverse_stft_multiresolution, combine_multiresolution_bits
from .bit_extraction import extract_bits_by_energy_adaptive, extract_bits_hybrid
from .ecc import RSECCEncoder, RSECCDecoder
from .psychoacoustic import PsychoacousticModel

# Legacy / Alternative Components
from .encoder import AudioGuardEncoder
from .decoder import AudioGuardDecoder

__all__ = [
    # Production Architecture
    "EncoderMultiResolution",
    "MultiResolutionDecoder",
    "stft_multiresolution",
    "inverse_stft_multiresolution",
    "combine_multiresolution_bits",
    "extract_bits_by_energy_adaptive",
    "extract_bits_hybrid",
    "RSECCEncoder",
    "RSECCDecoder",
    "PsychoacousticModel",
    
    # Legacy Engines
    "AudioGuardEncoder",
    "AudioGuardDecoder"
]
