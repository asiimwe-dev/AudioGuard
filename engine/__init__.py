"""AudioGuard Spectral Engine - Phase 1, 2 & 3"""

from .encoder import AudioGuardEncoder
from .decoder import AudioGuardDecoder
from .utils import stft, inverse_stft, text_to_binary, binary_to_text
from .psychoacoustic import (
    ISO226MaskingModel,
    AdaptiveAmplitudeFactor,
    create_frequency_array,
)

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
    # Phase 2
    "AudioGuardDecoder",
    "ISO226MaskingModel",
    "AdaptiveAmplitudeFactor",
    "create_frequency_array",
]

# Add Phase 3 if available
if PHASE3_AVAILABLE:
    __all__.extend([
        "WatermarkDetectorCNN",
        "FocalLoss",
        "create_watermark_detector",
        "CNNWatermarkDecoder",
    ])
