# AudioGuard Backend - Complete Implementation Guide

## Overview

AudioGuard is an audio watermarking system that embeds imperceptible digital watermarks into audio files for ownership verification and copyright protection. This guide covers the implementation architecture, key concepts, and how to use all components.

**Key Features**:
- 🔐 Imperceptible watermark embedding (amplitude factor 0.05)
- 🎯 Binary watermark detection
- 📝 Message encoding/decoding (1-255 characters)
- ⚡ Real-time processing (70ms for 2-second audio)
- 🔄 RESTful API endpoints
- 💻 Command-line interface (CLI)
- 🧪 Comprehensive test suite (62/62 passing)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [How Watermarking Works](#how-watermarking-works)
3. [Directory Structure](#directory-structure)
4. [Core Components](#core-components)
5. [Using the CLI](#using-the-cli)
6. [Using the REST API](#using-the-rest-api)
7. [Running Tests](#running-tests)
8. [Key Implementation Details](#key-implementation-details)
9. [Advanced Configuration](#advanced-configuration)

---

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    AudioGuard Backend                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         REST API (FastAPI)                           │   │
│  │  - /api/v1/encode   (POST: upload + watermark)      │   │
│  │  - /api/v1/verify   (POST: binary detection)         │   │
│  │  - /api/v1/decode   (POST: message recovery)         │   │
│  │  - /api/v1/analyze  (POST: spectral analysis)        │   │
│  │  - /api/v1/download (GET: file download)             │   │
│  │  - /health          (GET: server status)             │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         CLI Interface (Click)                        │   │
│  │  - encode   (embed watermark)                        │   │
│  │  - verify   (binary detection)                       │   │
│  │  - decode   (message recovery)                       │   │
│  │  - analyze  (spectral analysis)                      │   │
│  │  - batch    (process directories)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Core Engine                                  │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │ AudioGuardEncoder                               │ │   │
│  │  │ - STFT computation (frequency analysis)         │ │   │
│  │  │ - Bit-spreading algorithm                       │ │   │
│  │  │ - Energy-adaptive modulation                    │ │   │
│  │  │ - Inverse STFT (signal reconstruction)          │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  │                                                       │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │ AudioGuardDecoder                               │ │   │
│  │  │ - STFT extraction (frequency analysis)          │ │   │
│  │  │ - Bit recovery (ratio-based detection)          │ │   │
│  │  │ - Confidence scoring                            │ │   │
│  │  │ - Message extraction                            │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  │                                                       │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │ Utilities                                       │ │   │
│  │  │ - STFT/iSTFT (utils.py)                        │ │   │
│  │  │ - Audio I/O (utils.py)                         │ │   │
│  │  │ - Bit manipulation (utils.py)                  │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

#### Encoding Process
```
Audio File → Load audio → Normalize → Compute STFT
    ↓
Message → Convert to bits → Spread across bins
    ↓
Apply amplitude modulation → Inverse STFT → Output audio
```

#### Verification Process
```
Audio File → Load → Compute STFT → Extract bits
    ↓
Calculate confidence → Detect watermark presence → Output result
```

#### Decoding Process
```
Audio File → Load → Compute STFT → Extract all bits
    ↓
Try different message lengths → Score message quality
    ↓
Output: best decoded message + confidence
```

---

## How Watermarking Works

### Fundamental Concept

The watermarking technique uses **Short-Time Fourier Transform (STFT)** to convert audio from time domain to frequency domain, where watermarks can be embedded imperceptibly.

### Step-by-Step Encoding

#### 1. **Audio Loading & Normalization** (`engine/encoder.py:encode()`)
```python
# Load audio file and normalize
audio = librosa.load(input_file, sr=44100, mono=True)
audio = audio / max(abs(audio))  # Normalize to [-1, 1]
```

#### 2. **STFT Computation** (`engine/utils.py:stft()`)
The STFT breaks audio into overlapping frames and applies Fourier transform to each:

```python
import numpy as np
from scipy import signal

def stft(audio, frame_size=2048, hop_length=None):
    if hop_length is None:
        hop_length = frame_size // 2
    
    # Apply Hanning window for spectral leakage reduction
    window = signal.hann(frame_size)
    
    # Compute STFT
    f, t, Zxx = signal.stft(
        audio, 
        fs=44100,
        window=window,
        nperseg=frame_size,
        noverlap=frame_size - hop_length
    )
    
    return Zxx  # Complex spectrogram (frequency × time)
```

**Output**: A 2D array with shape `(1025, num_frames)` for 44.1kHz audio
- 1025 frequency bins (2048/2 + 1)
- One column per frame (50ms overlapping windows)

#### 3. **Message Encoding** (`engine/encoder.py:_message_to_bits()`)
```python
def _message_to_bits(message):
    # Convert message to ASCII then to binary
    bits = ''.join(format(ord(c), '08b') for c in message)
    return [int(b) for b in bits]
```

Example: `"A"` → ASCII 65 → `"01000001"` → `[0,1,0,0,0,0,0,1]`

#### 4. **Bit-Spreading Algorithm** (`engine/encoder.py:_spread_bits_across_bins()`)

Each bit is spread across multiple frequency bins for redundancy and robustness:

```python
def _spread_bits_across_bins(bits, stft_matrix, seed=42):
    num_frames = stft_matrix.shape[1]
    rng = np.random.RandomState(seed)
    
    # For each bit, select random frequency bins in each frame
    for bit_idx, bit_value in enumerate(bits):
        # Select bins randomly (deterministic with seed)
        bins = rng.choice(50, 100, size=4, replace=False)  # 4 bins per frame
        
        # Mark these bins (bit_value = 1 increases magnitude, 0 decreases)
        for frame_idx in range(num_frames):
            for bin_idx in bins:
                # Magnitude modulation (details below)
                stft_matrix[bin_idx, frame_idx] *= modulation_factor
```

#### 5. **Energy-Adaptive Magnitude Modulation** (`engine/encoder.py:encode()`)

Watermark strength is adapted based on the energy (magnitude) of each frequency bin:

```python
def encode(self, input_file, output_file, message, amplitude_factor=0.05):
    # ... STFT computed ...
    
    # Compute bin energy (magnitude)
    magnitudes = np.abs(stft_matrix)
    bin_energy = np.sum(magnitudes**2, axis=1)
    
    # Normalize energy to [0.5, 1.0] scale
    normalized_energy = 0.5 + 0.5 * (bin_energy / np.max(bin_energy))
    
    # Apply modulation: use higher amplitude in high-energy bins
    # This keeps watermark imperceptible (louder frequencies can tolerate more change)
    for bin_idx in watermark_bins:
        modulation = amplitude_factor * normalized_energy[bin_idx]
        stft_matrix[bin_idx] += modulation * sign(bit_value)
```

**Key insight**: Watermark is imperceptible because:
- Amplitude factor = 0.05 means only 5% magnitude change
- Changes are applied to existing signal energy, not as noise
- Human ear is less sensitive to phase changes

#### 6. **Inverse STFT & Audio Reconstruction** (`engine/utils.py:istft()`)

```python
def istft(stft_matrix, frame_size=2048, hop_length=None):
    # Convert frequency-domain back to time-domain
    _, reconstructed_audio = signal.istft(
        stft_matrix,
        fs=44100,
        window='hann',
        nperseg=frame_size,
        noverlap=frame_size - hop_length
    )
    return reconstructed_audio
```

---

## Directory Structure

```
backend/
├── README.md                          ← You are here
├── requirements.txt                   ← Python dependencies
├── requirements-api.txt               ← API-specific dependencies
├── app.py                             ← FastAPI entry point
├── cli.py                             ← Command-line interface
├── main.py                            ← Alternative entry point
├── Dockerfile                         ← Docker container config
├── docker-compose.yml                 ← Docker compose setup
│
├── engine/                            ← CORE WATERMARKING ENGINE
│   ├── __init__.py
│   ├── encoder.py                     ⭐ Watermark embedding (bit-spreading algorithm)
│   ├── decoder.py                     ⭐ Watermark extraction (bit recovery)
│   ├── utils.py                       ⭐ STFT, audio I/O, bit manipulation
│   ├── ecc.py                         ⭐ Reed-Solomon error correction (Phase 1)
│   ├── sync.py                        ⭐ Barker sync headers (Phase 1)
│   ├── cnn_model.py                   📊 CNN architecture for Phase 3
│   ├── cnn_decoder.py                 📊 CNN-based decoder (Phase 3)
│   └── convert_to_tflite.py           📊 TensorFlow Lite conversion
│
├── api/                               ← REST API LAYER
│   ├── __init__.py
│   ├── server.py                      ⭐ FastAPI app (endpoints definition)
│   ├── models.py                      ⭐ Request/response schemas (Pydantic)
│   ├── storage.py                     ✅ File storage management
│   └── routes.py                      (if modularized)
│
├── models/                            ← TRAINED MODELS (Phase 3)
│   ├── cnn_model.pth                  (PyTorch model file)
│   ├── watermark_detector.h5          (TensorFlow Lite model)
│   └── convert_to_tflite.py           (Conversion utility)
│
├── data/                              ← STORAGE & DATASETS
│   ├── test_audio/                    (Test audio samples)
│   ├── output/                        (Encoded audio files)
│   └── models/                        (Model storage)
│
└── tests/                             ← TEST SUITE
    ├── __init__.py
    ├── test_encoder.py                ⭐ Encoder unit tests
    ├── test_decoder.py                ⭐ Decoder unit tests
    ├── test_api.py                    ⭐ API endpoint tests (22 tests)
    ├── test_utils.py                  ⭐ Utility function tests
    ├── test_ecc.py                    (ECC verification tests)
    ├── test_sync.py                   (Sync header tests)
    └── test_integration.py            (End-to-end tests)
```

### Key Files to Understand

| File | Purpose | Key Functions |
|------|---------|---------------|
| `engine/encoder.py` | Watermark embedding | `AudioGuardEncoder.encode()`, `_spread_bits_across_bins()` |
| `engine/decoder.py` | Watermark extraction | `AudioGuardDecoder.decode()`, `_estimate_bit_energy()` |
| `engine/utils.py` | Signal processing | `stft()`, `istft()`, `load_audio()`, `message_to_bits()` |
| `api/server.py` | API endpoints | `create_app()`, `/encode`, `/verify`, `/decode` |
| `api/models.py` | Request schemas | `EncodeRequest`, `VerifyRequest`, `DecodeRequest` |
| `cli.py` | Command-line | `encode_command()`, `verify_command()`, `decode_command()` |

---

## Core Components

### 1. AudioGuardEncoder (`engine/encoder.py`)

**Purpose**: Embeds imperceptible watermarks into audio files

**Main Method**:
```python
def encode(
    self,
    input_file: str,
    output_file: str,
    message: str,
    amplitude_factor: float = 0.05,
    frame_size: int = 2048,
    bits_per_frame: int = 4,
    seed: int = None
) -> Dict
```

**Key Parameters**:
- `amplitude_factor` (0.01-1.0): Watermark strength (0.05 = imperceptible)
- `frame_size` (1024-4096): STFT window size (larger = better frequency resolution)
- `bits_per_frame` (1-8): Redundancy (more = more robust but larger footprint)
- `seed`: Random seed for reproducible bit-spreading

**Fourier Transform Implementation**:
```python
# Location: engine/encoder.py:encode() lines 45-65
from scipy import signal

# Compute STFT (Short-Time Fourier Transform)
stft_matrix = self.stft(audio, frame_size)
# Returns: Complex spectrogram with shape (1025, num_frames)

# Modify spectrogram
stft_matrix = self._embed_watermark(stft_matrix, message_bits)

# Inverse STFT for audio reconstruction
output_audio = self.istft(stft_matrix)
```

**Bit-Spreading Algorithm** (Location: `engine/encoder.py:lines 150-170`):
```python
def _spread_bits_across_bins(self, bits, stft_matrix, seed=42):
    """Spread each bit across multiple frequency bins for robustness"""
    rng = np.random.RandomState(seed)
    
    for bit_idx, bit_value in enumerate(bits):
        # Deterministically select bins for this bit
        selected_bins = rng.choice(
            range(50, 100),  # Frequency range (speech-safe)
            size=self.bits_per_frame,
            replace=False
        )
        
        # Apply modulation to selected bins in all frames
        for frame_idx in range(stft_matrix.shape[1]):
            modulation = amplitude * normalized_energy[selected_bins]
            direction = 1 if bit_value else -1
            stft_matrix[selected_bins, frame_idx] *= (1 + direction * modulation)
```

### 2. AudioGuardDecoder (`engine/decoder.py`)

**Purpose**: Extracts watermarks and recovers embedded messages

**Main Methods**:
```python
def decode(
    self,
    input_file: str,
    message_length: int,
    use_cnn: bool = False,
    confidence_threshold: float = 0.5
) -> Dict
```

**Bit Recovery Algorithm** (Location: `engine/decoder.py:lines 95-135`):
```python
def _estimate_bit_energy(self, original_stft, watermarked_stft, bit_index):
    """Detect if a bit is 0 or 1 by comparing STFT magnitudes"""
    
    # Extract magnitudes
    original_mag = np.abs(original_stft)
    watermarked_mag = np.abs(watermarked_stft)
    
    # Compute ratio in watermark frequency bins
    ratio = np.mean(
        watermarked_mag[watermark_bins] / (original_mag[watermark_bins] + 1e-10)
    )
    
    # Bit detection: ratio > 1.0 → bit=1, else bit=0
    confidence = abs(ratio - 1.0)
    bit_value = 1 if ratio > 1.0 else 0
    
    return bit_value, confidence
```

**Confidence Scoring**:
- 0.0-0.5: Watermark not detected (false positive risk)
- 0.5-0.95: Marginal detection
- 0.95-1.0: Strong detection (recommended threshold ≥ 0.95)

### 3. Signal Processing Utilities (`engine/utils.py`)

**STFT Implementation**:
```python
def stft(audio, frame_size=2048, hop_length=None):
    """Short-Time Fourier Transform"""
    if hop_length is None:
        hop_length = frame_size // 2
    
    window = np.hanning(frame_size)
    f, t, Zxx = scipy.signal.stft(
        audio, fs=44100, window=window,
        nperseg=frame_size, noverlap=frame_size - hop_length
    )
    return Zxx  # Shape: (1025, num_frames)
```

**Inverse STFT**:
```python
def istft(stft_matrix, frame_size=2048, hop_length=None):
    """Inverse Short-Time Fourier Transform"""
    _, reconstructed = scipy.signal.istft(
        stft_matrix, fs=44100, window='hann',
        nperseg=frame_size, noverlap=frame_size - hop_length
    )
    return reconstructed
```

**Message Encoding/Decoding**:
```python
def message_to_bits(message):
    """Convert message to binary array"""
    return [int(b) for c in message for b in format(ord(c), '08b')]

def bits_to_message(bits):
    """Convert binary array back to text"""
    chars = []
    for i in range(0, len(bits), 8):
        byte = ''.join(str(b) for b in bits[i:i+8])
        if len(byte) == 8:
            chars.append(chr(int(byte, 2)))
    return ''.join(chars)
```

---

## Using the CLI

### Installation

```bash
cd backend
pip install -r requirements.txt
```

### Commands

#### 1. Encode (Embed Watermark)

**Syntax**:
```bash
python cli.py encode -i INPUT_FILE -o OUTPUT_FILE -m MESSAGE [OPTIONS]
```

**Example**:
```bash
python cli.py encode \
  -i input.wav \
  -o watermarked.wav \
  -m "Author: John Doe" \
  -a 0.05 \
  --frame-size 2048 \
  --bits-per-frame 4
```

**Output**:
```
ℹ Encoding 'Author: John Doe' into input.wav...
[AudioGuardEncoder] Reading audio from input.wav...
[AudioGuardEncoder] Audio: 10.00s @ 44100Hz
[AudioGuardEncoder] Embedding message: 'Author: John Doe' (128 bits)
[AudioGuardEncoder] Computing STFT (frame_size=2048)...
[AudioGuardEncoder] STFT computed: 434 frames × 1025 bins
[AudioGuardEncoder] Applying bit-spreading watermark...
[AudioGuardEncoder] Reconstructing audio from modified spectrum...
[AudioGuardEncoder] Saving watermarked audio to watermarked.wav...
[AudioGuardEncoder] ✓ Watermarking complete!
✓ Watermark embedded successfully
ℹ Output: watermarked.wav
ℹ Message: Author: John Doe (16 chars)
ℹ Duration: 10.00s @ 44100Hz
ℹ Strength: 0.050 (amplitude factor)
```

**Options**:
| Flag | Default | Description |
|------|---------|-------------|
| `-i, --input` | required | Input audio file path |
| `-o, --output` | required | Output audio file path |
| `-m, --message` | required | Message to embed (1-255 chars) |
| `-a, --amplitude` | 0.05 | Watermark strength (0.01-1.0) |
| `--frame-size` | 2048 | STFT window size |
| `--bits-per-frame` | 4 | Redundancy factor (1-8) |
| `--seed` | random | Random seed for reproducibility |
| `--json` | false | Output as JSON |

#### 2. Verify (Binary Detection)

**Syntax**:
```bash
python cli.py verify -i INPUT_FILE [OPTIONS]
```

**Example**:
```bash
python cli.py verify -i watermarked.wav
```

**Output**:
```
ℹ Verifying watermark in watermarked.wav...
[AudioGuardDecoder] Loading audio from watermarked.wav...
[AudioGuardDecoder] Audio: 10.00s @ 44100Hz
[AudioGuardDecoder] Expecting 1 chars (8 bits)
[AudioGuardDecoder] Computing STFT...
[AudioGuardDecoder] STFT: 434 frames × 1025 bins
[AudioGuardDecoder] Extracting watermark bits...
✓ Watermark detected
ℹ Confidence: 100.0%
ℹ Time: 125ms
```

**Options**:
| Flag | Default | Description |
|------|---------|-------------|
| `-i, --input` | required | Audio file to verify |
| `--json` | false | Output as JSON |

**Note**: Verify performs binary detection (watermark present/absent) without needing the original message.

#### 3. Decode (Message Recovery)

**Syntax**:
```bash
python cli.py decode -i INPUT_FILE [OPTIONS]
```

**Example**:
```bash
python cli.py decode -i watermarked.wav --max-length 32
```

**Output**:
```
ℹ Decoding watermark from watermarked.wav...
[AudioGuardDecoder] Loading audio from watermarked.wav...
[AudioGuardDecoder] Audio: 10.00s @ 44100Hz
[AudioGuardDecoder] Expecting 16 chars (128 bits)
[AudioGuardDecoder] Computing STFT...
[AudioGuardDecoder] STFT: 434 frames × 1025 bins
[AudioGuardDecoder] Extracting watermark bits...
✓ Watermark detected: 'Author: John Doe'
ℹ Confidence: 98.5%
ℹ Method: classical
ℹ SNR: 2.45 dB
ℹ Time: 245ms
```

**Options**:
| Flag | Default | Description |
|------|---------|-------------|
| `-i, --input` | required | Audio file |
| `--max-length` | 32 | Max message length to try |
| `--use-cnn` | false | Use CNN decoder (Phase 3) |
| `--json` | false | Output as JSON |

#### 4. Analyze (Spectral Analysis)

**Syntax**:
```bash
python cli.py analyze -i INPUT_FILE [OPTIONS]
```

**Example**:
```bash
python cli.py analyze -i watermarked.wav
```

**Output**:
```
ℹ File: watermarked.wav
ℹ Duration: 10.00s
ℹ Sample Rate: 44100Hz
ℹ Channels: 1
ℹ RMS Level: 0.1234
ℹ Peak Level: 0.7890
ℹ Crest Factor: 6.39
ℹ Dynamic Range: 18.0dB
```

#### 5. Batch Processing

**Syntax**:
```bash
python cli.py batch -i INPUT_DIR -o OUTPUT_DIR -m MESSAGE [OPTIONS]
```

**Example**:
```bash
python cli.py batch \
  -i ./input_audio/ \
  -o ./encoded_audio/ \
  -m "Copyright 2024" \
  --pattern "*.wav"
```

**Output**:
```
Processing batch of audio files...
[1/5] Processing song1.wav... ✓
[2/5] Processing song2.wav... ✓
[3/5] Processing song3.wav... ✓
[4/5] Processing song4.wav... ✓
[5/5] Processing song5.wav... ✓
✓ Batch processing complete: 5/5 successful
```

#### 6. JSON Output

All commands support `--json` flag for machine-readable output:

**Example**:
```bash
python cli.py encode -i input.wav -o output.wav -m "Test" --json | python3 -m json.tool
```

**Output**:
```json
{
  "success": true,
  "file": "output.wav",
  "message": "Test",
  "duration_seconds": 10.0,
  "sample_rate": 44100,
  "channels": 1,
  "embedding_strength": 0.05,
  "processing_time_ms": 245
}
```

---

## Using the REST API

### Starting the Server

**Option 1: Direct Python**
```bash
cd backend
PORT=5000 python app.py
```

**Option 2: Uvicorn**
```bash
uvicorn app:app --host 0.0.0.0 --port 5000 --reload
```

**Option 3: Docker**
```bash
docker-compose up -d
```

### API Endpoints

#### 1. Health Check

```http
GET /health
```

**Response**:
```json
{
  "status": "ok",
  "version": "1.0.0",
  "models_available": ["classical", "cnn"],
  "uptime_seconds": 3600.5
}
```

#### 2. Encode Endpoint

```http
POST /api/v1/encode
Content-Type: multipart/form-data

audio_file: <binary audio data>
message: "Author: John Doe"
message_length: (optional) 16
```

**Response** (200 OK):
```json
{
  "success": true,
  "file_id": "enc_abc123def456",
  "message": "Author: John Doe",
  "embedding_strength": 0.05,
  "processing_time_ms": 245,
  "original_duration": 10.0,
  "sample_rate": 44100,
  "message_length": 16
}
```

**Error Response** (422 Unprocessable Entity):
```json
{
  "detail": [
    {
      "loc": ["body", "message"],
      "msg": "ensure this value has at most 255 characters",
      "type": "value_error.string.max_length"
    }
  ]
}
```

#### 3. Verify Endpoint (Binary Detection)

```http
POST /api/v1/verify
Content-Type: application/json

{
  "file_id": "enc_abc123def456",
  "expected_message": (optional) "Author: John Doe",
  "confidence_threshold": 0.95
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "watermark_detected": true,
  "confidence": 0.985,
  "processing_time_ms": 125
}
```

**Key Feature**: `expected_message` is optional, enabling binary detection without knowing the original message.

#### 4. Decode Endpoint (Message Recovery)

```http
POST /api/v1/decode
Content-Type: application/json

{
  "file_id": "enc_abc123def456",
  "use_cnn": false,
  "confidence_threshold": 0.5,
  "max_message_length": 32
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Author: John Doe",
  "confidence": 0.985,
  "method": "classical",
  "snr_db": 2.45,
  "processing_time_ms": 245
}
```

#### 5. Analyze Endpoint

```http
POST /api/v1/analyze
Content-Type: application/json

{
  "file_id": "enc_abc123def456"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "watermark_present": true,
  "signal_strength": 0.92,
  "spectral_info": {
    "peak_frequency": 2400,
    "bandwidth": 1200,
    "snr_estimate": 2.45
  },
  "processing_time_ms": 185
}
```

#### 6. Download Endpoint

```http
GET /api/v1/download/{file_id}
```

**Response** (200 OK): Binary WAV audio file
**Response** (404 Not Found): File expired or doesn't exist

### Using cURL

**Encode example**:
```bash
curl -X POST \
  -F "audio_file=@input.wav" \
  -F "message=Copyright 2024" \
  http://localhost:5000/api/v1/encode
```

**Verify example**:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"file_id": "enc_abc123def456"}' \
  http://localhost:5000/api/v1/verify
```

**Decode example**:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"file_id": "enc_abc123def456", "use_cnn": false}' \
  http://localhost:5000/api/v1/decode
```

---

## Running Tests

### Complete Test Suite

```bash
# Run all tests
python -m pytest tests/ -v

# Run specific test file
python -m pytest tests/test_encoder.py -v

# Run specific test
python -m pytest tests/test_encoder.py::TestAudioGuardEncoder::test_encode_valid_audio -v

# Run with coverage
python -m pytest tests/ --cov=engine --cov=api
```

### Test Structure

```
tests/
├── test_encoder.py      (15 tests) - Watermark embedding
├── test_decoder.py      (12 tests) - Message extraction
├── test_api.py          (22 tests) - REST endpoints
├── test_utils.py        (8 tests)  - Signal processing
├── test_ecc.py          (3 tests)  - Error correction
└── test_sync.py         (2 tests)  - Sync headers
```

### Key Tests to Review

**Test Embedding Quality** (`test_encoder.py`):
```python
def test_encode_preserves_audio_quality(self):
    """Verify watermark is imperceptible"""
    # Original audio
    original_audio = self.encoder.encode(...)
    
    # Watermarked audio
    watermarked_audio = self.encoder.encode(..., message="test")
    
    # Compare: PESQ (Perceptual Evaluation of Speech Quality)
    # Original PESQ ≈ 4.0 (identical)
    # Watermarked PESQ > 3.8 (imperceptible)
```

**Test Message Recovery** (`test_decoder.py`):
```python
def test_decode_correct_message(self):
    """Verify message extraction accuracy"""
    message = "AudioGuard Test"
    
    # Encode
    encoded = self.encoder.encode(audio, message=message)
    
    # Decode
    decoded = self.decoder.decode(encoded_audio, len(message))
    
    # Verify
    assert decoded['message'] == message
    assert decoded['confidence'] > 0.95
```

**Test API Endpoints** (`test_api.py`):
```python
def test_encode_decode_roundtrip(self):
    """End-to-end API workflow"""
    # 1. Upload and encode
    response = client.post(
        "/api/v1/encode",
        files={"audio_file": open("test.wav", "rb")},
        data={"message": "Test"}
    )
    file_id = response.json()["file_id"]
    
    # 2. Verify
    response = client.post("/api/v1/verify", json={"file_id": file_id})
    assert response.json()["watermark_detected"] == True
    
    # 3. Decode
    response = client.post("/api/v1/decode", json={"file_id": file_id})
    assert response.json()["message"] == "Test"
```

---

## Key Implementation Details

### 1. STFT for Fourier Analysis

**Why STFT instead of regular FFT?**
- Audio is non-stationary (frequency content changes over time)
- STFT preserves temporal information while analyzing frequency
- Window function (Hanning) reduces spectral leakage

**Location**: `engine/utils.py:stft()`

```python
# Frame size 2048 = 2048/44100 ≈ 46ms windows
# Hop length 1024 = 50% overlap
# Results in 1025 frequency bins per frame
```

### 2. Bit-Spreading for Robustness

**Why spread bits across bins?**
- Single bin modification is fragile (compression, noise)
- Multiple bins provide redundancy
- Deterministic spreading (seeded) ensures reproducibility

**Algorithm** (`engine/encoder.py:_spread_bits_across_bins()`):
```python
# For each bit in message:
#   1. Deterministically select 4 frequency bins (based on seed)
#   2. Modify magnitude in those bins across all frames
#   3. Direction (increase/decrease) encodes bit value
```

### 3. Energy-Adaptive Modulation

**Why adaptive amplitude?**
- Human ear tolerates larger changes in loud frequencies
- Watermark imperceptibility requires frequency-aware adaptation
- Keeps watermark inaudible across all audio types

**Formula**:
```
modulation = amplitude_factor × normalized_bin_energy
normalized_energy = (bin_energy - min) / (max - min) × 0.5 + 0.5
```

### 4. Message Length Scanning (Decoder)

**Why scan multiple lengths?**
- Decoder doesn't know original message length
- Try lengths 1-32, score each attempt
- Return highest-confidence result

**Location** (`engine/decoder.py:decode()`):
```python
best_message = ""
best_confidence = 0

for length in range(1, max_length + 1):
    message = extract_bits_and_decode(audio, length)
    confidence = compute_confidence(message)
    
    if confidence > best_confidence:
        best_confidence = confidence
        best_message = message

return best_message, best_confidence
```

### 5. Confidence Scoring

**Ratio-Based Detection** (`engine/decoder.py:_estimate_bit_energy()`):
```python
# For watermarked audio vs. original:
# ratio > 1.0 → bit value 1
# ratio < 1.0 → bit value 0
# confidence = abs(ratio - 1.0)  # 0-1 scale

# Example:
# ratio = 1.05 → bit=1, confidence=0.05 (weak)
# ratio = 1.50 → bit=1, confidence=0.50 (strong)
```

### 6. Phase 1 Additions

**Reed-Solomon Error Correction** (`engine/ecc.py`):
- 16 ECC symbols for error correction
- Recovers corrupted bits up to 8 errors
- Location: `engine/ecc.py:encode()`, `decode()`

**Barker Sync Headers** (`engine/sync.py`):
- Frame synchronization headers
- Aids in decoder frame alignment
- Location: `engine/sync.py:add_sync_header()`, `find_sync()`

---

## Advanced Configuration

### Watermark Strength Tuning

```python
# Imperceptible (PESQ > 3.8)
amplitude_factor = 0.01  # Very subtle, lower accuracy
amplitude_factor = 0.05  # Default, good balance

# Perceptible (PESQ < 3.8)
amplitude_factor = 0.10  # Noticeable, high accuracy
amplitude_factor = 0.50  # Very obvious, maximum robustness
```

### STFT Window Sizes

```python
# Small window (512)
# Pro: Better temporal resolution
# Con: Poor frequency resolution

# Medium window (2048) ← DEFAULT
# Pro: Good balance
# Con: None

# Large window (4096)
# Pro: Excellent frequency resolution
# Con: Poor temporal resolution
```

### Frequency Bin Selection

The algorithm avoids:
- **0-500 Hz**: Rumble, inaudible background
- **3000-4000 Hz**: Speech formants, perceptible
- **8000+ Hz**: Requires high sample rate, compression artifacts

**Safe range**: 500-3000 Hz (algorithm default)

### Message Encoding

Current limitation: 255 character maximum
```python
# Message to bits: 1 char = 8 bits
# "A" → 01000001

# Total watermark size = message_length × 8 bits
# Each bit spread across 4 frequency bins (default)
# Total modified bins = message_length × 32
```

---

## Troubleshooting

### Issue: Watermark Not Detected

**Cause 1**: Audio compression (MP3, AAC)
```
Solution: Use WAV or FLAC formats
```

**Cause 2**: Amplitude factor too low
```
Solution: Increase from 0.05 to 0.10
Current: python cli.py encode -i test.wav -o out.wav -m "test" -a 0.05
New:     python cli.py encode -i test.wav -o out.wav -m "test" -a 0.10
```

**Cause 3**: Audio too short
```
Solution: Use audio ≥ 2 seconds
Reason: More frames → more robust watermark
```

### Issue: Inaudible Watermark Becomes Audible

**Cause**: Amplitude factor too high
```
Solution: Reduce from 0.10 to 0.05
```

### Issue: Memory Error on Large Files

**Cause**: Large STFT matrix in memory
```
Solution: Process in chunks or increase frame size
Current: --frame-size 2048
Larger:  --frame-size 4096  (fewer frames)
```

---

## Performance Benchmarks

Tested on: 2-second stereo audio @ 44.1kHz

| Operation | Time | Memory |
|-----------|------|--------|
| Encoding | 70ms | 45MB |
| Verification | 48ms | 40MB |
| Decoding | 120ms | 50MB |
| API Encode | 245ms | 120MB |
| API Verify | 185ms | 100MB |
| API Decode | 400ms | 130MB |

---

## References & Further Reading

### Signal Processing Theory
- **STFT**: Short-Time Fourier Transform (Gabor transform)
- **Windows**: Hanning vs. Hamming vs. Blackman
- **Overlap-Add**: Perfect reconstruction with 50% overlap

### Audio Watermarking Papers
- Cox et al. (1997): "Secure Spread Spectrum Watermarking"
- Boney et al. (1996): "Robust Audio Watermarking"

### Implementation Resources
- SciPy signal processing: https://docs.scipy.org/doc/scipy/reference/signal.html
- NumPy FFT: https://numpy.org/doc/stable/reference/fft.html
- Librosa audio analysis: https://librosa.org/

---

## Support & Feedback

For questions or issues:
1. Check this README's Troubleshooting section
2. Run `python cli.py --help` for command help
3. Review test files for usage examples
4. Check API server logs: `tail -f /tmp/backend.log`
