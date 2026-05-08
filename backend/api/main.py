"""
AudioGuard REST API

Endpoints:
  POST /api/v1/encode          - Embed watermark
  POST /api/v1/decode          - Extract watermark
  POST /api/v1/verify          - Binary watermark detection
  POST /api/v1/analyse         - Full spectral + authenticity analysis
  GET  /api/v1/jobs/{job_id}   - Poll async job status
  GET  /health                 - Health check

Design:
  - Small files (<10 MB) → synchronous response
  - Large files → background task + job polling
  - SlowAPI rate limiting (100 req/min per IP)
  - Strict file size and duration caps
  - UploadFile streaming → tempfile; never hold in memory
  - Structured logging (JSON) for production observability
"""

from __future__ import annotations

import asyncio
import logging
import os
import time
import tempfile
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

import soundfile as sf
from fastapi import (
    BackgroundTasks,
    Depends,
    FastAPI,
    File,
    Form,
    HTTPException,
    Request,
    UploadFile,
    status,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

from .schemas import (
    AnalyseResponse,
    DecodeResponse,
    EncodeResponse,
    ErrorResponse,
    HealthResponse,
    JobStatusResponse,
    VerifyResponse,
)
from .dependencies import (
    get_storage,
    get_watermarker,
    RateLimiter,
    validate_audio_file,
)

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# In-process job store (replace with Redis for multi-worker deployments)
# ---------------------------------------------------------------------------
_JOBS: dict[str, dict] = {}

MAX_FILE_SIZE_BYTES = 100 * 1024 * 1024   # 100 MB
MAX_DURATION_SECONDS = 3600               # 60 min
SYNC_SIZE_THRESHOLD = 10 * 1024 * 1024   # 10 MB → async above this


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown hooks."""
    logger.info("AudioGuard API starting up")
    yield
    logger.info("AudioGuard API shutting down")


def create_app(debug: bool = False) -> FastAPI:
    app = FastAPI(
        title="AudioGuard API",
        description="Professional audio watermarking — embed, extract, verify, analyse",
        version="2.0.0",
        debug=debug,
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
        allow_methods=["*"],
        allow_headers=["*"],
    )

    _register_routes(app)
    _register_exception_handlers(app)
    return app


# ---------------------------------------------------------------------------
# Route registration
# ---------------------------------------------------------------------------

def _register_routes(app: FastAPI) -> None:
    rate_limit = RateLimiter(requests=100, window_seconds=60)

    # ------------------------------------------------------------------
    @app.get("/health", response_model=HealthResponse, tags=["meta"])
    async def health():
        return HealthResponse(
            status="healthy",
            version="2.0.0",
            uptime_seconds=time.time() - _START_TIME,
        )

    # ------------------------------------------------------------------
    @app.post(
        "/api/v1/encode",
        response_model=EncodeResponse,
        status_code=status.HTTP_200_OK,
        tags=["watermark"],
        summary="Embed a watermark message into an audio file",
    )
    async def encode(
        request: Request,
        background_tasks: BackgroundTasks,
        file: UploadFile = File(..., description="Audio file (wav/mp3/flac/ogg/m4a)"),
        message: str = Form(..., min_length=1, max_length=255),
        amplitude_factor: float = Form(default=0.08, ge=0.01, le=1.0),
        seed: int = Form(default=42),
        _rl: None = Depends(rate_limit),
        watermarker=Depends(get_watermarker),
        storage=Depends(get_storage),
    ):
        file_size = await _check_file_size(file)
        tmp_in, tmp_out = await _save_upload(file)

        try:
            await validate_audio_file(tmp_in, MAX_DURATION_SECONDS)

            if file_size > SYNC_SIZE_THRESHOLD:
                job_id = _create_job("encode")
                background_tasks.add_task(
                    _bg_encode, job_id, tmp_in, tmp_out, message,
                    amplitude_factor, seed, watermarker, storage,
                )
                return JSONResponse(
                    status_code=status.HTTP_202_ACCEPTED,
                    content={"job_id": job_id, "status": "queued"},
                )

            # Synchronous path
            from core.watermarker import WatermarkConfig
            wm = watermarker(WatermarkConfig(amplitude_factor=amplitude_factor, seed=seed))
            result = wm.encode(tmp_in, tmp_out, message)

            if not result.success:
                raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, result.error)

            file_id = storage.save_file(tmp_out, {"message": message, "amplitude_factor": amplitude_factor})

            return EncodeResponse(
                success=True,
                file_id=file_id,
                message=message,
                duration_s=result.duration_s,
                sample_rate=result.sample_rate,
                bits_embedded=result.bits_embedded,
                snr_db=result.snr_db,
                processing_time_ms=result.processing_time_ms,
            )
        finally:
            _cleanup(tmp_in)

    # ------------------------------------------------------------------
    @app.post(
        "/api/v1/decode",
        response_model=DecodeResponse,
        tags=["watermark"],
        summary="Extract the watermark message from an audio file",
    )
    async def decode(
        request: Request,
        file: UploadFile = File(...),
        seed: int = Form(default=42),
        _rl: None = Depends(rate_limit),
        watermarker=Depends(get_watermarker),
    ):
        tmp_in, _ = await _save_upload(file)
        try:
            await validate_audio_file(tmp_in, MAX_DURATION_SECONDS)

            from core.watermarker import WatermarkConfig
            wm = watermarker(WatermarkConfig(seed=seed))
            result = wm.decode(tmp_in)

            return DecodeResponse(
                success=result.success,
                message=result.message if result.success else None,
                confidence=result.confidence,
                snr_db=result.snr_db,
                ber_estimate=result.ber_estimate,
                sync_found=result.sync_found,
                ecc_errors=result.ecc_errors,
                method=result.method,
                processing_time_ms=result.processing_time_ms,
                error=result.error,
            )
        finally:
            _cleanup(tmp_in)

    # ------------------------------------------------------------------
    @app.post(
        "/api/v1/verify",
        response_model=VerifyResponse,
        tags=["watermark"],
        summary="Quick binary watermark detection",
    )
    async def verify(
        request: Request,
        file: UploadFile = File(...),
        confidence_threshold: float = Form(default=0.60, ge=0.0, le=1.0),
        _rl: None = Depends(rate_limit),
        watermarker=Depends(get_watermarker),
    ):
        tmp_in, _ = await _save_upload(file)
        try:
            from core.watermarker import WatermarkConfig
            wm = watermarker(WatermarkConfig())
            result = wm.decode(tmp_in)

            detected = result.sync_found and result.confidence >= confidence_threshold
            verdict = "watermarked" if detected else (
                "possibly_tampered" if result.sync_found else "not_watermarked"
            )

            return VerifyResponse(
                success=True,
                watermark_detected=detected,
                verdict=verdict,
                confidence=result.confidence,
                processing_time_ms=result.processing_time_ms,
            )
        finally:
            _cleanup(tmp_in)

    # ------------------------------------------------------------------
    @app.post(
        "/api/v1/analyse",
        response_model=AnalyseResponse,
        tags=["watermark"],
        summary="Full spectral analysis with watermark status",
    )
    async def analyse(
        request: Request,
        file: UploadFile = File(...),
        _rl: None = Depends(rate_limit),
        watermarker=Depends(get_watermarker),
    ):
        tmp_in, _ = await _save_upload(file)
        try:
            import numpy as np
            audio, sr = sf.read(tmp_in, dtype="float32")
            if audio.ndim > 1:
                audio = audio.mean(axis=1)

            duration = len(audio) / sr
            rms = float(np.sqrt(np.mean(audio ** 2)))
            peak = float(np.max(np.abs(audio)))
            snr_proxy = float(20 * np.log10(peak / (rms + 1e-10)))

            from core.watermarker import WatermarkConfig
            wm = watermarker(WatermarkConfig())
            decode_result = wm.decode(tmp_in)

            return AnalyseResponse(
                success=True,
                duration_s=duration,
                sample_rate=sr,
                rms=rms,
                peak=peak,
                dynamic_range_db=snr_proxy,
                watermark_detected=decode_result.sync_found,
                watermark_message=decode_result.message if decode_result.success else None,
                watermark_confidence=decode_result.confidence,
                snr_db=decode_result.snr_db,
                processing_time_ms=decode_result.processing_time_ms,
            )
        finally:
            _cleanup(tmp_in)

    # ------------------------------------------------------------------
    @app.get(
        "/api/v1/jobs/{job_id}",
        response_model=JobStatusResponse,
        tags=["jobs"],
        summary="Poll async job status",
    )
    async def job_status(job_id: str):
        job = _JOBS.get(job_id)
        if not job:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Job not found")
        return JobStatusResponse(**job)

    # ------------------------------------------------------------------
    @app.get(
        "/api/v1/files/{file_id}",
        tags=["files"],
        summary="Download a watermarked file",
    )
    async def download_file(file_id: str, storage=Depends(get_storage)):
        path = storage.get_file(file_id)
        if not path:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "File not found or expired")
        return FileResponse(
            path=path,
            media_type="audio/wav",
            filename=f"watermarked_{file_id[:8]}.wav",
        )


# ---------------------------------------------------------------------------
# Exception handlers
# ---------------------------------------------------------------------------

def _register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(Exception)
    async def generic_handler(request: Request, exc: Exception):
        logger.exception("Unhandled exception: %s", exc)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": "Internal server error", "details": str(exc)},
        )

    @app.exception_handler(HTTPException)
    async def http_handler(request: Request, exc: HTTPException):
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": exc.detail},
        )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_START_TIME = time.time()


async def _check_file_size(file: UploadFile) -> int:
    content = await file.read()
    if len(content) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            f"File too large (max {MAX_FILE_SIZE_BYTES // 1024 // 1024} MB)",
        )
    await file.seek(0)
    return len(content)


async def _save_upload(file: UploadFile) -> tuple[str, str]:
    suffix = Path(file.filename or "audio.wav").suffix or ".wav"
    tmp_in = tempfile.mktemp(suffix=suffix)
    tmp_out = tempfile.mktemp(suffix=".wav")
    content = await file.read()
    Path(tmp_in).write_bytes(content)
    return tmp_in, tmp_out


def _cleanup(*paths: str) -> None:
    for p in paths:
        try:
            Path(p).unlink(missing_ok=True)
        except Exception:
            pass


def _create_job(operation: str) -> str:
    job_id = str(uuid.uuid4())
    _JOBS[job_id] = {
        "job_id": job_id,
        "operation": operation,
        "status": "queued",
        "created_at": time.time(),
        "result": None,
        "error": None,
    }
    return job_id


async def _bg_encode(
    job_id: str,
    tmp_in: str,
    tmp_out: str,
    message: str,
    amplitude_factor: float,
    seed: int,
    watermarker_factory,
    storage,
) -> None:
    try:
        _JOBS[job_id]["status"] = "running"
        from core.watermarker import WatermarkConfig
        wm = watermarker_factory(WatermarkConfig(amplitude_factor=amplitude_factor, seed=seed))
        result = wm.encode(tmp_in, tmp_out, message)

        if result.success:
            file_id = storage.save_file(tmp_out, {"message": message})
            _JOBS[job_id]["status"] = "done"
            _JOBS[job_id]["result"] = {"file_id": file_id, "snr_db": result.snr_db}
        else:
            _JOBS[job_id]["status"] = "failed"
            _JOBS[job_id]["error"] = result.error
    except Exception as exc:
        _JOBS[job_id]["status"] = "failed"
        _JOBS[job_id]["error"] = str(exc)
        logger.exception("Background encode failed: %s", exc)
    finally:
        _cleanup(tmp_in, tmp_out)
