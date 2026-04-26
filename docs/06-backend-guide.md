# Backend Guide

The AudioGuard backend is a high-performance Python application built with FastAPI. It serves as the orchestration layer for the core spectral watermarking engine, providing a robust REST API and a feature-rich CLI.

## Table of Contents
1. [Core Technologies](#core-technologies)
2. [Project Structure](#project-structure)
3. [Watermarking Engine](#watermarking-engine)
4. [API Architecture](#api-architecture)
5. [Command-Line Interface (CLI)](#command-line-interface-cli)
6. [Performance and Testing](#performance-and-testing)

## Core Technologies
*   **FastAPI**: Asynchronous web framework for high-performance APIs.
*   **NumPy & SciPy**: Used for core signal processing and matrix operations.
*   **Librosa**: Audio analysis and format handling.
*   **Uvicorn**: ASGI server for production-grade performance.
*   **Pytest**: Comprehensive testing framework.
*   **TensorFlow Lite**: Used for CNN-based robust decoding (mobile-optimized).

## Project Structure

```text
backend/
├── api/                # FastAPI application and endpoint definitions
│   ├── models.py       # Pydantic request/response models
│   └── server.py       # API routing and business logic
├── engine/             # Core watermarking logic
│   ├── encoder.py      # Watermark embedding (STFT-based)
│   ├── decoder.py      # Watermark extraction (Classical)
│   ├── cnn_decoder.py  # Robust extraction (Deep Learning)
│   └── psychoacoustic.py # Human auditory masking model
├── tests/              # Unit and integration test suite
├── app.py              # Application entry point
└── cli.py              # Command-line interface for local/batch use
```

## Watermarking Engine

The engine implements a multi-phase pipeline designed for high fidelity and robustness.

### Encoder (`engine/encoder.py`)
1.  **STFT Analysis**: Decomposes audio into frequency-domain spectra.
2.  **Magnitude Modulation**: Modulates specific frequency magnitudes to represent binary data.
3.  **Psychoacoustic Masking**: Ensures the added signal is inaudible by calculating frequency-specific thresholds.
4.  **Inverse STFT**: Reconstructs the time-domain signal.

### Decoder (`engine/decoder.py` & `engine/cnn_decoder.py`)
AudioGuard employs a hybrid decoding strategy:
*   **Classical Decoder**: High-speed extraction for high-fidelity audio (e.g., WAV).
*   **CNN Decoder**: Deep learning model optimized for robust extraction from compressed or noisy audio (e.g., low-bitrate MP3).

## API Architecture

The API is designed for scalability and mobile integration:
*   **Endpoints**: Fully documented via Swagger UI at `/docs`.
*   **Asynchronous I/O**: Handles concurrent file uploads and processing efficiently.
*   **Security**: Includes parameter validation, secure file storage, and optional JWT/API key authentication.

## Command-Line Interface (CLI)

The `cli.py` tool provides power users with batch processing capabilities:
```bash
# Example: Batch watermark a directory
python cli.py batch --directory ./raw --message "AUTH_001" --output-dir ./signed
```
Features include:
*   Colored output and progress indicators.
*   JSON output mode for pipeline integration.
*   Auto-detection of message length.

## Performance and Testing

### Performance Benchmarks
| Operation | 2s Audio | 60s Audio | Throughput |
|-----------|----------|-----------|------------|
| Encode | ~450ms | ~250ms | 240x Realtime |
| Decode | ~200ms | ~200ms | 300x Realtime |
| Verify | ~150ms | ~150ms | 400x Realtime |

### Testing Strategy
AudioGuard maintains high reliability through a suite of 60+ tests:
*   **Unit Tests**: Validate DSP algorithms and masking curves.
*   **API Tests**: Ensure endpoint reliability and correct status code handling.
*   **Robustness Tests**: Verify watermark survival against MP3 compression and noise addition.

To run the suite:
```bash
pytest tests/ -v
```

---
[Return to Documentation Index](README.md)
