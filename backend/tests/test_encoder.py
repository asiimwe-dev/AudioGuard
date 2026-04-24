"""
Unit tests for AudioGuard Encoder (Phase 1)

Tests core STFT encoding pipeline, bit-spreading, and audio I/O.
"""

import pytest
import numpy as np
import soundfile as sf
from pathlib import Path
import tempfile
import sys

# Add engine to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from engine import AudioGuardEncoder, stft, inverse_stft
from engine.utils import text_to_binary, binary_to_text


class TestUtilities:
    """Test DSP utility functions."""

    def test_text_to_binary(self):
        """Test text to binary conversion."""
        # ASCII 'A' = 65 = 01000001
        assert text_to_binary("A") == "01000001"
        # Test multi-character
        binary = text_to_binary("dev")
        assert len(binary) == 24  # 3 chars × 8 bits
        assert binary == "011001000110010101110110"

    def test_binary_to_text(self):
        """Test binary to text conversion."""
        binary = "01000001"  # 'A'
        assert binary_to_text(binary) == "A"
        # Test round-trip
        original = "AudioGuard"
        binary = text_to_binary(original)
        assert binary_to_text(binary) == original

    def test_binary_conversion_roundtrip(self):
        """Test text->binary->text roundtrip."""
        test_messages = ["A", "dev", "AUTHOR_001", "Phase1"]
        for msg in test_messages:
            binary = text_to_binary(msg)
            recovered = binary_to_text(binary)
            assert recovered == msg, f"Roundtrip failed for '{msg}'"

    def test_binary_to_text_invalid_length(self):
        """Test binary_to_text rejects invalid lengths."""
        with pytest.raises(ValueError):
            binary_to_text("0100000")  # 7 bits, not multiple of 8


class TestSTFT:
    """Test STFT forward and inverse transforms."""

    def test_stft_shape(self):
        """Test STFT produces correct output shape."""
        # Create test signal: 2 seconds at 44.1kHz
        sample_rate = 44100
        duration = 2.0
        audio = np.random.randn(int(sample_rate * duration)).astype(np.float32)

        magnitude, phase, freq_bins = stft(audio, frame_size=2048)

        assert magnitude.ndim == 2, "Magnitude should be 2D (frames × bins)"
        assert phase.ndim == 2, "Phase should be 2D"
        assert magnitude.shape == phase.shape, "Magnitude and phase should match"
        assert magnitude.shape[1] == 1025, "Expected 1025 frequency bins for frame_size=2048"

    def test_stft_inverse_reconstruction(self):
        """Test STFT->inverse STFT reconstruction accuracy."""
        # Create simple test signal (sine wave)
        sample_rate = 44100
        duration = 1.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio = 0.5 * np.sin(2 * np.pi * 440 * t).astype(np.float32)

        # Forward STFT
        magnitude, phase, _ = stft(audio, frame_size=2048)

        # Inverse STFT
        reconstructed = inverse_stft(magnitude, phase, frame_size=2048)

        # Trim to original length
        reconstructed = reconstructed[: len(audio)]

        # Check reconstruction error
        mse = np.mean((audio - reconstructed) ** 2)
        correlation = np.corrcoef(audio, reconstructed)[0, 1]

        assert mse < 0.01, f"Reconstruction MSE too high: {mse}"
        assert correlation > 0.99, f"Reconstruction correlation too low: {correlation}"

    def test_stft_magnitude_positive(self):
        """Test that STFT magnitude is always non-negative."""
        audio = np.random.randn(44100).astype(np.float32)
        magnitude, _, _ = stft(audio)

        assert np.all(magnitude >= 0), "Magnitude should be non-negative"


