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
import gc
from contextlib import asynccontextmanager
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
from scipy import signal

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

# Create persistent storage for encoded files
# Use /tmp for Render Free Tier (read-only /app), fallback to configured path if available
_storage_path = os.environ.get("AUDIOGUARD_STORAGE", "/tmp/audioguard_storage")
STORAGE_DIR = Path(_storage_path)
try:
    STORAGE_DIR.mkdir(parents=True, exist_ok=True)
except (PermissionError, OSError):
    # If primary path fails, use /tmp as fallback
    STORAGE_DIR = Path("/tmp/audioguard_storage")
    STORAGE_DIR.mkdir(parents=True, exist_ok=True)


def create_app(debug: bool = False) -> FastAPI:
    """
    Create and configure FastAPI application.

    Args:
        debug: Enable debug mode with detailed error messages

    Returns:
        Configured FastAPI application instance
    """
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        """
        Lifespan context manager for startup and shutdown events.
        Replaces deprecated @app.on_event() decorators.
        """
        # Startup
        logger.info("AudioGuard API starting up...")
        cleanup_resources()
        yield
        # Shutdown
        logger.info("AudioGuard API shutting down...")
        cleanup_resources()

    app = FastAPI(
        title="AudioGuard API",
        description="High-fidelity digital audio watermarking service",
        version="1.0.0",
        debug=debug,
        lifespan=lifespan,
    )

    # Add middleware
    app.add_middleware(GZipMiddleware, minimum_size=1000)
    # Configure CORS based on environment
    # For production with mobile clients, allow all origins to support cross-domain requests
    allowed_origins = os.getenv("ALLOWED_ORIGINS", "*").split(",")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Content-Type", "Authorization"],
    )

    @app.middleware("http")
    async def add_request_id(request, call_next):
        """Add request ID to all responses and manage resources."""
        app_state["request_count"] += 1
        request.state.request_id = f"req_{app_state['request_count']}"
        try:
            response = await call_next(request)
            response.headers["X-Request-ID"] = request.state.request_id
            return response
        finally:
            # Periodic cleanup every 50 requests
            if app_state["request_count"] % 50 == 0:
                gc.collect()

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
        audio_file: UploadFile = File(...),
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
        persistent_path = None

        try:
            # Validate message
            if not message or len(message) > 255:
                raise HTTPException(
                    status_code=400,
                    detail="Message must be 1-255 characters",
                )

            # Validate parameters
            if not (0.01 <= amplitude_factor <= 1.0):
                raise HTTPException(
                    status_code=400,
                    detail="amplitude_factor must be between 0.01 and 1.0",
                )
            if not (512 <= frame_size <= 4096):
                raise HTTPException(
                    status_code=400,
                    detail="frame_size must be between 512 and 4096",
                )
            if not (1 <= bits_per_frame <= 8):
                raise HTTPException(
                    status_code=400,
                    detail="bits_per_frame must be between 1 and 8",
                )

            # Read file into memory (only once)
            content = await audio_file.read()
            file_size_mb = len(content) / (1024 * 1024)
            
            # Limit file size to prevent OOM (max 50MB)
            if file_size_mb > 50:
                raise HTTPException(
                    status_code=400,
                    detail=f"Audio file too large ({file_size_mb:.1f}MB). Maximum: 50MB",
                )
            
            # Check if MP3 and limit further for Render tier (MP3 decompression is memory-intensive)
            file_name = getattr(audio_file, 'filename', '').lower()
            if file_name.endswith('.mp3') and file_size_mb > 10:
                raise HTTPException(
                    status_code=400,
                    detail=f"MP3 files limited to 10MB on this tier ({file_size_mb:.1f}MB provided). Please use WAV format for larger files.",
                )

            # Handle different formats with explicit error handling
            try:
                audio_data, sr = sf.read(io.BytesIO(content))
            except Exception as e:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid audio format. Supported: WAV, MP3, FLAC, OGG. Error: {str(e)[:100]}",
                )

            # Clean up input content from memory immediately
            del content
            gc.collect()  # Force GC after large file load
            
            # Downsample to 22.05 kHz if needed (reduce memory usage)
            # Use scipy.signal.resample which is more memory-efficient than librosa
            if sr > 22050:
                try:
                    # Use scipy resample directly (no librosa overhead)
                    num_samples = int(len(audio_data) * 22050 / sr)
                    audio_data = signal.resample(audio_data, num_samples)
                    sr = 22050
                except Exception as e:
                    logger.warning(f"Resample failed: {e}, continuing with original sample rate")
                    # Continue with original sample rate if resample fails
                    pass

            # Save as WAV for processing
            input_wav = Path(temp_dir) / "input.wav"
            sf.write(str(input_wav), audio_data, sr)
            
            # Calculate original duration before clearing audio from memory
            original_duration = len(audio_data) / sr

            # Clear audio from memory after saving
            del audio_data

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

            # Store encoded file in persistent location
            file_id = f"file_{int(time.time())}_{np.random.randint(10000)}"
            persistent_path = STORAGE_DIR / f"{file_id}.wav"
            import shutil
            shutil.copy2(str(output_wav), str(persistent_path))
            app_state["encoded_files"][file_id] = str(persistent_path)

            processing_time = (time.time() - start_time) * 1000
            
            if background_tasks:
                background_tasks.add_task(cleanup_temp_file, temp_dir)

            return EncodeResponse(
                success=True,
                file_id=file_id,
                original_duration=original_duration,
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
        finally:
            # Ensure temp directory is cleaned up even on error
            if temp_dir and Path(temp_dir).exists():
                import shutil
                shutil.rmtree(temp_dir, ignore_errors=True)
            # Force garbage collection to free memory immediately
            gc.collect()

    @app.post("/api/v1/decode", response_model=DecodeResponse)
    async def decode_watermark(request_data: DecodeRequest):
        """
        Extract watermark from previously encoded audio file.

        **Parameters:**
        - **file_id**: File ID from encoding response
        - **message_length**: Expected message length (optional, default tries 4-32)
        - **use_cnn**: Use CNN decoder for compressed audio (optional)
        - **confidence_threshold**: Minimum confidence to accept result (0-1)

        **Returns:**
        - **message**: Extracted message (null if not detected)
        - **confidence**: Extraction confidence (0-1)
        - **method**: Decoder method used (classical or cnn)
        - **snr_db**: Estimated signal-to-noise ratio
        """
        file_id = request_data.file_id
        message_length = getattr(request_data, 'message_length', None)
        use_cnn = request_data.use_cnn
        confidence_threshold = request_data.confidence_threshold
        
        start_time = time.time()
        temp_dir = tempfile.mkdtemp()

        try:
            # Get audio from file_id
            if file_id not in app_state["encoded_files"]:
                raise HTTPException(
                    status_code=404,
                    detail=f"File ID '{file_id}' not found",
                )
            input_wav = app_state["encoded_files"][file_id]
            message = None
            confidence = 0.0
            snr = None
            method = "classical"
            
            # **PRIMARY: Try CNN decoder first if available**
            if CNN_AVAILABLE:
                try:
                    logger.info("Attempting CNN decoding (primary method)...")
                    cnn_decoder = CNNWatermarkDecoder()
                    
                    # Determine message length to try with CNN
                    cnn_msg_len = message_length if message_length is not None else 8  # Default to 8 chars if auto-detect
                    cnn_result = cnn_decoder.decode_with_cnn(str(input_wav), message_length=cnn_msg_len)
                    
                    if isinstance(cnn_result, dict):
                        message = cnn_result.get('message')
                        confidence = cnn_result.get('cnn_confidence', 0.0)
                        method = "cnn"
                        logger.info(f"CNN decode successful: message='{message}', confidence={confidence:.2%}")
                    else:
                        logger.warning(f"CNN returned unexpected type: {type(cnn_result)}")
                except Exception as e:
                    logger.error(f"CNN decoding failed: {str(e)}", exc_info=True)
                    message = None
                    confidence = 0.0
            
            # **FALLBACK: Use classical decoder if CNN failed or unavailable**
            if message is None or confidence < confidence_threshold:
                logger.info("Attempting classical decoding...")
                decoder = AudioGuardDecoder()
                
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
                        method = "classical"
                        logger.info(f"Classical decode with length={message_length}: message={message}, conf={confidence:.2%}")
                    except Exception as e:
                        logger.warning(f"Decode failed with message_length={message_length}: {str(e)}")
                else:
                    # Try different message lengths (min 1 to max_message_length)
                    max_len = request_data.max_message_length
                    best_result = (None, 0.0, None)
                    for try_length in range(1, max_len + 1):
                        try:
                            result = decoder.decode(str(input_wav), message_length=try_length)
                            if isinstance(result, dict):
                                msg = result.get('message')
                                conf = result.get('confidence', 0.0)
                                s = result.get('snr_db')
                            else:
                                msg, conf, s = result
                            
                            if msg is not None and conf > best_result[1]:
                                best_result = (msg, conf, s)
                                if conf > 0.8:  # Good enough, stop searching
                                    break
                        except Exception:
                            continue
                    
                    if best_result[0] is not None:
                        message, confidence, snr = best_result
                        method = "classical"
                        logger.info(f"Classical decode with auto-length: message={message}, conf={confidence:.2%}")

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
            gc.collect()
            return DecodeResponse(
                success=False,
                message=None,
                confidence=0.0,
                method="unknown",
                processing_time_ms=(time.time() - start_time) * 1000,
                error=str(e),
            )

    @app.post("/api/v1/verify", response_model=VerifyResponse)
    async def verify_watermark(request_data: VerifyRequest):
        """
        Check if audio contains watermark (binary classification).

        **Parameters:**
        - **file_id**: File ID from encoding response
        - **confidence_threshold**: Minimum confidence to accept watermark (default 0.7)

        **Returns:**
        - **watermark_detected**: True if watermark is present
        - **confidence**: Detection confidence (0-1)
        """
        file_id = request_data.file_id
        confidence_threshold = request_data.confidence_threshold
        start_time = time.time()
        temp_dir = tempfile.mkdtemp()

        try:
            # Get audio from file_id
            if file_id not in app_state["encoded_files"]:
                raise HTTPException(
                    status_code=404,
                    detail=f"File ID '{file_id}' not found",
                )
            input_wav = app_state["encoded_files"][file_id]

            # Use CNN if available, else classical
            watermark_detected = False
            confidence = 0.0
            
            if CNN_AVAILABLE:
                try:
                    detector = CNNWatermarkDecoder()
                    _, confidence = detector.decode(str(input_wav))
                    watermark_detected = confidence > confidence_threshold
                except Exception:
                    # Fallback to classical
                    decoder = AudioGuardDecoder()
                    # Try different message lengths to detect watermark
                    max_len = request_data.max_message_length
                    for try_length in range(1, max_len + 1):
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
                max_len = request_data.max_message_length
                for try_length in range(1, max_len + 1):
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
            gc.collect()
            raise HTTPException(status_code=500, detail=f"Verification failed: {str(e)}")

    @app.post("/api/v1/analyze", response_model=AnalyzeResponse)
    async def analyze_audio(request_data: AnalyzeRequest):
        """
        Analyze audio for watermark presence and signal strength.

        **Parameters:**
        - **file_id**: File ID from encoding response
        - **confidence_threshold**: Minimum confidence to accept watermark (default 0.5)

        **Returns:**
        - **watermark_present**: Whether watermark is detected
        - **signal_strength**: Signal strength (0-1)
        - **spectral_info**: Spectral analysis information
        """
        file_id = request_data.file_id
        confidence_threshold = request_data.confidence_threshold
        start_time = time.time()
        temp_dir = tempfile.mkdtemp()

        try:
            # Get audio from file_id
            if file_id not in app_state["encoded_files"]:
                raise HTTPException(
                    status_code=404,
                    detail=f"File ID '{file_id}' not found",
                )
            input_wav = app_state["encoded_files"][file_id]

            # Analyze with decoder - try different message lengths
            decoder = AudioGuardDecoder()
            message = None
            confidence = 0.0
            snr = None
            
            max_len = request_data.max_message_length
            for try_length in range(1, max_len + 1):
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

            # Validate watermark: only report if message contains mostly printable characters AND meets confidence threshold
            # This prevents false positives from random bit patterns  
            watermark_present = False
            if message is not None and confidence >= confidence_threshold:
                # Check if at least 70% of characters are printable/ASCII
                printable_count = sum(1 for c in str(message) if 32 <= ord(c) <= 126)
                if len(message) > 0:
                    printable_ratio = printable_count / len(message)
                    watermark_present = (printable_ratio >= 0.7)

            return AnalyzeResponse(
                success=True,
                watermark_present=watermark_present,
                signal_strength=confidence if watermark_present else 0.0,
                spectral_info={
                    "snr_db": float(snr) if (snr is not None and watermark_present) else 0.0,
                    "message_detected": watermark_present,
                    "confidence": float(confidence) if watermark_present else 0.0,
                },
                processing_time_ms=processing_time,
            )

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Analysis error: {str(e)}")
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)
            gc.collect()
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
    """Clean up temporary files and force garbage collection."""
    try:
        import shutil
        shutil.rmtree(path, ignore_errors=True)
    except Exception as e:
        logger.warning(f"Failed to clean up {path}: {str(e)}")
    finally:
        # Force garbage collection to free memory immediately
        gc.collect()


def cleanup_resources():
    """Force cleanup of all temporary files in storage directory."""
    try:
        import shutil
        # Clean up old temp directories (older than 1 hour)
        now = time.time()
        for item in Path(tempfile.gettempdir()).iterdir():
            if item.name.startswith("tmp") and item.is_dir():
                try:
                    mtime = item.stat().st_mtime
                    if now - mtime > 3600:  # Older than 1 hour
                        shutil.rmtree(str(item), ignore_errors=True)
                except Exception:
                    pass
        gc.collect()
    except Exception as e:
        logger.warning(f"Resource cleanup failed: {e}")


# Create default app instance
app = create_app(debug=False)
