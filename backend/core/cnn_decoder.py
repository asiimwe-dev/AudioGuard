"""Server-side CNN decoder wrapper.

This module provides a simple interface to a CNN-based watermark decoder.
It attempts to load a PyTorch or TFLite model if configured, otherwise marks
itself unavailable. The goal is to provide a drop-in fallback: call
CNNDecoder.decode(audio_path) -> (message_or_none, confidence_float).

Training and model artifacts are out-of-scope for this change; this file
adds the integration points and a permissive fallback to classical decode
when no trained model is installed.
"""

from __future__ import annotations

import os
import logging
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

MODEL_PATH = os.getenv("AUDIOGUARD_CNN_MODEL", "backend/models/detector.pt")

try:
    import torch
    TORCH_AVAILABLE = True
except Exception:
    TORCH_AVAILABLE = False

try:
    import tensorflow as tf
    TF_AVAILABLE = True
except Exception:
    TF_AVAILABLE = False


class CNNDecoder:
    """Wrapper that exposes decode(audio_path) -> (message, confidence)

    If a real model is present and loadable, inference is performed. If not,
    `available` is False and decode() should not be relied upon for production
    — it will return (None, 0.0).
    """

    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or MODEL_PATH
        self.available = False
        self._model = None

        # Try loading PyTorch model first
        if TORCH_AVAILABLE and os.path.exists(self.model_path):
            try:
                logger.info("Loading CNN model (PyTorch) from %s", self.model_path)
                # Best-effort: load state_dict only - model architecture must match
                # In production, replace this with the actual model class import.
                self._model = torch.load(self.model_path, map_location="cpu")
                # If state dict, keep as-is; full model objects still work too
                self.available = True
            except Exception as exc:
                logger.warning("Failed to load PyTorch CNN model: %s", exc)
                self._model = None
                self.available = False

        # Fallback: TFLite model path (detector.tflite)
        elif TF_AVAILABLE and os.path.exists(self.model_path.replace('.pt', '.tflite')):
            try:
                tflite_path = self.model_path.replace('.pt', '.tflite')
                logger.info("Loading CNN model (TFLite) from %s", tflite_path)
                self._interpreter = tf.lite.Interpreter(model_path=tflite_path)
                self._interpreter.allocate_tensors()
                self.available = True
            except Exception as exc:
                logger.warning("Failed to load TFLite CNN model: %s", exc)
                self.available = False
        else:
            logger.info("No CNN model found at %s (TORCH=%s TF=%s)", self.model_path, TORCH_AVAILABLE, TF_AVAILABLE)
            self.available = False

    def decode(self, audio_path: str) -> Tuple[Optional[str], float]:
        """Run CNN inference on audio file and return (message, confidence).

        If no model is available, returns (None, 0.0). Implementers should
        replace this with a proper preprocessing + model forward pass.
        """
        if not self.available:
            return None, 0.0

        # NOTE: Placeholder behavior: when a full model integration is added,
        # this method should compute spectrogram input, run model, and map
        # outputs to message+confidence.
        try:
            # If PyTorch checkpoint contains a callable object, try invoking it
            if TORCH_AVAILABLE and callable(self._model):
                out = self._model(audio_path)
                # Expect (message, confidence) from model wrapper
                if isinstance(out, tuple) and len(out) == 2:
                    return out[0], float(out[1])

            # If state dict loaded, real model integration required
            logger.warning("CNN model loaded but no inference wrapper available. Please integrate model class.")
            return None, 0.0
        except Exception as exc:
            logger.exception("CNN inference failed: %s", exc)
            return None, 0.0
