"""
AudioGuard REST API Module

Provides FastAPI-based REST endpoints for watermarking and verification.
"""

from .server import app, create_app
from .models import EncodeRequest, DecodeRequest, VerifyRequest, EncodeResponse, DecodeResponse

__all__ = [
    "app",
    "create_app",
    "EncodeRequest",
    "DecodeRequest",
    "VerifyRequest",
    "EncodeResponse",
    "DecodeResponse",
]
