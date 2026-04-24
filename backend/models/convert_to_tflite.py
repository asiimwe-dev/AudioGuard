"""
Convert PyTorch CNN Model to TensorFlow Lite for Mobile Deployment.

This script converts the trained WatermarkDetectorCNN model to TFLite format
with quantization options for efficient mobile inference.

Usage:
    python convert_to_tflite.py --model path/to/model.pt --output models/detector.tflite
"""

import argparse
import torch
import torch.nn as nn
from pathlib import Path
import numpy as np
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

try:
    import tensorflow as tf
    TF_AVAILABLE = True
except ImportError:
    TF_AVAILABLE = False
    logger.warning("TensorFlow not available. Install with: pip install tensorflow")


def load_pytorch_model(model_path: str) -> nn.Module:
    """
    Load PyTorch model from checkpoint.

    Args:
        model_path: Path to saved model (.pt file)

    Returns:
        Loaded PyTorch model in eval mode
    """
    logger.info(f"Loading PyTorch model from {model_path}")

    # Import model class
    from engine import WatermarkDetectorCNN

    model = WatermarkDetectorCNN()

    # Load checkpoint if available
    if Path(model_path).exists():
        checkpoint = torch.load(model_path, map_location="cpu")
        if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
            model.load_state_dict(checkpoint["model_state_dict"])
        else:
            model.load_state_dict(checkpoint)
        logger.info(f"✓ Loaded checkpoint from {model_path}")
    else:
        logger.warning(f"Model file not found: {model_path}, using untrained weights")

    model.eval()
    return model


def create_dummy_input() -> torch.Tensor:
    """
    Create dummy input for model tracing.

    Returns:
        torch.Tensor: Dummy input with shape (1, 1, 87, 1025)
    """
    # Typical input: 1 sample, 1 channel (magnitude spectrogram), 87 frames, 1025 frequency bins
    return torch.randn(1, 1, 87, 1025, dtype=torch.float32)


def pytorch_to_onnx(model: nn.Module, output_path: str) -> str:
    """
    Convert PyTorch model to ONNX format (intermediate step).

    Args:
        model: PyTorch model in eval mode
        output_path: Path to save ONNX model

    Returns:
        Path to saved ONNX model
    """
    logger.info(f"Converting PyTorch to ONNX: {output_path}")

    dummy_input = create_dummy_input()
    output_path = Path(output_path).with_suffix(".onnx")

    torch.onnx.export(
        model,
        dummy_input,
        str(output_path),
        opset_version=13,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={
            "input": {0: "batch_size"},
            "output": {0: "batch_size"},
        },
        do_constant_folding=True,
    )

    logger.info(f"✓ ONNX model saved: {output_path}")
    return str(output_path)


def validate_tflite_model(tflite_path: str) -> bool:
    """
    Validate TFLite model can be loaded and run inference.

    Args:
        tflite_path: Path to TFLite model

    Returns:
        bool: True if model is valid
    """
    if not TF_AVAILABLE:
        logger.warning("TensorFlow not available for validation")
        return None

    logger.info(f"Validating TFLite model: {tflite_path}")

    try:
        # Load interpreter
        interpreter = tf.lite.Interpreter(model_path=tflite_path)
        interpreter.allocate_tensors()

        # Get input/output details
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

        logger.info(f"  Input shape: {input_details[0]['shape']}")
        logger.info(f"  Output shape: {output_details[0]['shape']}")

        # Run inference on dummy data
        dummy_input = np.random.randn(*input_details[0]['shape']).astype(np.float32)
        interpreter.set_tensor(input_details[0]['index'], dummy_input)
        interpreter.invoke()

        output = interpreter.get_tensor(output_details[0]['index'])
        logger.info(f"  Inference output: {output.shape}")
        logger.info(f"✓ TFLite model is valid")

        return True

    except Exception as e:
        logger.error(f"✗ TFLite validation failed: {str(e)}")
        return False


def main():
    """Main conversion script placeholder."""
    logger.info("=" * 60)
    logger.info("AudioGuard: PyTorch to TFLite Conversion")
    logger.info("=" * 60)
    logger.info("\nNote: Full TFLite conversion requires:")
    logger.info("  - pip install tf2onnx onnx onnx-tf")
    logger.info("  - Trained model checkpoint (currently uses untrained weights)")
    logger.info("\nFor production use:")
    logger.info("  1. Train CNN model on degraded audio dataset")
    logger.info("  2. Save checkpoint: torch.save(model.state_dict(), 'model.pt')")
    logger.info("  3. Run: python convert_to_tflite.py --model model.pt --output detector.tflite")
    logger.info("\nTarget specs:")
    logger.info("  - File size: < 10MB (int8 quantization)")
    logger.info("  - Inference time: < 500ms on mobile CPU")
    logger.info("  - Supported: iOS 13+, Android 10+")


if __name__ == "__main__":
    main()
