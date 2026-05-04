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

| Endpoint | Method | Purpose | Engine Features |
|----------|--------|---------|-----------------|
| `/health` | GET | Service health check | Reports engine readiness |
| `/api/v1/encode` | POST | Embed watermark into audio | Multi-res + ECC + storage |
| `/api/v1/decode` | POST | Extract watermark from audio | Multi-res voting + ECC recovery |
| `/api/v1/verify` | POST | Check for watermark presence | Multi-res confidence scoring |
| `/api/v1/analyze` | POST | Spectral analysis of audio | Per-resolution BER heatmap |
| `/api/v1/download/{file_id}` | GET | Retrieve processed audio | UUID-tracked persistent storage |

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

**Request**
```bash
curl -X POST http://localhost:8000/api/v1/decode \
  -H "Content-Type: application/json" \
  -d '{
    "file_id": "550e8400-e29b-41d4-a716-446655440000",
    "message_length": 14
  }'
```

**Parameters (JSON Body)**
*   `file_id` (String, Required): The UUID returned from the encode endpoint.
*   `message_length` (Integer, Optional): Expected message length for better accuracy.

**Response (200 OK)**
```json
{
  "success": true,
  "message": "AUTHOR_ID_001",
  "confidence": 0.9847,
  "method": "classical"
}
```

### 4. Verify
Quickly checks if a watermark is present in the audio without extracting the full message.

**Request**
```bash
curl -X POST http://localhost:8000/api/v1/verify \
  -H "Content-Type: application/json" \
  -d '{"file_id": "550e8400-e29b-41d4-a716-446655440000"}'
```

**Response (200 OK)**
```json
{
  "success": true,
  "watermark_detected": true,
  "confidence": 0.8734
}
```

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
*   `422`: Validation Error (Parameter out of range)
*   `500`: Internal Server Error

---
[Return to Documentation Index](README.md)
