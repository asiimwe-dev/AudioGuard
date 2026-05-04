"""AudioGuard Spectral Engine - Phase 1, 2 & 3"""

from .encoder import AudioGuardEncoder
from .decoder import AudioGuardDecoder
from .utils import stft, inverse_stft, text_to_binary, binary_to_text
from .psychoacoustic import (
    ISO226MaskingModel,
    AdaptiveAmplitudeFactor,
    create_frequency_array,
)
from .ecc import MessageECC, encode_message_with_ecc, decode_message_with_ecc, ECC_AVAILABLE
from .sync import SyncDetector, BarkerCodes, create_sync_header, parse_sync_header

# Phase 2 (Multi-Resolution)
from .multi_res_stft import (
    stft_multiresolution,
    inverse_stft_multiresolution,
    align_multiresolution_stfts,
    combine_multiresolution_bits,
    extract_multiresolution_confidence,
)
from .encoder_multiresolution import EncoderMultiResolution
from .decoder_multiresolution import MultiResolutionDecoder

# Phase 3 imports (conditional on PyTorch availability)
try:
    from .cnn_model import WatermarkDetectorCNN, FocalLoss, create_watermark_detector
    from .cnn_decoder import CNNWatermarkDecoder
    PHASE3_AVAILABLE = True
except ImportError:
    PHASE3_AVAILABLE = False

__all__ = [
    # Phase 1
    "AudioGuardEncoder",
    "stft",
    "inverse_stft",
    "text_to_binary",
    "binary_to_text",
    # Phase 1.5 (Robustness: ECC, Sync, Storage)
    "MessageECC",
    "encode_message_with_ecc",
    "decode_message_with_ecc",
    "ECC_AVAILABLE",
    "SyncDetector",
    "BarkerCodes",
    "create_sync_header",
    "parse_sync_header",
    # Phase 2 (Decoder + Multi-Res)
    "AudioGuardDecoder",
    "ISO226MaskingModel",
    "AdaptiveAmplitudeFactor",
    "create_frequency_array",
    # Phase 2 (Multi-Resolution)
    "stft_multiresolution",
    "inverse_stft_multiresolution",
    "align_multiresolution_stfts",
    "combine_multiresolution_bits",
    "extract_multiresolution_confidence",
    "EncoderMultiResolution",
    "MultiResolutionDecoder",
]

# Add Phase 3 if available
if PHASE3_AVAILABLE:
    __all__.extend([
        "WatermarkDetectorCNN",
        "FocalLoss",
        "create_watermark_detector",
        "CNNWatermarkDecoder",
    ])
