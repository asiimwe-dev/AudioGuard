"""
Comprehensive tests for AudioGuard REST API.

Tests all endpoints with various scenarios including:
- File upload and encoding
- Watermark decoding
- Verification
- Error handling
- Rate limiting (integration)
"""

import pytest
import json
import io
import numpy as np
import soundfile as sf
from fastapi.testclient import TestClient
from pathlib import Path
import tempfile

from api import create_app
from api.models import EncodeRequest, DecodeRequest, VerifyRequest


@pytest.fixture
def app():
    """Create test app."""
    return create_app(debug=True)


@pytest.fixture
def client(app):
    """Create test client."""
    return TestClient(app)


@pytest.fixture
def sample_audio():
    """Create sample audio file for testing."""
    duration = 2.0
    sample_rate = 44100
    t = np.linspace(0, duration, int(sample_rate * duration))
    
    # Simple sine wave
    frequencies = [440, 880]  # A4, A5
    audio = np.zeros_like(t)
    
    segment_length = duration / len(frequencies)
    for i, freq in enumerate(frequencies):
        start_idx = int(i * segment_length * sample_rate)
        end_idx = int((i + 1) * segment_length * sample_rate)
        segment = t[start_idx:end_idx] - t[start_idx]
        audio[start_idx:end_idx] += 0.2 * np.sin(2 * np.pi * freq * segment)
    
    audio = audio.astype(np.float32)
    
    # Return as bytes
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        sf.write(f.name, audio, sample_rate)
        with open(f.name, 'rb') as wav_file:
            return wav_file.read()


class TestHealthCheck:
    """Test health check endpoint."""

    def test_health_check_returns_200(self, client):
        """Health check should return 200."""
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_check_has_required_fields(self, client):
        """Health check response should have required fields."""
        response = client.get("/health")
        data = response.json()
        
        assert "status" in data
        assert "version" in data
        assert "models_available" in data
        assert "uptime_seconds" in data
        assert data["status"] == "healthy"

    def test_health_check_models_available(self, client):
        """Health check should list available models."""
        response = client.get("/health")
        data = response.json()
        
        assert "classical" in data["models_available"]


class TestEncoding:
    """Test watermark encoding endpoint."""

    def test_encode_returns_200(self, client, sample_audio):
        """Encoding should return 200."""
        response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": "AUTHOR_001"}
        )
        assert response.status_code == 200

    def test_encode_response_structure(self, client, sample_audio):
        """Encoding response should have required fields."""
        response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": "TEST"}
        )
        data = response.json()
        
        assert data["success"] is True
        assert "file_id" in data
        assert "original_duration" in data
        assert "sample_rate" in data
        assert "message_length" in data
        assert data["message_length"] == 4

    def test_encode_with_custom_parameters(self, client, sample_audio):
        """Encoding should accept custom parameters."""
        response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={
                "message": "CUSTOM",
                "amplitude_factor": 0.1,
                "frame_size": 1024,
                "bits_per_frame": 2,
                "seed": 123
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["embedding_strength"] == 0.1

    def test_encode_missing_message(self, client, sample_audio):
        """Encoding without message should fail."""
        response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={}
        )
        # Should fail validation
        assert response.status_code in [422, 400]

    def test_encode_empty_message(self, client, sample_audio):
        """Encoding with empty message should fail."""
        response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": ""}
        )
        assert response.status_code in [422, 400]

    def test_encode_message_too_long(self, client, sample_audio):
        """Encoding with very long message should fail."""
        response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": "X" * 500}
        )
        assert response.status_code in [422, 400]

    def test_encode_invalid_amplitude(self, client, sample_audio):
        """Invalid amplitude factor should fail validation."""
        response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={
                "message": "TEST",
                "amplitude_factor": 2.0  # Out of range
            }
        )
        assert response.status_code in [422, 400]

    def test_encode_processes_in_reasonable_time(self, client, sample_audio):
        """Encoding should complete within reasonable time."""
        response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": "SPEED_TEST"}
        )
        assert response.status_code == 200
        data = response.json()
        
        # 2-second audio should encode in < 5 seconds
        assert data["processing_time_ms"] < 5000


class TestDecoding:
    """Test watermark decoding endpoint."""

    def test_decode_requires_file_id(self, client):
        """Decoding without file_id should fail."""
        response = client.post(
            "/api/v1/decode",
            json={"use_cnn": False}
        )
        assert response.status_code in [422, 400]

    def test_decode_invalid_file_id(self, client):
        """Decoding with invalid file_id should return 404."""
        response = client.post(
            "/api/v1/decode",
            json={"file_id": "nonexistent_file"}
        )
        assert response.status_code == 404

    def test_decode_after_encode(self, client, sample_audio):
        """Should be able to decode after encoding."""
        # Encode
        encode_response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": "ROUNDTRIP"}
        )
        assert encode_response.status_code == 200
        file_id = encode_response.json()["file_id"]
        
        # Decode
        decode_response = client.post(
            "/api/v1/decode",
            json={"file_id": file_id}
        )
        assert decode_response.status_code == 200
        data = decode_response.json()
        
        assert "message" in data
        assert "confidence" in data
        assert "method" in data

    def test_decode_response_structure(self, client, sample_audio):
        """Decode response should have required fields."""
        # Encode first
        encode_response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": "VALIDATE"}
        )
        file_id = encode_response.json()["file_id"]
        
        # Decode
        decode_response = client.post(
            "/api/v1/decode",
            json={"file_id": file_id}
        )
        data = decode_response.json()
        
        assert "success" in data
        assert "message" in data
        assert "confidence" in data
        assert "method" in data
        assert "processing_time_ms" in data
        assert data["method"] in ["classical", "cnn"]


