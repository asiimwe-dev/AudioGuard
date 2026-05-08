"""
AudioGuard API Dependencies

FastAPI Depends() factories for:
  - Rate limiting (sliding window, per-IP)
  - Watermarker factory (singleton config, per-request instance)
  - Storage backend (singleton)
  - Audio file validation
"""

from __future__ import annotations

import asyncio
import logging
import time
from collections import defaultdict, deque
from functools import lru_cache
from pathlib import Path
from typing import Optional

import soundfile as sf
from fastapi import HTTPException, Request, status

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Rate limiter
# ---------------------------------------------------------------------------

class RateLimiter:
    """Sliding-window rate limiter keyed by client IP."""

    def __init__(self, requests: int = 100, window_seconds: int = 60):
        self._limit = requests
        self._window = window_seconds
        self._buckets: dict[str, deque] = defaultdict(deque)
        self._lock = asyncio.Lock()

    async def __call__(self, request: Request) -> None:
        client_ip = request.client.host if request.client else "unknown"
        now = time.monotonic()
        window_start = now - self._window

        async with self._lock:
            bucket = self._buckets[client_ip]
            # Remove expired timestamps
            while bucket and bucket[0] < window_start:
                bucket.popleft()
            if len(bucket) >= self._limit:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Rate limit exceeded: max {self._limit} requests per {self._window}s",
                )
            bucket.append(now)


# ---------------------------------------------------------------------------
# Watermarker factory
# ---------------------------------------------------------------------------

def get_watermarker():
    """
    Returns a callable that accepts a WatermarkConfig and returns a Watermarker.
    Allows per-request config (amplitude, seed) while sharing heavy state.
    """
    def factory(config=None):
        from core.watermarker import Watermarker, WatermarkConfig
        return Watermarker(config or WatermarkConfig())
    return factory


# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

@lru_cache(maxsize=1)
def _build_storage():
    import os
    from utils.storage import LocalFileStorage
    base_dir = os.getenv("AUDIOGUARD_STORAGE_DIR", "/tmp/audioguard_storage")
    return LocalFileStorage(base_dir)


def get_storage():
    return _build_storage()


# ---------------------------------------------------------------------------
# File validation
# ---------------------------------------------------------------------------

async def validate_audio_file(path: str, max_duration_s: float = 3600) -> None:
    """
    Validate that the uploaded file is a readable audio file within duration caps.
    Runs in a thread pool to avoid blocking the event loop.
    """
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _sync_validate, path, max_duration_s)


def _sync_validate(path: str, max_duration_s: float) -> None:
    try:
        info = sf.info(path)
    except Exception as exc:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            f"Cannot read audio file: {exc}",
        )

    duration = info.frames / info.samplerate
    if duration > max_duration_s:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            f"Audio duration {duration:.0f}s exceeds maximum {max_duration_s:.0f}s",
        )
    if duration < 0.5:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Audio file too short (minimum 0.5 seconds)",
        )
