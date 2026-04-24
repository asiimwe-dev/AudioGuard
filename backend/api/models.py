"""
Pydantic data models for AudioGuard REST API.

Defines request/response schemas for all endpoints with validation.
"""

from typing import Optional
from pydantic import BaseModel, Field


class EncodeRequest(BaseModel):
    """Request body for watermark encoding endpoint."""

    message: str = Field(
        ..., min_length=1, max_length=255, description="Message to embed in audio"
    )
    amplitude_factor: float = Field(
        default=0.05, ge=0.01, le=1.0, description="Watermark strength (0.01-1.0)"
    )
    frame_size: int = Field(default=2048, ge=512, le=4096, description="STFT frame size")
    bits_per_frame: int = Field(
        default=4, ge=1, le=8, description="Bits per frame for redundancy"
    )
    seed: int = Field(default=42, description="Random seed for reproducibility")


class EncodeResponse(BaseModel):
    """Response body for encoding endpoint."""

    success: bool
    message: str = "Watermark embedded successfully"
    file_id: str = Field(..., description="Unique ID for watermarked file")
    original_duration: float = Field(..., description="Duration in seconds")
    sample_rate: int = Field(..., description="Sample rate in Hz")
    message_length: int = Field(..., description="Length of embedded message")
    embedding_strength: float = Field(
        ..., description="Actual amplitude factor used"
    )
    processing_time_ms: float = Field(
        ..., description="Time taken to encode in milliseconds"
    )


class DecodeRequest(BaseModel):
    """Request body for watermark decoding endpoint."""

    file_id: str = Field(..., description="File ID from encoding response")
    use_cnn: bool = Field(
        default=False, description="Use CNN decoder for degraded audio"
    )
    confidence_threshold: float = Field(
        default=0.5, ge=0.0, le=1.0, description="Confidence threshold for acceptance"
    )


class DecodeResponse(BaseModel):
    """Response body for decoding endpoint."""

    success: bool
    message: Optional[str] = Field(
        None, description="Extracted message (null if not detected)"
    )
    confidence: float = Field(
        ..., ge=0.0, le=1.0, description="Confidence in extraction (0-1)"
    )
    method: str = Field(
        ..., description="Decoder method used: 'classical' or 'cnn'"
    )
    snr_db: Optional[float] = Field(
        None, description="Signal-to-noise ratio estimate"
    )
    processing_time_ms: float = Field(
        ..., description="Time taken to decode in milliseconds"
    )
    error: Optional[str] = Field(None, description="Error message if failed")


class VerifyRequest(BaseModel):
    """Request body for watermark verification endpoint."""

    file_id: str = Field(..., description="File ID from encoding response")


class VerifyResponse(BaseModel):
    """Response body for verification endpoint."""

    success: bool
    watermark_detected: bool = Field(..., description="Whether watermark is present")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Detection confidence")
    processing_time_ms: float = Field(
        ..., description="Time taken to verify in milliseconds"
    )


class AnalyzeRequest(BaseModel):
    """Request body for audio analysis endpoint."""

    file_id: Optional[str] = Field(None, description="File ID from encoding response")


class AnalyzeResponse(BaseModel):
    """Response body for analysis endpoint."""

    success: bool
    watermark_present: bool = Field(..., description="Whether watermark is detected")
    signal_strength: float = Field(..., ge=0.0, le=1.0, description="Watermark signal strength")
    spectral_info: dict = Field(
        default_factory=dict, description="Spectral analysis information"
    )
    processing_time_ms: float = Field(
        ..., description="Time taken to analyze in milliseconds"
    )


class HealthResponse(BaseModel):
    """Response body for health check endpoint."""

    status: str = Field(default="healthy", description="Service status")
    version: str = Field(..., description="API version")
    models_available: list = Field(..., description="Available models (classical, cnn)")
    uptime_seconds: float = Field(..., description="Service uptime in seconds")


class ErrorResponse(BaseModel):
    """Standard error response."""

    error: str = Field(..., description="Error message")
    status_code: int = Field(..., description="HTTP status code")
    details: Optional[str] = Field(None, description="Additional error details")