class TestAudioGuardEncoder:
    """Test the main AudioGuardEncoder class."""

    @pytest.fixture
    def test_audio(self):
        """Fixture providing test audio data."""
        sample_rate = 44100
        duration = 2.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio = 0.3 * np.sin(2 * np.pi * 440 * t).astype(np.float32)
        return audio, sample_rate

    @pytest.fixture
    def test_wav_file(self, test_audio):
        """Fixture providing a temporary test WAV file."""
        audio, sample_rate = test_audio
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            sf.write(tmp.name, audio, sample_rate)
            yield tmp.name
            Path(tmp.name).unlink()

    def test_encoder_initialization(self):
        """Test encoder initialization with various parameters."""
        encoder = AudioGuardEncoder()
        assert encoder.frame_size == 2048
        assert encoder.hop_size == 1024
        assert encoder.amplitude_factor == 0.05
        assert encoder.seed == 42

        # Test custom parameters
        encoder = AudioGuardEncoder(frame_size=4096, amplitude_factor=0.1, seed=123)
        assert encoder.frame_size == 4096
        assert encoder.amplitude_factor == 0.1
        assert encoder.seed == 123

    def test_encoder_encode_basic(self, test_wav_file):
        """Test basic encoding workflow."""
        encoder = AudioGuardEncoder(amplitude_factor=0.05)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as output:
            output_path = output.name

        try:
            metadata = encoder.encode(
                input_audio_path=test_wav_file,
                output_audio_path=output_path,
                message="test",
                bits_per_frame=4,
            )

            # Check metadata
            assert metadata["message"] == "test"
            assert metadata["sample_rate"] == 44100
            assert metadata["duration"] == pytest.approx(2.0, abs=0.01)
            assert len(metadata["bit_sequence"]) == 32  # 4 chars × 8 bits

            # Check output file exists and is valid
            assert Path(output_path).exists()
            watermarked, sr = sf.read(output_path, dtype="float32")
            assert sr == 44100
            assert len(watermarked) > 0

        finally:
            Path(output_path).unlink(missing_ok=True)

    def test_encoder_preserves_sample_rate(self, test_audio):
        """Test that encoder preserves original sample rate."""
        audio, sr = test_audio

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as input_file:
            sf.write(input_file.name, audio, sr)
            input_path = input_file.name

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as output:
            output_path = output.name

        try:
            encoder = AudioGuardEncoder()
            encoder.encode(input_path, output_path, "test")

            watermarked, sr_out = sf.read(output_path, dtype="float32")
            assert sr_out == sr, f"Sample rate mismatch: {sr_out} != {sr}"

        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)

    def test_encoder_output_normalized(self, test_wav_file):
        """Test that output is normalized to prevent clipping."""
        encoder = AudioGuardEncoder()

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as output:
            output_path = output.name

        try:
            encoder.encode(test_wav_file, output_path, "test")
            watermarked, _ = sf.read(output_path, dtype="float32")

            # Check max amplitude is reasonable (< 1.0 to avoid clipping)
            assert np.max(np.abs(watermarked)) <= 1.0

        finally:
            Path(output_path).unlink(missing_ok=True)

    def test_encoder_empty_message_raises(self, test_wav_file):
        """Test that empty message raises ValueError."""
        encoder = AudioGuardEncoder()

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as output:
            output_path = output.name

        try:
            with pytest.raises(ValueError, match="empty"):
                encoder.encode(test_wav_file, output_path, "")
        finally:
            Path(output_path).unlink(missing_ok=True)

    def test_encoder_missing_file_raises(self):
        """Test that missing input file raises FileNotFoundError."""
        encoder = AudioGuardEncoder()

        with pytest.raises(FileNotFoundError):
            encoder.encode("/nonexistent/file.wav", "output.wav", "test")

    def test_encoder_deterministic_seeding(self, test_wav_file):
        """Test that same seed produces consistent results."""
        encoder1 = AudioGuardEncoder(seed=42, amplitude_factor=0.05)
        encoder2 = AudioGuardEncoder(seed=42, amplitude_factor=0.05)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as out1:
            path1 = out1.name
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as out2:
            path2 = out2.name

        try:
            encoder1.encode(test_wav_file, path1, "test")
            encoder2.encode(test_wav_file, path2, "test")

            # Read both outputs
            audio1, _ = sf.read(path1, dtype="float32")
            audio2, _ = sf.read(path2, dtype="float32")

            # Should be bitwise identical with same seed
            correlation = np.corrcoef(audio1, audio2)[0, 1]
            assert correlation > 0.9999, "Same seed should produce nearly identical results"

        finally:
            Path(path1).unlink(missing_ok=True)
            Path(path2).unlink(missing_ok=True)

    def test_encoder_bit_spreading_parameters(self, test_wav_file):
        """Test encoder with various bit-spreading parameters."""
        for bits_per_frame in [2, 4, 8]:
            encoder = AudioGuardEncoder()

            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as output:
                output_path = output.name

            try:
                metadata = encoder.encode(
                    test_wav_file,
                    output_path,
                    "msg",
                    bits_per_frame=bits_per_frame,
                )

                assert metadata["spread_info"]["bits_per_frame"] == bits_per_frame

            finally:
                Path(output_path).unlink(missing_ok=True)


class TestIntegration:
    """Integration tests combining multiple components."""

    def test_full_pipeline(self):
        """Test complete encoding pipeline."""
        # Create test audio
        sample_rate = 44100
        duration = 1.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio = 0.3 * np.sin(2 * np.pi * 440 * t).astype(np.float32)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as input_file:
            sf.write(input_file.name, audio, sample_rate)
            input_path = input_file.name

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as output:
            output_path = output.name

        try:
            # Encode
            encoder = AudioGuardEncoder(amplitude_factor=0.05)
            metadata = encoder.encode(
                input_path,
                output_path,
                "AudioGuard",
                bits_per_frame=4,
            )

            # Verify results
            assert Path(output_path).exists()
            assert metadata["message"] == "AudioGuard"
            assert metadata["sample_rate"] == sample_rate
            assert len(metadata["bit_sequence"]) == 80  # 10 chars × 8 bits

            # Read and validate watermarked audio
            watermarked, sr = sf.read(output_path, dtype="float32")
            assert sr == sample_rate
            assert len(watermarked) == len(audio)

        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
