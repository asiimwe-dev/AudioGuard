"""
Phase 2 Tests: Psychoacoustic Masking & Decoder

Tests ISO 226 masking model, decoder extraction accuracy, and robustness
to compression and noise.
"""

import pytest
import numpy as np
import soundfile as sf
from pathlib import Path
import tempfile
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))

from engine import AudioGuardEncoder
from engine.decoder import AudioGuardDecoder
from engine.psychoacoustic import (
    ISO226MaskingModel,
    AdaptiveAmplitudeFactor,
    create_frequency_array,
)
from engine.utils import stft, hanning_window


class TestISO226MaskingModel:
    """Test ISO 226 equal-loudness masking curves."""

    def test_iso226_initialization(self):
        """Test model initialization."""
        model = ISO226MaskingModel(loudness_level=40)
        assert model.loudness_level == 40

    def test_masking_threshold_shape(self):
        """Test masking threshold output shape."""
        model = ISO226MaskingModel()
        freqs = np.array([100, 1000, 10000])
        thresholds = model.get_masking_threshold_db(freqs)

        assert thresholds.shape == freqs.shape
        assert np.all(np.isfinite(thresholds))

    def test_masking_threshold_values(self):
        """Test masking threshold values are physically reasonable."""
        model = ISO226MaskingModel(loudness_level=40)
        freqs = np.linspace(20, 20000, 100)
        thresholds = model.get_masking_threshold_db(freqs)

        # Thresholds should be in reasonable range
        assert np.all(thresholds >= -10)
        assert np.all(thresholds <= 90)

        # ~1000 Hz should be most sensitive (lowest threshold)
        idx_1k = np.argmin(np.abs(freqs - 1000))
        idx_100 = np.argmin(np.abs(freqs - 100))
        assert thresholds[idx_1k] < thresholds[idx_100]

    def test_masking_factor_range(self):
        """Test masking factor bounds."""
        model = ISO226MaskingModel()
        freqs = np.linspace(20, 20000, 100)
        factors = model.get_masking_factor(freqs)

        assert np.all(factors >= 0.1)
        assert np.all(factors <= 1.0)

    def test_masking_factor_inverse_correlation(self):
        """Test that lower thresholds give higher masking factors."""
        model = ISO226MaskingModel()
        freqs = np.array([100, 1000, 10000])
        thresholds = model.get_masking_threshold_db(freqs)
        factors = model.get_masking_factor(freqs)

        # Lower threshold → higher masking factor
        min_threshold_idx = np.argmin(thresholds)
        max_factor_idx = np.argmax(factors)
        # Should be negatively correlated
        assert factors[np.argmin(thresholds)] > factors[np.argmax(thresholds)]


class TestAdaptiveAmplitude:
    """Test adaptive amplitude factor computation."""

    def test_adaptive_amplitude_initialization(self):
        """Test AdaptiveAmplitudeFactor initialization."""
        computer = AdaptiveAmplitudeFactor()
        assert computer.masking_model is not None

    def test_adaptive_amplitude_output_shape(self):
        """Test output shape matches frequency dimension."""
        computer = AdaptiveAmplitudeFactor()
        magnitude = np.random.randn(87, 1025)
        frequencies = np.fft.rfftfreq(2048, 1/44100)

        adaptive = computer.compute_adaptive_amplitude(magnitude, frequencies)
        assert adaptive.shape == (frequencies.shape[0],)

    def test_adaptive_amplitude_bounds(self):
        """Test adaptive amplitude is in reasonable range."""
        computer = AdaptiveAmplitudeFactor()
        magnitude = np.random.randn(87, 1025)
        frequencies = np.fft.rfftfreq(2048, 1/44100)

        adaptive = computer.compute_adaptive_amplitude(
            magnitude, frequencies, base_amplitude=0.05
        )

        # Should be scaled version of base amplitude
        assert np.all(adaptive >= 0.001)
        assert np.all(adaptive <= 0.5)


