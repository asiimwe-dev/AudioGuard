# AudioGuard 🛡️

### **Fourier-Based Acoustic Steganography & AI Attribution**

[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Mobile](https://img.shields.io/badge/Platform-Android%20|%20iOS-green.svg)]()
[![Engine: Fourier Analysis](https://img.shields.io/badge/Engine-STFT-orange.svg)]()

**AudioGuard** is a high-fidelity digital watermarking suite designed to protect audio integrity in the age of generative AI. By leveraging **Short-Time Fourier Transforms (STFT)** and **Psychoacoustic Masking**, AudioGuard embeds invisible, robust digital signatures directly into the spectral domain of audio files.

---

## Project Vision

In a landscape flooded with deepfakes and AI-generated content, the ability to verify audio authenticity is critical. AudioGuard solves the "Attribution Problem" by weaving a cryptographic identity into the audio signal itself, rather than relying on easily strippable metadata.

### **Why AudioGuard?**
* **Inaudible:** Uses human auditory masking to ensure 0% impact on listening quality.
* **Tamper-Resistant:** Survives common "attacks" such as MP3 compression, resampling, and noise addition.
* **Mobile-First:** Designed for on-the-go verification and signing of voice memos, tracks, and evidence.

---

## Core Technical Mechanism

AudioGuard operates in the **Frequency Domain**. Instead of modifying the raw amplitude of the sound, it decomposes the audio into its constituent frequencies using the **Fourier Transform**.

### **The Signal Processing Pipeline**
1.  **Framing & Windowing:** The audio signal is divided into overlapping frames to maintain temporal resolution.
2.  **STFT (Short-Time Fourier Transform):** Each frame is converted into a frequency spectrum.
    $$X(k) = \sum_{n=0}^{N-1} x(n) \cdot e^{-j\frac{2\pi}{N}kn}$$
3.  **Spectral Magnitude Modulation:** A unique binary signature is embedded by subtly manipulating the magnitudes of specific frequency bins within the "Psychoacoustic Masking Threshold."
4.  **Inverse FFT:** The modified spectrum is converted back into a time-domain wave, creating the watermarked file.

---

## Mobile Application Architecture

The mobile application serves as the interface for **Signing** and **Verifying** audio.

* **Audio Capture:** Record or import audio directly on the device.
* **Local Processing:** Lightweight Fourier Analysis performed on-device for real-time verification.
* **Cloud Verification (Optional):** Integration with a Python-based backend for deep-learning-enhanced watermark extraction from highly degraded files.

---

## Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Core Engine** | Python 3.11 (NumPy, Librosa, SciPy) |
| **Mobile Framework** | Flutter (Cross-platform) |
| **Edge Math** | Numba (JIT Compilation for high-speed FFT) |
| **Robustness AI** | PyTorch (CNN-based watermark extraction) |
| **Containerization** | Docker (Environment isolation for the backend) |
| **Development OS** | Fedora Linux (Primary workstation) |

---

## Development Roadmap

- [x] **Phase 1: Spectral Engine:** Develop the core Python library for FFT-based embedding and extraction.
- [x] **Phase 2: Psychoacoustic Model:** Implement masking curves to ensure watermark inaudibility.
- [x] **Phase 3: Robustness Layer:** Train a CNN to detect watermarks in low-bitrate MP3s and noisy environments.
- [x] **Phase 4: Mobile Integration:** Build the Flutter/React Native UI and integrate the Python engine via a REST API or TFLite.
- [ ] **Phase 5: Public Release:** Documentation and API access for independent creators.

---

## Local Setup & Installation

To set up the development environment on a Linux-based system (optimized for Fedora):

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/asiimwe-dev/audioguard.git](https://github.com/asiimwe-dev/audioguard.git)
   cd audioguard
2. **Setup a Virtual Environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate
3. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
4. **Run the core Engine (Example):**
   ```bash
   python engine/encoder.py --input sample.wav --message "AUTHOR_ID_001"
---

## Contribution

Contributions are welcome! If you are interested in signal processing, mobile development, or AI ethics, feel free to fork the repo and submit a PR.

## Author

**ASIIMWE GILBERT** Aspiring AI Full-Stack & Systems Engineer. Github:[https://github.com/asiimwe-dev](https://github.com/asiimwe-dev) 

## License

This project is licensed under the MIT License - see the [[License: MIT](https://github.com/asiimwe-dev/AudioGuard/blob/main/LICENSE)] file for details.
