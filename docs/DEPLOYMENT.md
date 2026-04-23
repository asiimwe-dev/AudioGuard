# AudioGuard Phase 4: Production Deployment Guide

**Version:** 1.0.0  
**Status:** Production-Ready  
**Last Updated:** 2026-04-23

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [REST API](#rest-api)
3. [Command-Line Interface](#command-line-interface)
4. [Docker Deployment](#docker-deployment)
5. [Performance Benchmarks](#performance-benchmarks)
6. [Mobile Integration](#mobile-integration)
7. [Security Considerations](#security-considerations)

---

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/asiimwe-dev/AudioGuard.git
cd AudioGuard

# Install dependencies (API + Phase 1-3)
pip install -r requirements.txt -r requirements-api.txt

# Verify installation
python -c "from api import create_app; print('✓ API ready')"
```

### Encode Audio (CLI)

```bash
# Embed watermark in audio file
python cli.py encode -i input.wav -o watermarked.wav -m "AUTHOR_ID_001"

# With custom parameters
python cli.py encode -i input.wav -o output.wav -m "MSG" \
  --amplitude 0.1 \
  --frame-size 1024 \
  --bits-per-frame 2 \
  --seed 42
```

### Decode Audio (CLI)

```bash
# Extract watermark from audio
python cli.py decode -i watermarked.wav

# Specify message length for faster decoding
python cli.py decode -i watermarked.wav --message-length 10

# Use CNN for compressed audio
python cli.py decode -i compressed.mp3 --use-cnn
```

### Verify Watermark (CLI)

```bash
# Binary watermark detection (yes/no)
python cli.py verify -i audio.wav
```

### Analyze Audio (CLI)

```bash
# Get audio properties and statistics
python cli.py analyze -i audio.wav

# Output as JSON
python cli.py analyze -i audio.wav --json
```

### Batch Processing (CLI)

```bash
# Watermark multiple files
python cli.py batch \
  --directory ./audio_files \
  --message "BATCH_AUTHOR" \
  --output-dir ./watermarked \
  --amplitude 0.05
```

---

## REST API

### Starting the API Server

```bash
# Development mode (auto-reload)
uvicorn app:app --reload --host 0.0.0.0 --port 8000

# Production mode (4 workers)
uvicorn app:app --host 0.0.0.0 --port 8000 --workers 4
```

### API Endpoints

#### 1. **Health Check**

```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "models_available": ["classical", "cnn"],
  "uptime_seconds": 3600.5
}
```

---

#### 2. **Encode Watermark**

```http
POST /api/v1/encode
Content-Type: multipart/form-data

{
  "file": <audio_file>,
  "message": "AUTHOR_ID",
  "amplitude_factor": 0.05,
  "frame_size": 2048,
  "bits_per_frame": 4,
  "seed": 42
}
```

**Response:**
```json
{
  "success": true,
  "file_id": "file_1713900180_7234",
  "original_duration": 10.5,
  "sample_rate": 44100,
  "message_length": 9,
  "embedding_strength": 0.05,
  "processing_time_ms": 450.2
}
```

---

#### 3. **Decode Watermark**

```http
POST /api/v1/decode
Content-Type: application/json

{
  "file_id": "file_1713900180_7234",
  "use_cnn": false,
  "confidence_threshold": 0.5
}
```

**Response:**
```json
{
  "success": true,
  "message": "AUTHOR_ID",
  "confidence": 0.95,
  "method": "classical",
  "snr_db": 15.2,
  "processing_time_ms": 380.1
}
```

---

## Command-Line Interface

### Encode Example

```bash
python cli.py encode -i voice.wav -o watermarked.wav -m "AUTHOR"
```

### Decode Example

```bash
python cli.py decode -i watermarked.wav --message-length 6
```

### Batch Processing Example

```bash
python cli.py batch \
  --directory ./audio_files \
  --message "BATCH_ID" \
  --output-dir ./watermarked
```

---

## Docker Deployment

### Quick Start

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f api

# Stop services
docker-compose down
```

### Docker Images

- **audioguard:latest** - REST API server (~500MB)
- **redis:7-alpine** - Cache layer (~50MB)
- **nginx:alpine** - Reverse proxy with rate limiting (~50MB)

---

## Performance Benchmarks

| Task | Duration | Speed |
|------|----------|-------|
| Encode 1min audio | ~250ms | 240x realtime |
| Decode 1min audio | ~200ms | 300x realtime |
| Verify 1min audio | ~150ms | 400x realtime |
| API encode (10MB) | ~2s | - |
| API decode (10MB) | ~1.5s | - |

---

## Mobile Integration

### TensorFlow Lite Model

Convert CNN to mobile format:

```python
from engine.cnn_model import convert_to_tflite
convert_to_tflite("models/watermark_detector.tflite")
```

Model specs:
- Size: < 10MB
- Inference: < 500ms on mobile CPU
- Quantization: int8 (optional)

### Flutter/React Native

Integrate with platform channels:

```dart
// Load model and run inference
final result = await audioguardChannel.invokeMethod('detectWatermark');
```

---

## Security

- **Authentication:** JWT tokens (configurable)
- **Rate Limiting:** 10 req/s regular, 5 req/s uploads
- **HTTPS:** Ready for SSL/TLS deployment
- **Data Privacy:** Temporary files cleaned up automatically
- **OWASP:** Top 10 compliance (injection protection, input validation, etc.)

---

## Support & Documentation

- Full API documentation at `/docs` (Swagger UI)
- OpenAPI schema at `/openapi.json`
- CLI help: `python cli.py --help`
- Issue tracker: https://github.com/asiimwe-dev/AudioGuard/issues
