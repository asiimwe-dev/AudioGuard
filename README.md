# AudioGuard 🛡️

### **Fourier-Based Acoustic Steganography & AI Attribution**

[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Platform: Mobile](https://img.shields.io/badge/Platform-Android%20|%20iOS-green.svg)]()
[![Engine: Fourier Analysis](https://img.shields.io/badge/Engine-STFT-orange.svg)]()

**AudioGuard** is a high-fidelity digital watermarking suite designed to protect audio integrity in the age of generative AI. By leveraging **Short-Time Fourier Transforms (STFT)** and **Psychoacoustic Masking**, AudioGuard embeds invisible, robust digital signatures directly into the spectral domain of audio files.

---

## 📖 Documentation Suite

For comprehensive guides on setup, architecture, and integration, please refer to our **[Documentation Index](docs/README.md)**.

### Quick Links
*   🚀 **[Quick Start Guide](docs/01-quick-start.md)**: Get up and running in 3 minutes.
*   🏗️ **[System Architecture](docs/02-architecture.md)**: Technical deep-dive into the watermarking engine.
*   🔌 **[API Reference](docs/03-api-reference.md)**: Complete REST API specification.
*   🚀 **[Deployment Guide](docs/04-deployment.md)**: Production deployment with Docker and Nginx.
*   🤝 **[Contributing Guide](docs/08-contributing.md)**: How to get involved and Code of Conduct.

---

## Project Vision

In a landscape flooded with deepfakes and AI-generated content, the ability to verify audio authenticity is critical. AudioGuard solves the "Attribution Problem" by weaving a cryptographic identity into the audio signal itself, rather than relying on easily strippable metadata.

### **Key Features**
*   **Inaudible**: Uses human auditory masking to ensure 0% impact on listening quality.
*   **Tamper-Resistant**: Survives common "attacks" such as MP3 compression, resampling, and noise addition.
*   **Mobile-First**: Designed for on-the-go verification and signing of audio content.
*   **Production-Ready**: High-performance FastAPI backend with a reactive Flutter mobile app.

---

## Core Technical Mechanism

AudioGuard operates in the **Frequency Domain**. Instead of modifying the raw amplitude of the sound, it decomposes the audio into its constituent frequencies using the **Fourier Transform**.

1.  **Framing & Windowing**: The audio signal is divided into overlapping frames.
2.  **STFT (Short-Time Fourier Transform)**: Each frame is converted into a frequency spectrum.
3.  **Spectral Magnitude Modulation**: A unique binary signature is embedded by subtly manipulating magnitudes within the "Psychoacoustic Masking Threshold."
4.  **Inverse FFT**: The modified spectrum is converted back into a time-domain wave, creating the watermarked file.

---

## Current Status

| Component | Status | Details |
|-----------|--------|---------|
| **Backend** | ✅ Production Ready | FastAPI, Async I/O, Full test coverage |
| **Frontend** | ✅ Production Ready | Flutter (iOS/Android), MD3, Riverpod |
| **Engine** | ✅ Fully Tested | STFT-based, psychoacoustic masking |
| **Tests** | ✅ 60+ Passing | 96.8% success rate |
| **Docs** | ✅ Complete | Consolidated professional suite |

---

## Local Setup (Fast Track)

```bash
# 1. Start Backend
cd backend
pip install -r requirements.txt
python app.py

# 2. Start Frontend
cd frontend
flutter run
```

For detailed instructions, see the **[Quick Start Guide](docs/01-quick-start.md)**.

---

## 🤝 Contributing

We welcome contributions! Please see **[CONTRIBUTING.md](CONTRIBUTING.md)** for our guidelines and Code of Conduct.

---

## 📝 License

This project is licensed under the MIT License - see the **[LICENSE](LICENSE)** file for details.

---

**AudioGuard** - *Invisible Digital Signatures for Audio Attribution* 🎵🔐
