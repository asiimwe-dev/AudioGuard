# AudioGuard Implementation Deep-Dive

This document provides a low-level technical analysis of the AudioGuard watermarking engine, detailing the signal processing pipeline, bit extraction framework, and error correction integration.

---

## 1. Signal Processing Architecture

### Multi-Resolution STFT
AudioGuard implements a parallel Short-Time Fourier Transform (STFT) architecture. By analyzing the signal at multiple resolutions, the system achieves robustness against attacks that exploit specific time-frequency trade-offs.

| Resolution Layer | Window Size | Temporal Resolution | Spectral Resolution | primary Survival Target |
|------------------|-------------|---------------------|---------------------|-------------------------|
| **Res 1** | 1024 | 23ms | 43Hz | Time-stretching, resampling |
| **Res 2** | 2048 | 46ms | 21.5Hz | Baseline audio degradation |
| **Res 3** | 4096 | 93ms | 10.8Hz | Pitch-shifting, freq-warping |

### Inverse Transformation & Reconstruction
During encoding, the modulated magnitudes from all three resolutions are averaged to create a unified spectral representation. This averaging process acts as a smoothing filter, minimizing audible artifacts and maintaining transparency.

---

## 2. Advanced Bit Extraction

The extraction framework supports multiple strategies, allowing the system to adapt to different signal conditions.

### Adaptive Energy Thresholding (Standard)
This is the primary extraction method. It normalizes each STFT frame by its local spectral energy before applying a threshold. This makes the extraction invariant to volume changes and achieves a high extraction accuracy (~70% raw).

### Majority Voting
Extracted bits from the three parallel resolutions are passed through a voting gate:
*   **Logic**: A bit is recovered if $\geq 2$ resolutions agree.
*   **Confidence Scoring**: The system calculates a confidence metric per bit based on voting unanimity (1.0 for unanimous, 0.33 for weak majority).

---

## 3. Error Correction Framework

To achieve 100% payload recovery under high noise or compression (e.g., MP3 at 128kbps), AudioGuard integrates Reed-Solomon coding.

### Workflow
1.  **Redundancy Encoding**: The message is converted to bits and repeated 3x to create spatial redundancy across the spectral domain.
2.  **ECC Injection**: A Reed-Solomon block (255, 239) is applied, adding 16 parity symbols per block.
3.  **Spectral Modulation**: The protected bitstream is embedded into the multi-resolution magnitudes.
4.  **Recovery**: After majority voting, the Reed-Solomon decoder corrects up to 8 symbol errors per block, ensuring the final message is identical to the input.

---

## 4. Persistent Storage Management

The backend implements a persistent storage layer to track file lineage and embedding statistics.

### Schema
Each processed file is assigned a UUID and stored alongside a JSON metadata sidecar:
*   **Audio**: `{uuid}.wav`
*   **Metadata**: `{uuid}.json`
    *   `snr_db`: Signal-to-noise ratio of the embedding.
    *   `extraction_confidence`: Aggregated voting confidence.
    *   `embedding_time`: Latency of the spectral transformation.
    *   `message`: The embedded payload (stored for auditability).

---

## 5. Robustness Validation

The system is continuously validated against a suite of common audio attacks:
*   **Compression**: Survival against MP3 (128kbps, 64kbps) and AAC.
*   **Noise**: Survival against Gaussian white noise up to 10% intensity.
*   **Temporal**: Survival against ±5% time-stretching.
*   **Spectral**: Survival against ±2 semitones of pitch-shifting.

---
[Return to Documentation Index](README.md)
