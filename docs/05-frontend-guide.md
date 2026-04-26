# Frontend Guide

The AudioGuard mobile application is built with Flutter and provides a cross-platform interface for audio watermarking. It supports Android and iOS, featuring both local processing and cloud-based verification.

## Table of Contents
1. [Project Structure](#project-structure)
2. [Core Services](#core-services)
3. [State Management](#state-management)
4. [UI Screens](#ui-screens)
5. [Build and Deployment](#build-and-deployment)
6. [Security and Performance](#security-and-performance)

## Project Structure

The project follows a modular service-based architecture:

```text
lib/
├── main.dart               # Entry point and app initialization
├── models/                 # Data models for watermarking results
├── providers/              # Riverpod state management providers
├── screens/                # UI screens (Home, Encode, Decode, etc.)
├── services/               # Core business logic (API, Audio, Storage)
├── theme/                  # App theming and styling
├── utils/                  # Helper functions and constants
└── widgets/                # Reusable UI components
```

## Core Services

### ApiService
Handles all REST API communication. It uses `Dio` and `Retrofit` for robust HTTP requests, including multipart file uploads for encoding.

### AudioService
Manages audio recording and file system operations. It handles file picking, format validation (WAV, MP3, FLAC, OGG), and metadata extraction.

### LocalService
Provides on-device watermark processing using TensorFlow Lite (`tflite_flutter`). This allows for fast, offline verification of watermarks without cloud latency.

### StorageService
Manages persistent storage using `Hive` (for structured data) and `FlutterSecureStorage` (for sensitive credentials).

## State Management

AudioGuard uses **Riverpod** for reactive state management.
*   **Encoding/Decoding State**: Managed via `StateNotifierProviders` to handle complex asynchronous workflows and error states.
*   **UI State**: Manages theme preferences, operation history, and navigation state.

## UI Screens

*   **Home Dashboard**: Displays operation statistics and quick access to all features.
*   **Encode**: Interface for selecting audio files and embedding messages (1-255 characters).
*   **Decode**: Extracts messages from watermarked audio with confidence scoring.
*   **Verify**: Fast check for watermark presence.
*   **Analyze**: Provides spectral visualization and detailed audio properties.
*   **Settings**: Configure API endpoints and application preferences.

## Build and Deployment

### Development
```bash
flutter pub get
flutter run
```

### Production Build (Android)
The build process includes ProGuard R8 obfuscation and asset optimization (tree-shaking).
```bash
flutter build apk --release
```
**Artifact**: `build/app/outputs/flutter-apk/app-release.apk` (~71MB)

### Production Build (iOS)
Requires macOS and Xcode.
```bash
flutter build ios --release
```

## Security and Performance

### Security
*   **Obfuscation**: R8 ProGuard rules protect the core logic and TFLite GPU delegates.
*   **Secure Storage**: Sensitive data is encrypted at rest.
*   **Input Validation**: Strict validation for message lengths and audio formats.

### Performance Targets
*   **Startup Time**: < 3 seconds.
*   **Memory Usage**: ~150-200MB runtime.
*   **Processing Time**: < 5s for 1-minute audio (cloud); < 500ms (local).

---
[Return to Documentation Index](README.md)
