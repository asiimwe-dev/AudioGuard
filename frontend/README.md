# AudioGuard Frontend

Flutter-based mobile application for audio watermarking. Encode, verify, and analyze watermarks on iOS and Android.

## Table of Contents

1. [Overview](#overview)
2. [Setup & Installation](#setup--installation)
3. [Architecture](#architecture)
4. [Configuration](#configuration)
5. [Building & Deployment](#building--deployment)
6. [Known Limitations](#known-limitations)
7. [Troubleshooting](#troubleshooting)

## Overview

AudioGuard provides an intuitive mobile interface to:

- **Encode:** Watermark audio files with invisible signatures
- **Verify:** Check if audio contains a watermark
- **Analyse:** View spectral characteristics and watermark status
- **Download:** Save watermarked audio to device storage

### Key Features

✅ **Cross-Platform:** iOS and Android (Flutter)  
✅ **Intuitive UI:** Tab-based navigation for encode/verify/analyse  
✅ **File Handling:** Native file picker + persistent storage  
✅ **Permission Management:** Audio/file system permissions (iOS + Android)  
✅ **Offline Support:** All DSP runs locally (backend connectivity required for API)  
✅ **Auto-Download:** Watermarked files auto-saved post-encoding  

⚠️ **Backend Dependency:** Requires running FastAPI backend  
⚠️ **Classical Decode:** Message recovery accuracy is limited (Phase 2 improvement)

## Setup & Installation

### Requirements

- Flutter 3.10+ with Dart 3.0+
- iOS deployment target: 12.0+
- Android: minSdkVersion 21+
- Xcode 13+ (macOS) or Android Studio
- Backend running at `http://localhost:8000` (or Render.com in production)

### Install Flutter Dependencies

```bash
cd frontend
flutter pub get
```

This installs all Dart/Flutter packages, including:
- `http` — HTTP client
- `file_picker` — File selection on iOS/Android
- `path_provider` — App document storage
- `permission_handler` — Android/iOS permissions

### Install for Development

```bash
flutter pub get
# Optionally, generate code for any models/services
flutter pub run build_runner build --delete-conflicting-outputs
```

## Architecture

### Directory Structure

```
frontend/
├── lib/
│   ├── main.dart                 # App entry point + theme
│   ├── screens/
│   │   ├── encode_screen.dart    # Watermark embedding UI
│   │   ├── verify_screen.dart    # Binary detection UI
│   │   ├── analyse_screen.dart   # Spectral analysis UI
│   │   └── home_screen.dart      # Main navigation
│   ├── services/
│   │   ├── api_service.dart      # HTTP client (core)
│   │   └── audio_service.dart    # Local file operations
│   ├── widgets/
│   │   ├── audio_player.dart     # Playback UI
│   │   ├── result_display.dart   # Results formatting
│   │   └── error_handler.dart    # Error dialogs
│   ├── models/
│   │   ├── watermark.dart        # Data classes
│   │   └── api_models.dart       # API request/response
│   └── utils/
│       ├── constants.dart        # API endpoints, UI strings
│       ├── permissions.dart      # Permission helpers
│       └── formatters.dart       # Time/size formatting
├── pubspec.yaml                  # Dependencies + metadata
├── ios/                          # Xcode project (iOS)
├── android/                      # Gradle project (Android)
└── README.md                     # This file
```

### API Client (`api_service.dart`)

**Core Methods:**

```dart
// Encode (watermark audio)
Future<EncodeResponse> encode(File audioFile, String message, {double amplitudeFactor = 0.05})

// Verify (detect watermark)
Future<VerifyResponse> verify(File audioFile)

// Analyse (full spectral info)
Future<AnalyseResponse> analyse(File audioFile)

// Download (retrieve watermarked file)
Future<File> download(String fileId)
```

**Key Features:**

- **Request Timeout:** 60 seconds (configurable)
- **File Streaming:** Large files streamed (not held in memory)
- **Error Handling:** Exceptions wrapped in custom error types
- **TLS Handling:**
  - Development: Accepts unverified certs for `localhost`, `127.0.0.1`, `10.0.2.2`, `*.local`
  - Production: Enforces valid certificates signed by trusted CA
- **Auto-Download:** Post-encode, watermarked file automatically saved to device

### Screens & Navigation

#### 1. Home Screen (TabBar Navigation)

Three main tabs:
- **Encode:** Input audio + message, embed watermark
- **Verify:** Quick watermark detection
- **Analyse:** Detailed spectral + watermark status

#### 2. Encode Screen

**Workflow:**
1. Tap "Select Audio" → File picker
2. Enter message (1-255 chars)
3. Tap "Encode" → Submit to backend
4. Wait for response
5. Auto-download watermarked file

**Response Display:**
- File ID (for later decode/verify)
- Original duration & sample rate
- Processing time
- Download link (file saved to `/data/user/0/com.audioguard.app/app_flutter/`)

#### 3. Verify Screen

**Workflow:**
1. Select audio file
2. Tap "Verify" → Backend detection
3. Display verdict + confidence

**Output:**
- `watermark_detected: true/false`
- `confidence: 0.0–1.0`
- Processing time

#### 4. Analyse Screen

**Workflow:**
1. Select audio file
2. Tap "Analyse" → Full spectral report
3. Display audio metadata + watermark status

**Output:**
- Duration, sample rate
- RMS, peak amplitude, dynamic range
- Watermark presence (detected/not_detected)
- SNR (signal-to-noise ratio)
- Signal strength

### File Storage

**App Documents Directory:**
- iOS: `/var/mobile/Containers/Data/Application/{UUID}/Documents/audioguard/`
- Android: `/data/data/com.audioguard.app/app_flutter/`

**Access:**
```dart
import 'package:path_provider/path_provider.dart';

final directory = await getApplicationDocumentsDirectory();
final audioFile = File('${directory.path}/watermarked_audio.wav');
```

**Persistence:** Files survive app restarts and background termination.

### Permission Model

#### Android

**Permissions in `AndroidManifest.xml`:**
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

**Runtime Permissions (Android 6+):**
```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestStoragePermission() async {
  final status = await Permission.storage.request();
  return status.isGranted;
}
```

#### iOS

**Permissions in `ios/Runner/Info.plist`:**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>AudioGuard needs microphone access to record audio.</string>
<key>NSDocumentsFolderAccessDescription</key>
<string>AudioGuard needs access to your documents folder.</string>
```

**Runtime Permissions:**
```dart
Future<bool> requestMicrophonePermission() async {
  final status = await Permission.microphone.request();
  return status.isGranted;
}
```

**Note:** If permissions are denied, the app shows a native settings prompt via `openAppSettings()`.

## Configuration

### API Endpoint

Edit `lib/utils/constants.dart`:

```dart
const String API_BASE_URL = 'http://localhost:8000';  // Development
// const String API_BASE_URL = 'https://audioguard-api.onrender.com';  // Production
```

### HTTP Client Customization

In `lib/services/api_service.dart`:

```dart
// Timeout (default: 60 seconds)
const Duration HTTP_TIMEOUT = Duration(seconds: 120);

// TLS Certificate Verification
// Development: Custom handler allows self-signed certs for localhost, *.local
// Production: Enforce standard certificate validation
```

### Request Retry Logic

The client includes basic retry:
- 1 retry on network timeout
- Exponential backoff (e.g., 1s, 2s)
- Max 3 total attempts

## Building & Deployment

### Development Build

#### iOS

```bash
cd frontend
flutter pub get
flutter build ios --debug --simulator
# Or launch on connected device:
flutter run -d <device_id>
```

#### Android

```bash
cd frontend
flutter pub get
flutter build apk --debug
# Or launch on emulator:
flutter run -d emulator-5554
```

### Release Build

#### iOS (App Store)

1. Update version in `pubspec.yaml` and `ios/Runner/Info.plist`
2. Create provisioning profile in Apple Developer

```bash
flutter build ios --release --no-codesign
# Then use Xcode to sign and submit to App Store
```

#### Android (Google Play)

1. Generate keystore:
```bash
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias audioguard_key
```

2. Build signed APK:
```bash
flutter build apk --release \
  --dart-define-from-file=android/key.properties
```

3. Upload to Google Play Console

### CI/CD Pipeline

GitHub Actions workflow in `.github/workflows/ci.yml`:

```yaml
- name: Run Flutter Analyze
  run: cd frontend && flutter analyze --no-fatal-infos
```

Additional checks (can be added):
- Unit tests: `flutter test`
- Integration tests: `flutter drive`
- Code coverage: `lcov` + `codecov`

## API Integration Examples

### Encode with Progress Tracking

```dart
Future<void> encodeWithProgress(File audioFile, String message) async {
  try {
    final response = await _apiService.encode(
      audioFile,
      message,
      amplitudeFactor: 0.05,
    );

    print('Watermarked file ID: ${response.fileId}');
    print('Processing time: ${response.processingTimeMs}ms');

    // Auto-download happens in the service layer
    final downloadedFile = await _audioService.getFile(response.fileId);
    print('Saved to: ${downloadedFile.path}');
  } catch (e) {
    print('Encode failed: $e');
  }
}
```

### Batch Verify Multiple Files

```dart
Future<void> verifyMultiple(List<File> files) async {
  for (final file in files) {
    try {
      final response = await _apiService.verify(file);
      print('${file.path}: ${response.watermarkDetected}');
    } catch (e) {
      print('Verify failed for ${file.path}: $e');
    }
  }
}
```

## Known Limitations

### 1. Classical Decoder

Message recovery accuracy is ~50% (chance level), similar to the backend. The frontend correctly displays low `confidence` for decode operations. **Phase 2** will improve this with CNN-based extraction.

### 2. File Size Limits

- Max file size: 100 MB (enforced by backend)
- Max duration: 60 minutes (enforced by backend)

Larger files will be rejected by the backend with an HTTP 422 error.

### 3. Android 11+ Scoped Storage

Android 11+ enforces scoped storage, limiting direct file access. The app uses `path_provider` to access app-local documents directory (safe) but cannot directly access arbitrary user files via the file picker without additional permissions.

**Workaround:** Users must grant permissions explicitly via the system file picker; the app cannot bypass this.

### 4. iOS 16+ Privacy Manifest

iOS 16+ requires a privacy manifest (`PrivacyInfo.xcprivacy`) if using certain APIs. The app already includes basic permissions in `Info.plist`; ensure the manifest is in place for App Store submission.

### 5. Cold Start Latency

First request to the backend may experience 2-5 second latency (Render.com dyno cold start). Subsequent requests are fast.

### 6. No Local Offline Encode

All watermarking is done on the backend. The frontend is a UI client only. To enable local DSP, port the Python backend to Dart (not planned for Phase 1).

## Troubleshooting

### "Connection Refused" Error

**Cause:** Backend is not running or not reachable at the configured URL.

**Solution:**
1. Start backend: `cd backend && python -m uvicorn api.main:app --reload`
2. Verify URL in `lib/utils/constants.dart`
3. For emulator/simulator: Use `10.0.2.2` (Android) or `localhost` (iOS simulator) for local backend

### "Certificate Validation Failed"

**Cause:** TLS certificate is invalid or self-signed (development).

**Solution:**
- Development: Already handled by custom TLS handler for `localhost`, `127.0.0.1`, `10.0.2.2`, `*.local`
- Production: Use a valid certificate (Let's Encrypt, etc.)

### "Permission Denied" on File Picker

**Cause:** App lacks storage permissions.

**Solution:**
1. On Android: Grant "Files" or "Photos" permission
2. On iOS: Grant "Documents" or "Photos" permission
3. If denied permanently, direct user to Settings via `openAppSettings()`

### File Not Saved After Encode

**Cause:** Download failed or file path not writable.

**Solution:**
1. Check logcat (Android) or Xcode console (iOS) for errors
2. Verify app has write permission to documents directory
3. Check available disk space

### UI Freezes During Upload

**Cause:** Large file upload blocks the main thread.

**Solution:**
1. File streaming is automatic; ensure backend is responsive
2. For files >50 MB, use background isolate (not currently implemented; future optimization)

---

**For full API documentation, see [`../docs/03-api-reference.md`](../docs/03-api-reference.md).**

**For backend setup, see [`../backend/README.md`](../backend/README.md).**
