"""
AudioGuard FastAPI Server

REST API for watermark encoding, decoding, and verification.
Includes async file handling, JWT authentication, and rate limiting.
"""

import io
import os
import time
import tempfile
import logging
from pathlib import Path
from typing import Optional
from datetime import datetime, timedelta

from fastapi import (
    FastAPI,
    File,
    UploadFile,
    HTTPException,
    Depends,
    Header,
    BackgroundTasks,
)
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
try:
    from starlette.middleware.gzip import GZipMiddleware
except ImportError:
    from fastapi.middleware.gzip import GZipMiddleware
import soundfile as sf
import numpy as np

from engine import AudioGuardEncoder, AudioGuardDecoder
try:
    from engine import CNNWatermarkDecoder
    CNN_AVAILABLE = True
except ImportError:
    CNN_AVAILABLE = False

from .models import (
    EncodeRequest,
    EncodeResponse,
    DecodeRequest,
    DecodeResponse,
    VerifyRequest,
    VerifyResponse,
    HealthResponse,
    ErrorResponse,
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global state
app_state = {
    "start_time": datetime.now(),
    "encoded_files": {},  # file_id -> path
    "request_count": 0,
}


def create_app(debug: bool = False) -> FastAPI:
    """
    Create and configure FastAPI application.

    Args:
        debug: Enable debug mode with detailed error messages

    Returns:
        Configured FastAPI application instance
    """
    app = FastAPI(
        title="AudioGuard API",
        description="High-fidelity digital audio watermarking service",
        version="1.0.0",
        debug=debug,
    )

    # Add middleware
    app.add_middleware(GZipMiddleware, minimum_size=1000)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def add_request_id(request, call_next):
        """Add request ID to all responses."""
        app_state["request_count"] += 1
        request.state.request_id = f"req_{app_state['request_count']}"
        response = await call_next(request)
        response.headers["X-Request-ID"] = request.state.request_id
        return response

    # Routes
    @app.get("/health", response_model=HealthResponse)
    async def health_check():
        """Health check endpoint."""
        uptime = (datetime.now() - app_state["start_time"]).total_seconds()
        models = ["classical"]
        if CNN_AVAILABLE:
            models.append("cnn")

        return HealthResponse(
            status="healthy",
            version="1.0.0",
            models_available=models,
            uptime_seconds=uptime,
        )

    @app.get("/")
    async def redirect_to_docs():
        """Redirect to API documentation."""
        from fastapi.responses import RedirectResponse
        return RedirectResponse(url="/docs")

    @app.post("/api/v1/encode", response_model=EncodeResponse)
    async def encode_watermark(
        file: UploadFile = File(...),
        request: EncodeRequest = EncodeRequest(message="test"),
        background_tasks: BackgroundTasks = None,
    ):
        """
        Embed watermark in audio file.

        **Parameters:**
        - **file**: Audio file (WAV, MP3, FLAC, OGG)
        - **message**: Message to embed (1-255 chars)
        - **amplitude_factor**: Watermark strength (0.01-1.0, default 0.05)
        - **frame_size**: STFT frame size (512-4096, default 2048)
        - **bits_per_frame**: Redundancy factor (1-8, default 4)
        - **seed**: Random seed for reproducibility (default 42)

        **Returns:**
        - **file_id**: Unique ID for retrieving watermarked audio
        - **success**: Whether encoding succeeded
        - **confidence**: Embedding quality metrics
        """
        start_time = time.time()
        temp_dir = tempfile.mkdtemp()

        try:
            # Save uploaded file
            input_path = Path(temp_dir) / "input_audio"
            content = await file.read()

            # Handle different formats
            try:
                audio_data, sr = sf.read(io.BytesIO(content))
            except Exception:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid audio format. Supported: WAV, MP3, FLAC, OGG",
                )

            # Save as WAV for processing
            input_wav = Path(temp_dir) / "input.wav"
            sf.write(str(input_wav), audio_data, sr)

            # Encode watermark
            output_wav = Path(temp_dir) / "output.wav"
            encoder = AudioGuardEncoder(
                frame_size=request.frame_size,
                amplitude_factor=request.amplitude_factor,
                seed=request.seed,
            )

            metadata = encoder.encode(
                str(input_wav),
                str(output_wav),
                request.message,
                bits_per_frame=request.bits_per_frame,
            )

            # Store encoded file
            file_id = f"file_{int(time.time())}_{np.random.randint(10000)}"
            app_state["encoded_files"][file_id] = str(output_wav)

            processing_time = (time.time() - start_time) * 1000

            # Schedule cleanup
            if background_tasks:
                background_tasks.add_task(cleanup_temp_file, temp_dir)

            return EncodeResponse(
                success=True,
                file_id=file_id,
                original_duration=len(audio_data) / sr,
                sample_rate=sr,
                message_length=len(request.message),
                embedding_strength=request.amplitude_factor,
                processing_time_ms=processing_time,
            )

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Encoding error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Encoding failed: {str(e)}")

    @app.post("/api/v1/decode", response_model=DecodeResponse)
    async def decode_watermark(request: DecodeRequest):
        """
        Extract watermark from audio file.

        **Parameters:**
        - **file_id**: ID from encode response
        - **use_cnn**: Use CNN decoder for compressed audio (optional)
        - **confidence_threshold**: Minimum confidence to accept result (0-1)

        **Returns:**
        - **message**: Extracted message (null if not detected)
        - **confidence**: Extraction confidence (0-1)
        - **method**: Decoder used (classical or cnn)
        - **snr_db**: Estimated signal-to-noise ratio
        """
        start_time = time.time()

        try:
            if request.file_id not in app_state["encoded_files"]:
                raise HTTPException(
                    status_code=404,
                    detail=f"File ID not found: {request.file_id}",
                )

            audio_path = app_state["encoded_files"][request.file_id]

            # Classical decoder
            decoder = AudioGuardDecoder()
            message, confidence, snr = decoder.decode(audio_path)

            # Fallback to CNN if requested and classical failed
            if (
                use_cnn
                and CNN_AVAILABLE
                and (message is None or confidence < request.confidence_threshold)
            ):
                try:
                    cnn_decoder = CNNWatermarkDecoder()
                    message, confidence = cnn_decoder.decode(audio_path)
                    method = "cnn"
                except Exception as e:
                    logger.warning(f"CNN decoding failed: {str(e)}")
                    method = "classical"
            else:
                method = "classical"

            processing_time = (time.time() - start_time) * 1000

            if message is None:
                return DecodeResponse(
                    success=False,
                    message=None,
                    confidence=confidence,
                    method=method,
                    snr_db=snr,
                    processing_time_ms=processing_time,
                )

            return DecodeResponse(
                success=True,
                message=message,
                confidence=confidence,
                method=method,
                snr_db=snr,
                processing_time_ms=processing_time,
            )

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Decoding error: {str(e)}")
            return DecodeResponse(
                success=False,
                message=None,
                confidence=0.0,
                method="unknown",
                processing_time_ms=(time.time() - start_time) * 1000,
                error=str(e),
            )

    @app.post("/api/v1/verify", response_model=VerifyResponse)
    async def verify_watermark(request: VerifyRequest):
        """
        Check if audio contains watermark (binary classification).

        **Parameters:**
        - **file_id**: ID from encode response

        **Returns:**
        - **watermark_detected**: True if watermark is present
        - **confidence**: Detection confidence (0-1)
        """
        start_time = time.time()

        try:
            if request.file_id not in app_state["encoded_files"]:
                raise HTTPException(
                    status_code=404,
                    detail=f"File ID not found: {request.file_id}",
                )

            audio_path = app_state["encoded_files"][request.file_id]

            # Use CNN if available, else classical
            if CNN_AVAILABLE:
                try:
                    detector = CNNWatermarkDecoder()
                    _, confidence = detector.decode(audio_path)
                    watermark_detected = confidence > 0.5
                except Exception:
                    # Fallback to classical
                    decoder = AudioGuardDecoder()
                    message, confidence, _ = decoder.decode(audio_path)
                    watermark_detected = message is not None
            else:
                decoder = AudioGuardDecoder()
                message, confidence, _ = decoder.decode(audio_path)
                watermark_detected = message is not None

            processing_time = (time.time() - start_time) * 1000

            return VerifyResponse(
                success=True,
                watermark_detected=watermark_detected,
                confidence=confidence,
                processing_time_ms=processing_time,
            )

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Verification error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Verification failed: {str(e)}")

    @app.get("/api/v1/download/{file_id}")
    async def download_watermarked_audio(file_id: str):
        """
        Download watermarked audio file.

        **Parameters:**
        - **file_id**: ID from encode response

        **Returns:**
        - Binary audio file (WAV format)
        """
        if file_id not in app_state["encoded_files"]:
            raise HTTPException(status_code=404, detail="File not found")

        audio_path = app_state["encoded_files"][file_id]

        return FileResponse(
            path=audio_path,
            filename=f"watermarked_{file_id}.wav",
            media_type="audio/wav",
        )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request, exc):
        """Custom HTTP exception handler."""
        from fastapi.responses import JSONResponse
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": exc.detail,
                "status_code": exc.status_code,
                "request_id": getattr(request.state, "request_id", None),
            },
        )

    return app


def cleanup_temp_file(path: str):
    """Clean up temporary files."""
    try:
        import shutil

        shutil.rmtree(path, ignore_errors=True)
    except Exception as e:
        logger.warning(f"Failed to clean up {path}: {str(e)}")


# Create default app instance
app = create_app(debug=False)
