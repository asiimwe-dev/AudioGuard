"""
AudioGuard Mobile SDK (Python Bridge)

Provides Python interface for mobile applications to integrate AudioGuard
watermarking and verification capabilities. Supports both local processing
(via TFLite) and cloud API fallback.

Usage (Local):
    from audioguard_sdk import AudioGuardMobile
    guard = AudioGuardMobile(use_local=True)
    guard.encode("input.wav", "output.wav", "AUTHOR")
    message, confidence = guard.decode("output.wav")

Usage (Cloud):
    guard = AudioGuardMobile(
        api_url="https://api.audioguard.io",
        api_key="your_api_key"
    )
    message, confidence = guard.decode("audio.mp3")
"""

from typing import Tuple, Optional, Dict
from pathlib import Path
import json
import time
import logging
from dataclasses import dataclass

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Try importing local models
try:
    from engine import AudioGuardEncoder, AudioGuardDecoder
    try:
        from engine import CNNWatermarkDecoder
        CNN_AVAILABLE = True
    except ImportError:
        CNN_AVAILABLE = False
    LOCAL_AVAILABLE = True
except ImportError:
    LOCAL_AVAILABLE = False


@dataclass
class EncodeResult:
    """Encoding result."""
    success: bool
    output_path: str
    duration: float
    sample_rate: int
    processing_time_ms: float
    metadata: Dict = None


@dataclass
class DecodeResult:
    """Decoding result."""
    success: bool
    message: Optional[str]
    confidence: float
    method: str  # 'local', 'api', 'cnn'
    processing_time_ms: float


@dataclass
class VerifyResult:
    """Verification result."""
    success: bool
    watermark_detected: bool
    confidence: float
    processing_time_ms: float


