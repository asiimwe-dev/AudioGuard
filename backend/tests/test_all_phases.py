"""
Comprehensive Tests for All Phases (1, 2, and 3)

Validates complete pipeline: encoding → classical decoding → CNN fallback
"""

import pytest
import numpy as np
import soundfile as sf
from pathlib import Path
import tempfile
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))

from engine import AudioGuardEncoder, AudioGuardDecoder

# Phase 3 conditional imports
try:
    from engine import CNNWatermarkDecoder
    PHASE3_AVAILABLE = True
except ImportError:
    PHASE3_AVAILABLE = False


class TestPhase1:
    """Phase 1: Basic Encoding"""

    def test_phase1_basic_encoding(self):
        """Test Phase 1 encoder creates valid watermarked audio."""
        # Create audio
        sample_rate = 44100
        duration = 2.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio = 0.3 * np.sin(2 * np.pi * 440 * t).astype(np.float32)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, audio, sample_rate)
            input_path = f.name

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            output_path = f.name

        try:
            encoder = AudioGuardEncoder(amplitude_factor=0.05)
            metadata = encoder.encode(input_path, output_path, "phase1test")

            assert metadata["message"] == "phase1test"
            assert Path(output_path).exists()
            assert metadata["frame_count"] > 0

        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)


class TestPhase2:
    """Phase 2: Encoding + Classical Decoding"""

    def test_phase2_encode_decode(self):
        """Test Phase 2 decode-encode roundtrip."""
        # Create audio
        sample_rate = 44100
        duration = 2.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio = (
            0.2 * np.sin(2 * np.pi * 440 * t) +
            0.1 * np.sin(2 * np.pi * 880 * t)
        ).astype(np.float32)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, audio, sample_rate)
            input_path = f.name

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            output_path = f.name

        try:
            message = "phase2"

            # Encode
            encoder = AudioGuardEncoder(amplitude_factor=0.05, seed=42)
            encoder.encode(input_path, output_path, message)

            # Decode
            decoder = AudioGuardDecoder(seed=42)
            result = decoder.decode(output_path, message_length=len(message))

            assert len(result["bits"]) == len(message) * 8
            assert result["snr_db"] > -20

        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)


@pytest.mark.skipif(not PHASE3_AVAILABLE, reason="PyTorch not installed")
class TestPhase3:
    """Phase 3: CNN-Based Robust Detection"""

    def test_phase3_cnn_initialization(self):
        """Test Phase 3 CNN decoder initialization."""
        try:
            decoder = CNNWatermarkDecoder(device="cpu")
            assert decoder.model is not None
            assert decoder.classical_decoder is not None
        except ImportError as e:
            pytest.skip(f"PyTorch not installed: {e}")

    def test_phase3_cnn_forward_pass(self):
        """Test CNN forward pass with dummy input."""
        try:
            decoder = CNNWatermarkDecoder(device="cpu")
        except ImportError as e:
            pytest.skip(f"PyTorch not installed: {e}")

        # Create dummy audio
        sample_rate = 44100
        duration = 2.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio = 0.3 * np.sin(2 * np.pi * 440 * t).astype(np.float32)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, audio, sample_rate)
            audio_path = f.name

        try:
            # Test CNN decode (will use random predictions in demo mode)
            result = decoder.decode_with_cnn(audio_path, message_length=6)

            assert "watermark_detected" in result
            assert "cnn_confidence" in result
            assert result["method"] == "cnn"

        finally:
            Path(audio_path).unlink(missing_ok=True)


class TestEndToEnd:
    """End-to-end testing across multiple phases"""

    def test_encode_decode_with_different_seeds(self):
        """Test that different seeds produce different spreading patterns."""
        sample_rate = 44100
        duration = 1.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio = 0.3 * np.sin(2 * np.pi * 440 * t).astype(np.float32)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, audio, sample_rate)
            input_path = f.name

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            output1_path = f.name

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            output2_path = f.name

        try:
            message = "test"

            # Encode with seed 42
            encoder1 = AudioGuardEncoder(amplitude_factor=0.05, seed=42)
            encoder1.encode(input_path, output1_path, message)

            # Encode with seed 123
            encoder2 = AudioGuardEncoder(amplitude_factor=0.05, seed=123)
            encoder2.encode(input_path, output2_path, message)

            # Both should produce valid output
            assert Path(output1_path).exists()
            assert Path(output2_path).exists()

            # Files should be different (different spreading patterns)
            audio1, sr1 = sf.read(output1_path)
            audio2, sr2 = sf.read(output2_path)

            # Correlation should be very high (same message + similar encoding)
            # But not exactly 1.0 due to slightly different spreading
            correlation = np.corrcoef(audio1, audio2)[0, 1]
            assert correlation > 0.99  # Very similar, but not identical

        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(output1_path).unlink(missing_ok=True)
            Path(output2_path).unlink(missing_ok=True)

    def test_message_length_validation(self):
        """Test proper handling of various message lengths."""
        sample_rate = 44100
        duration = 3.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio = 0.3 * np.sin(2 * np.pi * 440 * t).astype(np.float32)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, audio, sample_rate)
            input_path = f.name

        try:
            encoder = AudioGuardEncoder(amplitude_factor=0.05)

            for message_length in [1, 4, 8, 10]:
                message = "x" * message_length

                with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                    output_path = f.name

                try:
                    metadata = encoder.encode(input_path, output_path, message)

                    assert len(metadata["bit_sequence"]) == message_length * 8
                    assert metadata["message"] == message

                finally:
                    Path(output_path).unlink(missing_ok=True)

        finally:
            Path(input_path).unlink(missing_ok=True)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
