# System Architecture

AudioGuard is a distributed system consisting of a Flutter mobile application and a FastAPI backend server. It uses advanced digital signal processing (DSP) to embed and extract watermarks in the spectral domain of audio signals.

## Table of Contents
1. [High-Level Architecture](#high-level-architecture)
2. [Component Overview](#component-overview)
3. [Data Flow](#data-flow)
4. [Technology Stack](#technology-stack)
5. [Watermarking Engine](#watermarking-engine)
6. [Security Architecture](#security-architecture)

## High-Level Architecture

AudioGuard follows a client-server model where the mobile app handles user interaction and audio management, while the backend performs the computationally intensive spectral operations.

```text
┌─────────────────────────────────────┐
│     Flutter Mobile Application      │
│   - Audio capture and management    │
│   - Watermark UI & Visualization    │
│   - Local TFLite Inference (Opt)    │
└────────────────┬────────────────────┘
                 │
                 │ REST API (HTTPS)
                 ▼
┌──────────────────────────────────────────┐
│      FastAPI Backend Server              │
│  - Request routing and validation        │
│  - Watermark encoding/decoding/verify    │
│  - Spectral analysis & visualization     │
│  - Persistent storage management         │
└────────────────┬─────────────────────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │ Watermarking Engine  │
      ├──────────────────────┤
      │ STFT Analysis        │
      │ Psychoacoustic Model │
      │ Magnitude Modulation │
      └──────────────────────┘
```

## Component Overview

### 1. Mobile Application (Frontend)
The mobile app provides the user interface for all watermarking operations.
*   **Audio Service**: Manages recording and importing audio files, extracting metadata, and performing basic validation.
*   **API Service**: Handles all communication with the backend using the Dio package for robust HTTP requests.
*   **Local Service**: Implements on-device processing using TensorFlow Lite for rapid verification.
*   **State Management**: Uses Riverpod for reactive UI updates and efficient error handling.

### 2. Backend Server
The backend acts as the orchestration layer for the core engine.
*   **FastAPI**: Provides high-performance, asynchronous endpoints for all operations.
*   **Storage Manager**: Manages temporary files and persistence for processed audio in a secure directory.
*   **API Layer**: Implements strict Pydantic models for request/response validation.

### 3. Core Engine
The heart of AudioGuard, written in Python using NumPy and SciPy.
*   **Encoder**: Implements the STFT-based embedding logic with magnitude modulation.
*   **Decoder**: Handles bit extraction, error correction, and confidence scoring.
*   **Psychoacoustic Model**: Calculates masking thresholds to ensure the watermark remains inaudible.

## Data Flow

### Encoding Workflow
1.  **Input**: User selects an audio file and enters a message (1-255 characters).
2.  **Request**: App sends a `POST` request with the audio and message to `/api/v1/encode`.
3.  **Validation**: Backend verifies file type and message length.
4.  **Processing**:
    *   **STFT**: Audio is decomposed into frequency spectra.
    *   **Embedding**: Binary bits are modulated into specific frequency magnitudes.
    *   **Masking**: Signal is adjusted to stay below the human auditory threshold.
    *   **ISTFT**: Signal is reconstructed into time-domain audio.
5.  **Persistence**: File is saved with a unique `file_id`.
6.  **Response**: Backend returns `file_id`, duration, and embedding metadata.

### Verification and Decoding
*   **Verification**: Fast binary check for watermark presence using pattern matching.
*   **Decoding**: Full extraction of the binary message with confidence scoring (typically >95% for high-fidelity sources).

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter (Dart) | Cross-platform mobile app |
| **Backend** | FastAPI (Python) | High-performance REST API |
| **DSP** | NumPy, SciPy | Signal processing and audio handling |
| **Audio I/O** | pydub (FFmpeg backend) | MP3, WAV, OGG, FLAC, M4A support |
| **Error Correction** | reedsolo (Reed-Solomon) | 20% ECC overhead, 8-byte error correction |
| **ML** | TensorFlow Lite, PyTorch | CNN-based robust decoding |
| **Cache** | Redis | API caching and session management |
| **Proxy** | Nginx | Rate limiting and SSL termination |
| **DevOps** | Docker | Environment isolation and deployment |

## Watermarking Engine

The engine operates in the frequency domain to achieve high robustness and transparency, with multi-resolution processing for enhanced accuracy.

### Multi-Resolution STFT Pipeline
AudioGuard uses **three parallel STFTs** at different frame sizes (1024, 2048, 4096 samples) to achieve high robustness:

```
Audio Input
    ↓
┌───────────────────────────────────────┐
│   Multi-Resolution STFT Analysis      │
├───────────────────────────────────────┤
│  Frame 1024 Hz (Fine Time Res)        │
│  Frame 2048 Hz (Balanced)             │
│  Frame 4096 Hz (Fine Freq Res)        │
└───────────────────────────────────────┘
    ↓
┌───────────────────────────────────────┐
│   Energy-Adaptive Embedding           │
│   (Per-bin amplitude scaling)          │
└───────────────────────────────────────┘
    ↓
┌───────────────────────────────────────┐
│   Reed-Solomon ECC (20% overhead)     │
│   16 error symbols per 255-byte block │
└───────────────────────────────────────┘
    ↓
Audio Output (Embedded 3x for redundancy)
```

**Key Features:**
- **Fine Time Resolution** (1024): Survives time-stretching attacks.
- **Fine Frequency Resolution** (4096): Survives pitch-shifting attacks.
- **Majority Voting**: Combined extraction from all 3 resolutions for enhanced bit accuracy.
- **Energy-Adaptive Amplitude**: Modulation scaled by local spectral energy for imperceptibility.

### Psychoacoustic Masking
AudioGuard uses a masking model based on human hearing sensitivity. It calculates frequency-specific thresholds, allowing stronger watermark embedding in "noisy" spectral regions where human perception is least sensitive.

### Error Correction
The system implements **Reed-Solomon Error Correction (ECC)** using the `reedsolo` library:
- **16 error symbols** per 255-byte block (20% overhead).
- Corrects up to **8-byte errors** per block.
- Validates successfully even post-compression in lossy formats.

## Security Architecture

*   **Input Validation**: All API inputs are strictly typed and range-checked.
*   **Secure File Handling**: Files are stored with non-predictable IDs and cleaned up regularly.
*   **Statelessness**: The API is stateless, reducing complexity and potential attack vectors.
*   **Rate Limiting**: Nginx layer protects against brute-force decoding or DDoS attacks.

---
[Return to Documentation Index](README.md)