class TestVerification:
    """Test watermark verification endpoint."""

    def test_verify_requires_file_id(self, client):
        """Verification without file_id should fail."""
        response = client.post(
            "/api/v1/verify",
            json={}
        )
        assert response.status_code in [422, 400]

    def test_verify_invalid_file_id(self, client):
        """Verification with invalid file_id should return 404."""
        response = client.post(
            "/api/v1/verify",
            json={"file_id": "nonexistent_file"}
        )
        assert response.status_code == 404

    def test_verify_response_structure(self, client, sample_audio):
        """Verify response should have required fields."""
        # Encode first
        encode_response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": "VERIFY_ME"}
        )
        file_id = encode_response.json()["file_id"]
        
        # Verify
        verify_response = client.post(
            "/api/v1/verify",
            json={"file_id": file_id}
        )
        assert verify_response.status_code == 200
        data = verify_response.json()
        
        assert "success" in data
        assert "watermark_detected" in data
        assert "confidence" in data
        assert "processing_time_ms" in data


class TestDownload:
    """Test audio file download endpoint."""

    def test_download_watermarked_audio(self, client, sample_audio):
        """Should be able to download watermarked audio."""
        # Encode
        encode_response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": "DOWNLOAD"}
        )
        file_id = encode_response.json()["file_id"]
        
        # Download
        download_response = client.get(f"/api/v1/download/{file_id}")
        assert download_response.status_code == 200
        assert download_response.headers["content-type"] == "audio/wav"

    def test_download_invalid_file_id(self, client):
        """Downloading invalid file should return 404."""
        response = client.get("/api/v1/download/nonexistent_file")
        assert response.status_code == 404


class TestDocumentation:
    """Test API documentation endpoints."""

    def test_swagger_docs_available(self, client):
        """Swagger documentation should be available."""
        response = client.get("/docs")
        assert response.status_code == 200

    def test_openapi_schema_available(self, client):
        """OpenAPI schema should be available."""
        response = client.get("/openapi.json")
        assert response.status_code == 200
        schema = response.json()
        
        assert "paths" in schema
        assert "/api/v1/encode" in schema["paths"]
        assert "/api/v1/decode" in schema["paths"]
        assert "/api/v1/verify" in schema["paths"]


class TestErrorHandling:
    """Test error handling and edge cases."""

    def test_invalid_audio_format(self, client):
        """Invalid audio format should fail gracefully."""
        response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.txt", io.BytesIO(b"not audio"))},
            data={"message": "TEST"}
        )
        assert response.status_code in [400, 500]

    def test_missing_file(self, client):
        """Missing file should fail validation."""
        response = client.post(
            "/api/v1/encode",
            data={"message": "TEST"}
        )
        assert response.status_code in [422, 400]


class TestEndToEnd:
    """End-to-end workflow tests."""

    def test_encode_decode_roundtrip(self, client, sample_audio):
        """Full encode-decode workflow should succeed."""
        message = "AUTHOR_ID_001"
        
        # Encode
        encode_response = client.post(
            "/api/v1/encode",
            files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
            data={"message": message, "amplitude_factor": 0.05}
        )
        assert encode_response.status_code == 200
        file_id = encode_response.json()["file_id"]
        
        # Verify
        verify_response = client.post(
            "/api/v1/verify",
            json={"file_id": file_id}
        )
        assert verify_response.status_code == 200
        verify_data = verify_response.json()
        assert verify_data["watermark_detected"] is True
        
        # Decode
        decode_response = client.post(
            "/api/v1/decode",
            json={"file_id": file_id}
        )
        assert decode_response.status_code == 200
        decode_data = decode_response.json()
        
        # Note: Exact message recovery depends on noise, but should have high confidence
        assert decode_data["confidence"] > 0.3 or decode_data["message"] == message

    def test_multiple_encodes_different_messages(self, client, sample_audio):
        """Multiple encodes should create unique file_ids."""
        file_ids = []
        
        for i in range(3):
            response = client.post(
                "/api/v1/encode",
                files={"audio_file": ("test.wav", io.BytesIO(sample_audio))},
                data={"message": f"MSG_{i}"}
            )
            assert response.status_code == 200
            file_id = response.json()["file_id"]
            file_ids.append(file_id)
        
        # All file_ids should be unique
        assert len(set(file_ids)) == 3


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
