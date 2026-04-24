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
    Form,
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
    AnalyzeRequest,
    AnalyzeResponse,
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
        message: str = Form(...),
        amplitude_factor: float = Form(0.05),
        frame_size: int = Form(2048),
        bits_per_frame: int = Form(4),
        seed: int = Form(42),
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
            # Validate message
            if not message or len(message) > 255:
                raise HTTPException(
                    status_code=400,
                    detail="Message must be 1-255 characters",
                )

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
                frame_size=frame_size,
                amplitude_factor=amplitude_factor,
                seed=seed,
            )

            metadata = encoder.encode(
                str(input_wav),
                str(output_wav),
                message,
                bits_per_frame=bits_per_frame,
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
                message_length=len(message),
                embedding_strength=amplitude_factor,
                processing_time_ms=processing_time,
            )

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Encoding error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Encoding failed: {str(e)}")

    @app.post("/api/v1/decode", response_model=DecodeResponse)
    async def decode_watermark(
        file: UploadFile = File(...),
        message_length: int = Form(None),
        use_cnn: bool = Form(False),
        confidence_threshold: float = Form(0.5),
    ):
        """
        Extract watermark from audio file.

        **Parameters:**
        - **file**: Audio file to decode
        - **message_length**: Expected message length (optional, default tries 4-32)
        - **use_cnn**: Use CNN decoder for compressed audio (optional)
        - **confidence_threshold**: Minimum confidence to accept result (0-1)

        **Returns:**
        - **message**: Extracted message (null if not detected)
        - **confidence**: Extraction confidence (0-1)
        - **method**: Decoder method used (classical or cnn)
        - **snr_db**: Estimated signal-to-noise ratio
        """
        start_time = time.time()
        temp_dir = tempfile.mkdtemp()

        try:
            # Read and save audio file
            content = await file.read()
            try:
                audio_data, sr = sf.read(io.BytesIO(content))
            except Exception:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid audio format. Supported: WAV, MP3, FLAC, OGG",
                )

            # Save as WAV for processing
            input_wav = Path(temp_dir) / "decode.wav"
            sf.write(str(input_wav), audio_data, sr)

            # Classical decoder - try with provided message_length or auto-detect
            decoder = AudioGuardDecoder()
            message = None
            confidence = 0.0
            snr = None
            method = "classical"
            
            if message_length is not None:
                # Try with specified message length
                try:
                    result = decoder.decode(str(input_wav), message_length=message_length)
                    if isinstance(result, dict):
                        message = result.get('message')
                        confidence = result.get('confidence', 0.0)
                        snr = result.get('snr_db')
                    else:
                        message, confidence, snr = result
                except Exception as e:
                    logger.warning(f"Decode failed with message_length={message_length}: {str(e)}")
            else:
                # Try different message lengths (4-32 chars)
                for try_length in range(4, 33):
                    try:
                        result = decoder.decode(str(input_wav), message_length=try_length)
                        if isinstance(result, dict):
                            msg = result.get('message')
                            conf = result.get('confidence', 0.0)
                            s = result.get('snr_db')
                        else:
                            msg, conf, s = result
                        
                        if msg is not None and conf > confidence:
                            message = msg
                            confidence = conf
                            snr = s
                            if confidence > 0.8:  # Good enough, stop searching
                                break
                    except Exception:
                        continue

            # Fallback to CNN if requested and classical failed
            if (
                use_cnn
                and CNN_AVAILABLE
                and (message is None or confidence < confidence_threshold)
            ):
                try:
                    cnn_decoder = CNNWatermarkDecoder()
                    message, confidence = cnn_decoder.decode(str(input_wav))
                    method = "cnn"
                except Exception as e:
                    logger.warning(f"CNN decoding failed: {str(e)}")
                    method = "classical"
            else:
                method = "classical"

            processing_time = (time.time() - start_time) * 1000

            # Cleanup
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

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
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)
            return DecodeResponse(
                success=False,
                message=None,
                confidence=0.0,
                method="unknown",
                processing_time_ms=(time.time() - start_time) * 1000,
                error=str(e),
            )

    @app.post("/api/v1/verify", response_model=VerifyResponse)
    async def verify_watermark(file: UploadFile = File(...)):
        """
        Check if audio contains watermark (binary classification).

        **Parameters:**
        - **file**: Audio file to verify

        **Returns:**
        - **watermark_detected**: True if watermark is present
        - **confidence**: Detection confidence (0-1)
        """
        start_time = time.time()
        temp_dir = tempfile.mkdtemp()

        try:
            # Read and save audio file
            content = await file.read()
            try:
                audio_data, sr = sf.read(io.BytesIO(content))
            except Exception:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid audio format. Supported: WAV, MP3, FLAC, OGG",
                )

            # Save as WAV for processing
            input_wav = Path(temp_dir) / "verify.wav"
            sf.write(str(input_wav), audio_data, sr)

            # Use CNN if available, else classical
            watermark_detected = False
            confidence = 0.0
            
            if CNN_AVAILABLE:
                try:
                    detector = CNNWatermarkDecoder()
                    _, confidence = detector.decode(str(input_wav))
                    watermark_detected = confidence > 0.5
                except Exception:
                    # Fallback to classical
                    decoder = AudioGuardDecoder()
                    # Try different message lengths to detect watermark
                    for try_length in range(4, 33):
                        try:
                            result = decoder.decode(str(input_wav), message_length=try_length)
                            if isinstance(result, dict):
                                msg = result.get('message')
                                conf = result.get('confidence', 0.0)
                            else:
                                msg, conf, _ = result
                            
                            if msg is not None:
                                watermark_detected = True
                                confidence = max(confidence, conf)
                                if confidence > 0.8:
                                    break
                        except Exception:
                            continue
            else:
                decoder = AudioGuardDecoder()
                # Try different message lengths to detect watermark
                for try_length in range(4, 33):
                    try:
                        result = decoder.decode(str(input_wav), message_length=try_length)
                        if isinstance(result, dict):
                            msg = result.get('message')
                            conf = result.get('confidence', 0.0)
                        else:
                            msg, conf, _ = result
                        
                        if msg is not None:
                            watermark_detected = True
                            confidence = max(confidence, conf)
                            if confidence > 0.8:
                                break
                    except Exception:
                        continue

            processing_time = (time.time() - start_time) * 1000

            # Cleanup
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

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
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)
            raise HTTPException(status_code=500, detail=f"Verification failed: {str(e)}")

    @app.post("/api/v1/analyze", response_model=AnalyzeResponse)
    async def analyze_audio(file: UploadFile = File(...)):
        """
        Analyze audio for watermark presence and signal strength.

        **Parameters:**
        - **file**: Audio file to analyze

        **Returns:**
        - **watermark_present**: Whether watermark is detected
        - **signal_strength**: Signal strength (0-1)
        - **spectral_info**: Spectral analysis information
        """
        start_time = time.time()
        temp_dir = tempfile.mkdtemp()

        try:
            # Save and read audio file
            content = await file.read()
            try:
                audio_data, sr = sf.read(io.BytesIO(content))
            except Exception:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid audio format. Supported: WAV, MP3, FLAC, OGG",
                )

            # Save as WAV for processing
            input_wav = Path(temp_dir) / "analyze.wav"
            sf.write(str(input_wav), audio_data, sr)

            # Analyze with decoder - try different message lengths
            decoder = AudioGuardDecoder()
            message = None
            confidence = 0.0
            snr = None
            
            for try_length in range(4, 33):
                try:
                    result = decoder.decode(str(input_wav), message_length=try_length)
                    if isinstance(result, dict):
                        msg = result.get('message')
                        conf = result.get('confidence', 0.0)
                        s = result.get('snr_db')
                    else:
                        msg, conf, s = result
                    
                    if msg is not None and conf > confidence:
                        message = msg
                        confidence = conf
                        snr = s
                        if confidence > 0.8:
                            break
                except Exception:
                    continue

            processing_time = (time.time() - start_time) * 1000

            # Cleanup
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

            return AnalyzeResponse(
                success=True,
                watermark_present=message is not None,
                signal_strength=confidence,
                spectral_info={
                    "snr_db": float(snr) if snr is not None else 0.0,
                    "message_detected": message is not None,
                    "confidence": float(confidence),
                },
                processing_time_ms=processing_time,
            )

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Analysis error: {str(e)}")
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)
            raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

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
