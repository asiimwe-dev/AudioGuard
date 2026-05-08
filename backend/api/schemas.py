"""
AudioGuard API Schemas (Pydantic v2)

All request / response models live here.  Using v2 field_validator
instead of v1 @validator for forward compatibility.
"""

from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Shared
# ---------------------------------------------------------------------------

class BaseResponse(BaseModel):
    success: bool
    processing_time_ms: float = Field(..., ge=0)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

class HealthResponse(BaseModel):
    status: str = "healthy"
    version: str
    uptime_seconds: float


# ---------------------------------------------------------------------------
# Encode
# ---------------------------------------------------------------------------

class EncodeResponse(BaseResponse):
    file_id: str
    message: str
    duration_s: float
    sample_rate: int
    bits_embedded: int
    snr_db: float = Field(..., description="Signal-to-noise ratio of watermark embedding")
    error: Optional[str] = None


# ---------------------------------------------------------------------------
# Decode
# ---------------------------------------------------------------------------

class DecodeResponse(BaseResponse):
    message: Optional[str] = None
    confidence: float = Field(..., ge=0.0, le=1.0)
    snr_db: float
    ber_estimate: float = Field(..., ge=0.0, le=1.0)
    sync_found: bool
    ecc_errors: int = Field(..., ge=0)
    method: str
    error: Optional[str] = None


# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

class VerifyResponse(BaseResponse):
    watermark_detected: bool
    verdict: str = Field(
        ...,
        description="One of: watermarked | not_watermarked | possibly_tampered",
    )
    confidence: float = Field(..., ge=0.0, le=1.0)


# ---------------------------------------------------------------------------
# Analyse
# ---------------------------------------------------------------------------

class AnalyseResponse(BaseResponse):
    duration_s: float
    sample_rate: int
    rms: float
    peak: float
    dynamic_range_db: float
    watermark_detected: bool
    watermark_message: Optional[str] = None
    watermark_confidence: float = Field(..., ge=0.0, le=1.0)
    snr_db: float


# ---------------------------------------------------------------------------
# Jobs
# ---------------------------------------------------------------------------

class JobStatusResponse(BaseModel):
    job_id: str
    operation: str
    status: str = Field(..., description="queued | running | done | failed")
    created_at: float
    result: Optional[dict] = None
    error: Optional[str] = None


# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

class ErrorResponse(BaseModel):
    error: str
    details: Optional[str] = None
