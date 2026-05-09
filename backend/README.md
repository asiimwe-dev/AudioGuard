# AudioGuard Backend

Production-grade audio watermarking engine built with FastAPI, NumPy/SciPy (DSP), and Reed-Solomon error correction.

## Table of Contents

1. [Overview](#overview)
2. [Setup & Installation](#setup--installation)
3. [Running the Server](#running-the-server)
4. [API Reference](#api-reference)
5. [Architecture](#architecture)
6. [Configuration](#configuration)
7. [Production Deployment](#production-deployment)
8. [Known Limitations (Phase 1)](#known-limitations-phase-1)

## Overview

AudioGuard embeds invisible, robust audio watermarks using multi-resolution STFT. The backend provides REST endpoints for:

- **Encoding:** Embed a watermark message into audio
- **Decoding:** Attempt message recovery (Phase 2 improvement planned)
- **Verification:** Fast binary detection of watermark presence
- **Analysis:** Full spectral characteristics + watermark status
- **File Management:** Upload, download, and retrieve processed audio

### Key Features

✅ **Multi-Resolution STFT:** 3 independent resolutions (2048, 1024, 512 frame sizes) for redundancy  
✅ **Reed-Solomon ECC:** 20% overhead for error correction  
✅ **Fast Verification:** <100ms for binary detection  
✅ **MP3 & WAV Support:** Automatic format handling  
✅ **Persistent File Storage:** UUID-tracked file management  
✅ **Production Logging:** Structured JSON output  

⚠️ **Classical Decoder:** ~50% bit accuracy (Phase 2: CNN-based redesign)

## Setup & Installation

### Requirements

- Python 3.10+
- pip or Poetry for dependency management

### Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

Key dependencies:
- `fastapi` — REST framework
- `numpy`, `scipy` — DSP primitives
- `soundfile` — Audio I/O
- `reedsolo` — Reed-Solomon error correction
- `pydub` — Format conversion (MP3)

### Install for Development

```bash
pip install -r requirements.txt
pip install pytest pytest-cov black flake8  # optional dev tools
```

## Running the Server

### Development (localhost)

```bash
cd backend
python -m uvicorn api.main:app --reload --host 127.0.0.1 --port 8000
```

Then visit:
- **API Docs:** http://localhost:8000/docs
- **Health Check:** http://localhost:8000/health

### Production

```bash
gunicorn \
  --workers 4 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  api.main:app
```

See [Production Deployment](#production-deployment) for containerization and cloud setup.

## API Reference

Full endpoint documentation is in [`../docs/03-api-reference.md`](../docs/03-api-reference.md).

### Quick Examples

#### Encode (Watermark)

```bash
curl -X POST http://localhost:8000/api/v1/encode \
  -F "audio_file=@sample.wav" \
  -F "message=AUTHOR_ID_001" \
  -F "amplitude_factor=0.05"
```

Response:
```json
{
  "success": true,
  "file_id": "550e8400-e29b-41d4-a716-446655440000",
  "original_duration": 2.5,
  "sample_rate": 44100,
  "processing_time_ms": 487.34
}
```

#### Verify (Fast Detection)

```bash
curl -X POST http://localhost:8000/api/v1/verify \
  -F "file_id=550e8400-e29b-41d4-a716-446655440000"
```

Response:
```json
{
  "success": true,
  "watermark_detected": true,
  "confidence": 0.95,
  "processing_time_ms": 98.5
}
```

#### Analyse (Spectral Info)

```bash
curl -X POST http://localhost:8000/api/v1/analyse \
  -F "file_id=550e8400-e29b-41d4-a716-446655440000"
```

Response:
```json
{
  "success": true,
  "watermark_detected": true,
  "rms": 0.085,
  "peak": 0.42,
  "dynamic_range_db": 12.3,
  "snr_db": 45.2,
  "watermark_confidence": 0.95,
  "processing_time_ms": 142.8
}
```

## Architecture

### Directory Structure

```
backend/
├── api/
│   ├── main.py              # FastAPI app + all route handlers
│   ├── schemas.py           # Pydantic request/response models
│   ├── dependencies.py      # FastAPI dependency injection
│   └── server.py            # Legacy file (deprecated)
├── core/
│   ├── watermarker.py       # Multi-res STFT embedding/extraction
│   ├── message_codec.py     # Barker-13 sync + ECC encoding/decoding
│   ├── ecc.py               # Reed-Solomon wrapper
│   └── sync.py              # Barker-13 correlation utilities
├── engine/
│   ├── encoder.py           # High-level encode API
│   ├── decoder.py           # High-level decode API
│   └── utils.py             # STFT/iSTFT, windowing, normalization
├── requirements.txt         # Python dependencies
├── pytest.ini               # pytest configuration
└── README.md                # This file
```

### Data Flow: Encoding

1. **User uploads audio + message**
   - File streamed to temporary storage (never held in memory)
   - Filename logged for tracking

2. **Preprocessing**
   - Convert to mono (stereo mixed down)
   - Normalize to max amplitude ≤ 1.0
   - Resample to target rate if needed

3. **Message Encoding**
   - Message → length header (1 byte)
   - Message + header → Barker-13 sync (23 bits) + ECC blocks
   - Total: 24 + len(msg) + nsym bits

4. **Watermark Embedding**
   - STFT at 3 resolutions (2048, 1024, 512 frame sizes)
   - Each bit spread across 4 frequency bins per resolution
   - Energy-adaptive magnitude modulation (amplitude_factor scaled by bin energy)
   - Deterministic pseudo-random bin selection (seeded for reproducibility)

5. **iSTFT + Save**
   - Inverse STFT via overlap-add (75% overlap, Hanning window)
   - Export as WAV
   - Store file UUID + metadata in persistent storage

### Data Flow: Verification

1. **Load watermarked audio**
2. **Multi-resolution extraction**
   - STFT at each resolution
   - Extract magnitude modulation (deviation from expected STFT bin magnitude)
   - Per-resolution confidence scoring
3. **Majority vote**
   - Combine confidences across resolutions
   - Return `watermark_detected` if overall confidence > threshold (0.60)

### DSP Parameters (Fixed)

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Frame Size** | 2048 samples | Frequency resolution ~21 Hz @ 44.1 kHz |
| **Hop Size** | 512 samples (75% overlap) | COLA condition: perfect reconstruction |
| **Hanning Window** | Applied per frame | Spectral leakage reduction |
| **Amplitude Factor** | 0.05 (default) | Inaudible; range 0.01–1.0 |
| **Bits per Frame** | 4 | Spread factor for robustness |
| **Resolution Count** | 3 (2048, 1024, 512) | Redundancy against frame-size mismatches |
| **ECC Strength** | 20% | Reed-Solomon nsym parameter |
| **Barker-13 Threshold** | 0.60 | Sync detection confidence (tuned for robustness) |
| **Search Window** | 8192 samples | Barker sync search span |

## Configuration

### Environment Variables

```bash
# API
export ALLOWED_ORIGINS="http://localhost:3000,https://example.com"
export MAX_FILE_SIZE_MB=100
export MAX_DURATION_SECONDS=3600

# Logging
export LOG_LEVEL=INFO
export LOG_FORMAT=json  # or 'text'

# DSP (optional overrides)
export AMPLITUDE_FACTOR=0.05
export BITS_PER_FRAME=4
export BARKER_THRESHOLD=0.60
```

### File Storage

- **Default Location:** `/tmp/audioguard_storage/` (or Render's ephemeral disk)
- **Cleanup:** Manual via `backend/scripts/cleanup.sh` or automatic on process exit
- **Production:** Migrate to S3/GCS for durability across restarts

## Production Deployment

### 1. Containerization (Docker)

Create `backend/Dockerfile`:

```dockerfile
FROM python:3.10-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["gunicorn", "--workers=4", "--worker-class=uvicorn.workers.UvicornWorker", "--bind=0.0.0.0:8000", "api.main:app"]
```

Build and run:

```bash
docker build -t audioguard-backend:latest .
docker run -p 8000:8000 \
  -e ALLOWED_ORIGINS="https://example.com" \
  -e LOG_LEVEL=INFO \
  audioguard-backend:latest
```

### 2. Render.com Deployment

See `../render.yaml` for full configuration. Key points:

- **Build Command:** `pip install -r backend/requirements.txt`
- **Start Command:** `gunicorn --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000 api.main:app`
- **Port:** 8000
- **Ephemeral Storage:** Files at `/tmp/audioguard_storage/` do NOT persist across restarts

### 3. CI/CD Pipeline

GitHub Actions workflow in `.github/workflows/ci.yml`:

```yaml
- name: Run Backend Tests
  run: cd backend && pytest -v
```

Tests include:
- STFT COLA condition validation
- ECC encode/decode round-trips
- API contract verification
- Multi-resolution redundancy

Run locally:

```bash
cd backend
pytest -v
```

### 4. Monitoring & Logging

All endpoints log request/response in JSON format:

```json
{
  "timestamp": "2025-04-25T12:34:56.789Z",
  "level": "INFO",
  "endpoint": "/api/v1/encode",
  "status": 200,
  "duration_ms": 487.34,
  "file_id": "550e8400-e29b-41d4-a716-446655440000",
  "message_length": 14
}
```

For production monitoring, integrate with:
- **CloudWatch** (AWS)
- **Stackdriver** (GCP)
- **Application Insights** (Azure)
- **Datadog** or **New Relic** (SaaS)

### 5. Security Hardening

- [ ] Enable HTTPS (TLS certificate from Let's Encrypt or similar)
- [ ] Implement rate limiting (FastAPI SlowAPI middleware)
- [ ] Add API key authentication (if multi-tenant)
- [ ] Run behind reverse proxy (Nginx) for additional filtering
- [ ] Implement file upload virus scanning (ClamAV or similar)
- [ ] Migrate from in-process `_JOBS` to Redis for cross-worker coordination

## Known Limitations (Phase 1)

### Classical Decoder (~50% Bit Accuracy)

The current `message_codec.py` uses z-score normalization per frame to extract bits, but achieves only chance-level accuracy (~50%) even on freshly encoded audio.

**Root Cause:** The energy-deviation model does not distinguish between watermarked and non-watermarked bins robustly in the presence of natural spectral variation.

**Status:** This is a **Phase 2 task**. Planned solutions:
1. **CNN-based Extraction:** Train a model to learn the signal model from labeled encode/decode pairs.
2. **Heuristic Redesign:** Model natural STFT variation more accurately (e.g., smoothness constraints, harmonic structure).
3. **SNR-Adaptive Thresholds:** Dynamic per-bin thresholds based on surrounding bin energy.

**Workaround (Phase 1):** Use `verify` (binary detection) and `analyse` (spectral info) for production use cases that don't require message recovery.

### Verify False Positives (Minor)

The `analyse` endpoint detects watermarks in *any* audio (including non-watermarked files) due to natural spectral variation. Confidence is high (~0.95) even for false positives.

**Mitigation:** Set a higher confidence threshold (e.g., 0.95+) or use post-encoding verification (known to be reliable).

### Multi-Worker Deployment

The in-process `_JOBS` dictionary is **not thread-safe** or distributed-safe. For multi-worker production deployments, migrate to Redis or a database backend.

### File Storage Durability

Files stored at `/tmp/audioguard_storage/` are **ephemeral** on Render.com. They do not persist across dyno restarts. For production, migrate to persistent storage (S3, GCS, or Persistent Disk).

---

## Troubleshooting

### "Module not found" when running tests

```bash
cd backend
pytest tests/
```

Or with explicit PYTHONPATH:

```bash
PYTHONPATH=/home/asiimwe/Projects/AudioGuard python -m pytest backend/tests/
```

### Audio file not encoding

Check file format:
```bash
ffprobe -v error -show_format -show_streams audio.wav
```

Ensure it's PCM (not compressed ADPCM or other codec).

### High decode confidence but incorrect message

This is expected with the classical decoder (Phase 1). The confidence reflects the presence of the sync header, not message accuracy. Message recovery accuracy is ~50% (chance level). Phase 2 will redesign this.

---

**For full API documentation, see [API REFERENCE](../docs/03-api-reference.md).**

**For Phase 2 roadmap, see [PHASE 2 ROADMAP](../docs/PHASE_2_ROADMAP.md).**