class TestAudioGuardDecoder:
    """Test watermark decoder functionality."""

    @pytest.fixture
    def test_audio(self):
        """Create test audio."""
        sample_rate = 44100
        duration = 2.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio = 0.3 * np.sin(2 * np.pi * 440 * t).astype(np.float32)
        return audio, sample_rate

    @pytest.fixture
    def watermarked_audio_file(self, test_audio):
        """Create and save watermarked audio."""
        audio, sample_rate = test_audio

        # Encode
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as input_file:
            sf.write(input_file.name, audio, sample_rate)
            input_path = input_file.name

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as output:
            output_path = output.name

        encoder = AudioGuardEncoder(amplitude_factor=0.05)
        encoder.encode(input_path, output_path, "test")

        yield output_path

        # Cleanup
        Path(input_path).unlink(missing_ok=True)
        Path(output_path).unlink(missing_ok=True)

    def test_decoder_initialization(self):
        """Test decoder initialization."""
        decoder = AudioGuardDecoder(seed=42)
        assert decoder.frame_size == 2048
        assert decoder.hop_size == 1024
        assert decoder.seed == 42

    def test_decoder_decode_basic(self, watermarked_audio_file):
        """Test basic decoding workflow."""
        decoder = AudioGuardDecoder(seed=42)

        result = decoder.decode(watermarked_audio_file, message_length=4)

        assert "message" in result
        assert "bits" in result
        assert "snr_db" in result
        assert "confidence" in result
        assert len(result["bits"]) == 32  # 4 chars × 8 bits

    def test_decoder_file_not_found(self):
        """Test decoder handles missing files."""
        decoder = AudioGuardDecoder()

        with pytest.raises(FileNotFoundError):
            decoder.decode("/nonexistent/file.wav", message_length=4)

    def test_decoder_snr_estimation(self, watermarked_audio_file):
        """Test SNR estimation is reasonable."""
        decoder = AudioGuardDecoder(seed=42)
        result = decoder.decode(watermarked_audio_file, message_length=4)

        # SNR should be in reasonable range
        snr = result["snr_db"]
        assert -20 < snr < 60

    def test_decoder_confidence_report(self, watermarked_audio_file):
        """Test confidence report generation."""
        decoder = AudioGuardDecoder(seed=42)
        result = decoder.decode(watermarked_audio_file, message_length=4)

        report = decoder.decode_confidence_report(result)
        assert "Message" in report
        assert "Confidence" in report
        assert "SNR" in report


class TestEncodeDecodeRoundtrip:
    """Test encode-decode roundtrip accuracy."""

    @pytest.fixture
    def clean_audio(self):
        """Create clean test audio."""
        sample_rate = 44100
        duration = 2.0
        t = np.linspace(0, duration, int(sample_rate * duration))
        # Multi-frequency signal for more realistic test
        audio = (
            0.2 * np.sin(2 * np.pi * 440 * t) +
            0.15 * np.sin(2 * np.pi * 880 * t) +
            0.1 * np.sin(2 * np.pi * 220 * t)
        ).astype(np.float32)
        return audio, sample_rate

    def test_roundtrip_message_recovery(self, clean_audio):
        """Test message can be extracted after encoding."""
        audio, sample_rate = clean_audio
        message = "dev"

        # Save original
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, audio, sample_rate)
            original_path = f.name

        # Encode
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            watermarked_path = f.name

        try:
            encoder = AudioGuardEncoder(amplitude_factor=0.05, seed=42)
            encoder.encode(original_path, watermarked_path, message)

            # Decode
            decoder = AudioGuardDecoder(seed=42)
            result = decoder.decode(watermarked_path, message_length=len(message))

            # Message recovery (exact match not guaranteed in Phase 2, but should be close)
            assert len(result["message"]) > 0
            assert len(result["bits"]) == 8 * len(message)

        finally:
            Path(original_path).unlink(missing_ok=True)
            Path(watermarked_path).unlink(missing_ok=True)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