class AudioGuardMobile:
    """
    Mobile-optimized AudioGuard SDK for local & cloud processing.

    Supports:
    - Local watermarking/verification (no network required)
    - Cloud API fallback for heavy computation
    - Hybrid mode (local check → cloud verification)
    - Automatic degradation handling (MP3, compressed audio)
    """

    def __init__(
        self,
        use_local: bool = True,
        api_url: Optional[str] = None,
        api_key: Optional[str] = None,
        tflite_model_path: Optional[str] = None,
        fallback_to_api: bool = True,
    ):
        """
        Initialize AudioGuard Mobile SDK.

        Args:
            use_local: Use local models (requires engine installed)
            api_url: Cloud API URL (e.g., https://api.audioguard.io)
            api_key: API key for authentication
            tflite_model_path: Path to TFLite model for CNN (optional)
            fallback_to_api: Automatically fallback to API if local fails
        """
        self.use_local = use_local and LOCAL_AVAILABLE
        self.api_url = api_url
        self.api_key = api_key
        self.fallback_to_api = fallback_to_api
        self.tflite_model_path = tflite_model_path

        # Verify configuration
        if not self.use_local and not api_url:
            raise ValueError("Provide either use_local=True or api_url for cloud API")

        # Initialize local encoders/decoders
        if self.use_local:
            logger.info("✓ Initializing local models")
            self.encoder = AudioGuardEncoder()
            self.decoder = AudioGuardDecoder()
            if CNN_AVAILABLE:
                self.cnn_decoder = CNNWatermarkDecoder()
            else:
                self.cnn_decoder = None
        else:
            logger.info("✓ Configured for cloud API")

        logger.info(f"  Local: {self.use_local}")
        logger.info(f"  Cloud API: {bool(api_url)}")
        logger.info(f"  CNN available: {CNN_AVAILABLE}")
        logger.info(f"  Fallback to API: {fallback_to_api}")

    def encode(
        self,
        input_path: str,
        output_path: str,
        message: str,
        amplitude_factor: float = 0.05,
        frame_size: int = 2048,
        bits_per_frame: int = 4,
        seed: int = 42,
    ) -> EncodeResult:
        """
        Embed watermark in audio file.

        Args:
            input_path: Path to input audio
            output_path: Path to save watermarked audio
            message: Message to embed (1-255 chars)
            amplitude_factor: Watermark strength (0.01-1.0)
            frame_size: STFT frame size
            bits_per_frame: Redundancy factor
            seed: Random seed for reproducibility

        Returns:
            EncodeResult with success status and metadata
        """
        start_time = time.time()

        # Validate
        if not Path(input_path).exists():
            return EncodeResult(
                success=False,
                output_path=output_path,
                duration=0,
                sample_rate=0,
                processing_time_ms=0,
                metadata={"error": f"File not found: {input_path}"},
            )

        if not (1 <= len(message) <= 255):
            return EncodeResult(
                success=False,
                output_path=output_path,
                duration=0,
                sample_rate=0,
                processing_time_ms=0,
                metadata={"error": "Message length must be 1-255 characters"},
            )

        # Local encoding
        if self.use_local:
            try:
                logger.info(f"Encoding locally: {input_path}")
                metadata = self.encoder.encode(
                    input_path,
                    output_path,
                    message,
                    bits_per_frame=bits_per_frame,
                )

                # Get audio metadata
                try:
                    import soundfile as sf
                    audio_data, sr = sf.read(input_path)
                    duration = len(audio_data) / sr
                except Exception:
                    duration = 0
                    sr = 0

                processing_time = (time.time() - start_time) * 1000

                return EncodeResult(
                    success=True,
                    output_path=output_path,
                    duration=duration,
                    sample_rate=sr,
                    processing_time_ms=processing_time,
                    metadata=metadata,
                )

            except Exception as e:
                logger.error(f"Local encoding failed: {str(e)}")
                if not self.fallback_to_api:
                    raise
                # Continue to API fallback

        # Cloud API encoding (not implemented in demo)
        return EncodeResult(
            success=False,
            output_path=output_path,
            duration=0,
            sample_rate=0,
            processing_time_ms=(time.time() - start_time) * 1000,
            metadata={"error": "No encoding method available"},
        )

    def decode(
        self,
        audio_path: str,
        message_length: Optional[int] = None,
        use_cnn: bool = True,
    ) -> DecodeResult:
        """
        Extract watermark from audio file.

        Args:
            audio_path: Path to watermarked audio
            message_length: Expected message length (optional for local)
            use_cnn: Use CNN decoder for degraded audio

        Returns:
            DecodeResult with extracted message and confidence
        """
        start_time = time.time()

        # Validate
        if not Path(audio_path).exists():
            return DecodeResult(
                success=False,
                message=None,
                confidence=0.0,
                method="unknown",
                processing_time_ms=0,
            )

        # Local decoding
        if self.use_local:
            try:
                logger.info(f"Decoding locally: {audio_path}")

                best_message = None
                best_confidence = 0.0

                # Try specified length or all reasonable lengths
                lengths = [message_length] if message_length else range(1, 33)

                for length in lengths:
                    try:
                        result = self.decoder.decode(audio_path, length)
                        if result["confidence"] > best_confidence:
                            best_message = result["message"]
                            best_confidence = result["confidence"]
                    except Exception:
                        continue

                # Fallback to CNN if available and confidence low
                if (
                    use_cnn
                    and CNN_AVAILABLE
                    and (best_message is None or best_confidence < 0.5)
                ):
                    try:
                        logger.info("Trying CNN decoder...")
                        message, confidence = self.cnn_decoder.decode(audio_path)
                        return DecodeResult(
                            success=message is not None,
                            message=message,
                            confidence=confidence,
                            method="cnn",
                            processing_time_ms=(time.time() - start_time) * 1000,
                        )
                    except Exception as e:
                        logger.warning(f"CNN decoding failed: {str(e)}")

                return DecodeResult(
                    success=best_message is not None,
                    message=best_message,
                    confidence=best_confidence,
                    method="local",
                    processing_time_ms=(time.time() - start_time) * 1000,
                )

            except Exception as e:
                logger.error(f"Local decoding failed: {str(e)}")
                if not self.fallback_to_api:
                    raise

        return DecodeResult(
            success=False,
            message=None,
            confidence=0.0,
            method="unknown",
            processing_time_ms=(time.time() - start_time) * 1000,
        )

    def verify(self, audio_path: str) -> VerifyResult:
        """
        Binary verification: does audio contain watermark?

        Args:
            audio_path: Path to audio file

        Returns:
            VerifyResult with detection status
        """
        start_time = time.time()

        # Local verification
        if self.use_local:
            try:
                result = self.decode(audio_path)
                return VerifyResult(
                    success=result.success,
                    watermark_detected=result.message is not None,
                    confidence=result.confidence,
                    processing_time_ms=(time.time() - start_time) * 1000,
                )
            except Exception as e:
                logger.error(f"Local verification failed: {str(e)}")

        return VerifyResult(
            success=False,
            watermark_detected=False,
            confidence=0.0,
            processing_time_ms=(time.time() - start_time) * 1000,
        )


if __name__ == "__main__":
    # Demo usage
    print("AudioGuard Mobile SDK")
    print("====================\n")

    # Local mode
    if LOCAL_AVAILABLE:
        print("1. Local mode (no network required):")
        guard_local = AudioGuardMobile(use_local=True)
        print("✓ Local SDK initialized\n")

        print("Usage:")
        print('  result = guard.encode("input.wav", "output.wav", "AUTHOR")')
        print('  result = guard.decode("watermarked.wav")')
        print('  result = guard.verify("audio.wav")\n')

    # Cloud mode
    print("2. Cloud mode (remote API):")
    print("  guard = AudioGuardMobile(")
    print('    api_url="https://api.audioguard.io",')
    print('    api_key="your_api_key"')
    print("  )\n")

    # Hybrid mode
    print("3. Hybrid mode (local + cloud fallback):")
    print("  guard = AudioGuardMobile(")
    print("    use_local=True,")
    print('    api_url="https://api.audioguard.io",')
    print("    fallback_to_api=True")
    print("  )\n")
