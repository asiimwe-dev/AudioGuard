# API Reference

This document provides a comprehensive reference for the AudioGuard REST API.

## Table of Contents
1. [Base URL](#base-url)
2. [Interactive Documentation](#interactive-documentation)
3. [Engine Capabilities](#engine-capabilities)
4. [Endpoints Overview](#endpoints-overview)
5. [Endpoint Details](#endpoint-details)
6. [Error Handling](#error-handling)

## Base URL
*   Development: `http://localhost:8000`
*   Production: `http://<your-server>:8000`

## Interactive Documentation
Interactive API documentation is available at the following locations when the server is running:
*   Swagger UI: `http://localhost:8000/docs`
*   ReDoc: `http://localhost:8000/redoc`

## Engine Capabilities

All endpoints utilize the production-grade **Multi-Resolution STFT** engine with Reed-Solomon Error Correction and persistent metadata storage. These features are fully integrated and provide high robustness with zero changes required to the API contract.

**Key Engine Features (Automatic):**
- ✅ Multi-resolution watermark embedding (3x redundancy)
- ✅ Reed-Solomon error correction (20% overhead)
- ✅ Adaptive energy thresholding for extraction
- ✅ Persistent file storage with UUID tracking
- ✅ Per-resolution confidence scoring
- ✅ Support for MP3, AAC, and OGG formats

## Endpoints Overview

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/health` | GET | Service health check | ✅ Production |
| `/api/v1/encode` | POST | Embed watermark into audio | ✅ Production |
| `/api/v1/decode` | POST | Extract watermark from audio | ⚠️ Classical (Phase 2: CNN) |
| `/api/v1/verify` | POST | Check for watermark presence | ✅ Production |
| `/api/v1/analyse` | POST | Spectral analysis + watermark status | ✅ Production |
| `/api/v1/upload` | POST | Upload audio without encoding | ✅ Production |
| `/api/v1/files/{file_id}` | GET | Download processed audio | ✅ Production |
| `/api/v1/download/{file_id}` | GET | Legacy download alias | ✅ Production |

## Endpoint Details

### 1. Health Check
Checks if the service is running and returns its current status.

**Request**
```bash
curl -X GET http://localhost:8000/health
```

**Response (200 OK)**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "models_available": ["classical"],
  "uptime_seconds": 1234.56
}
```

### 2. Encode
Embeds an invisible watermark message into an audio file using STFT.

**Request**
```bash
curl -X POST http://localhost:8000/api/v1/encode \
  -F "audio_file=@audio.wav" \
  -F "message=AUTHOR_ID_001" \
  -F "amplitude_factor=0.05"
```

**Parameters (Form Data)**
*   `audio_file` (File, Required): The WAV/MP3 file to watermark.
*   `message` (String, Required): The message to embed (1-255 characters).
*   `amplitude_factor` (Float, Optional): Watermark strength (Default: 0.05, Range: 0.01-1.0).

**Response (200 OK)**
```json
{
  "success": true,
  "file_id": "550e8400-e29b-41d4-a716-446655440000",
  "original_duration": 2.5,
  "sample_rate": 44100,
  "processing_time_ms": 487.34
}
```

### 3. Decode
Extracts a watermark message from a processed audio file.

**⚠️ Phase 1 Status:** The classical decoder is currently under development. While the endpoint is available, message recovery accuracy is limited (~50% bit accuracy). Phase 2 will introduce CNN-based recovery for >95% accuracy.

**Request (via file_id)**
```bash
curl -X POST http://localhost:8000/api/v1/decode \
  -F "file_id=550e8400-e29b-41d4-a716-446655440000"
```

**Request (via direct upload)**
```bash
curl -X POST http://localhost:8000/api/v1/decode \
  -F "file=@watermarked.wav"
```

**Parameters (Form Data)**
*   `file_id` (String, Optional): The UUID returned from encode.
*   `file` or `audio_file` (File, Optional): Direct audio file upload.
*   `seed` (Integer, Optional): Seed used during encoding (default: 42).

**Response (200 OK)**
```json
{
  "success": false,
  "message": null,
  "confidence": 0.95,
  "snr_db": 45.2,
  "ber_estimate": 0.50,
  "sync_found": false,
  "ecc_errors": 0,
  "method": "classical_multires",
  "processing_time_ms": 125.4,
  "error": null
}
```

**Response Fields:**
*   `success`: Whether a message was successfully decoded.
*   `message`: Decoded message string (null if decode failed).
*   `confidence`: Bit-level confidence (0.0-1.0).
*   `snr_db`: Estimated signal-to-noise ratio.
*   `ber_estimate`: Bit error rate estimate.
*   `sync_found`: Whether Barker-13 sync header was detected.
*   `ecc_errors`: Number of errors corrected by Reed-Solomon.
*   `method`: Extraction method used (classical_multires).


### 4. Verify
Quickly checks if a watermark is present in the audio without extracting the full message.

**Request (via file_id)**
```bash
curl -X POST http://localhost:8000/api/v1/verify \
  -F "file_id=550e8400-e29b-41d4-a716-446655440000" \
  -F "confidence_threshold=0.60"
```

**Request (via direct upload)**
```bash
curl -X POST http://localhost:8000/api/v1/verify \
  -F "file=@watermarked.wav" \
  -F "confidence_threshold=0.60"
```

**Parameters (Form Data)**
*   `file_id` (String, Optional): UUID from encode endpoint.
*   `file` or `audio_file` (File, Optional): Direct audio file.
*   `confidence_threshold` (Float, Optional): Detection threshold (default: 0.60, range: 0.0-1.0).

**Response (200 OK)**
```json
{
  "success": true,
  "watermark_detected": true,
  "verdict": "watermarked",
  "confidence": 0.95,
  "processing_time_ms": 98.5
}
```

**Response Fields:**
*   `watermark_detected`: Boolean verdict.
*   `verdict`: One of `watermarked`, `not_watermarked`, or `possibly_tampered`.
*   `confidence`: Detection confidence (0.0-1.0).

### 5. Analyse
Full spectral analysis and watermark status detection.

**Request (via file_id)**
```bash
curl -X POST http://localhost:8000/api/v1/analyse \
  -F "file_id=550e8400-e29b-41d4-a716-446655440000"
```

**Request (via direct upload)**
```bash
curl -X POST http://localhost:8000/api/v1/analyse \
  -F "file=@audio.wav"
```

**Parameters (Form Data)**
*   `file_id` (String, Optional): UUID from encode endpoint.
*   `file` or `audio_file` (File, Optional): Direct audio file.

**Response (200 OK)**
```json
{
  "success": true,
  "duration_s": 2.5,
  "sample_rate": 44100,
  "rms": 0.085,
  "peak": 0.42,
  "dynamic_range_db": 12.3,
  "watermark_detected": true,
  "watermark_message": null,
  "watermark_confidence": 0.95,
  "snr_db": 45.2,
  "watermark_present": true,
  "signal_strength": 0.95,
  "spectral_info": {
    "duration_s": 2.5,
    "sample_rate": 44100,
    "rms": 0.085,
    "peak": 0.42,
    "dynamic_range_db": 12.3
  },
  "processing_time_ms": 142.8
}
```

### 6. Upload
Upload an audio file without encoding (for later decode/verify/analyse operations).

**Request**
```bash
curl -X POST http://localhost:8000/api/v1/upload \
  -F "file=@audio.wav"
```

**Parameters (Form Data)**
*   `file` or `audio_file` (File, Required): Audio file to store.

**Response (200 OK)**
```json
{
  "file_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 7. Download
Retrieve a processed (watermarked) or uploaded audio file.

**Request**
```bash
curl -X GET http://localhost:8000/api/v1/files/550e8400-e29b-41d4-a716-446655440000 \
  -o watermarked.wav
```

**Response (200 OK)**
Audio file (WAV format) is streamed to the client.


## Error Handling

The API returns standard HTTP status codes and a JSON error body for failures.

**Error Response Format**
```json
{
  "error": "Error message description",
  "status_code": 400
}
```

**Common Status Codes**
*   `200`: Success
*   `400`: Bad Request (Invalid parameters)
*   `404`: Not Found (Invalid file ID)
*   `422`: Unprocessable Content (Parameter out of range, e.g., invalid audio file)
*   `500`: Internal Server Error

## Response Field Semantics

### `embedding_strength` (Encode response)
A heuristic value computed as `min(1.0, snr_db / 20.0)` representing the relative strength of the watermark embedding. Not a direct measure of audibility—it reflects only the estimated SNR at embedding time.

**Note:** This field is informational and should not be used for decode strategy selection in production; use the `amplitude_factor` parameter instead.

### `watermark_present` (Analyse response)
Indicates whether a watermark signature was detected in the spectral bins. This is a statistical verdict based on energy deviation from the baseline, not a guarantee. In Phase 1, watermark detection is reliable (>99% accuracy on freshly encoded audio). In degraded scenarios, false positives are possible; use `confidence` to assess reliability.

### `signal_strength` (Analyse response)
A normalized metric (0.0-1.0) indicating the overall signal-to-noise ratio. Values >0.8 indicate high confidence in any detection verdict. Values <0.5 should be treated with caution.

### `spectral_info` (Analyse response)
Informational metadata about the audio's spectral characteristics (RMS, peak amplitude, dynamic range). This can help assess whether a given audio is suitable for watermarking or has been significantly modified post-encoding.

## Production Considerations

### File Storage
- **Location:** Uploaded and encoded files are stored in the backend's temporary storage directory (default: `/tmp/audioguard_storage/` or Render's ephemeral filesystem).
- **Lifetime:** Files persist for the duration of the backend process. For production multi-worker deployments, implement persistent storage (e.g., S3, GCS) and a Redis-backed job store instead of the in-process `_JOBS` dict.
- **Cleanup:** Temporary files are automatically cleaned up when the backend process exits.

### Rate Limiting
Currently no rate limiting is enforced on the API. For production deployments, implement rate limiting (e.g., via FastAPI middleware) to prevent abuse.

### TLS / HTTPS
- **Development:** The client accepts unverified certificates for localhost, 127.0.0.1, 10.0.2.2 (Android emulator), and *.local domains.
- **Production:** Always use valid certificates signed by a trusted CA. Update the client configuration to enforce certificate verification.

### Concurrency & Threading
The backend uses an in-process `_JOBS` dictionary to track file upload/encode operations. This is **not thread-safe** for multi-worker deployments. For production, migrate to a Redis-backed job store to coordinate across worker processes.

---
[Return to Documentation Index](README.md)
