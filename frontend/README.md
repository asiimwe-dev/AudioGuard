# AudioGuard Mobile - Flutter Frontend

Production-ready Flutter application for iOS and Android watermarking with embedded TensorFlow Lite model and cloud fallback support.

## Project Structure

```
lib/
├── main.dart                 # App entry point with SplashScreen
├── models/
│   └── watermark_model.dart # Data classes (EncodingResult, DecodingResult, etc.)
├── services/
│   ├── api_service.dart     # REST API client (Dio)
│   ├── audio_service.dart   # Audio file I/O and validation
│   ├── local_service.dart   # TFLite model loading and inference
│   └── storage_service.dart # Secure credential storage
├── providers/
│   ├── watermark_provider.dart # Riverpod state for encode/decode/verify/analyze
│   └── ui_provider.dart        # UI state (history, stats, navigation)
├── screens/
│   ├── home_screen.dart     # Dashboard with mode selector and stats
│   ├── encode_screen.dart   # Add watermark UI
│   ├── decode_screen.dart   # Extract watermark UI
│   ├── verify_screen.dart   # Verify watermark UI
│   └── analyze_screen.dart  # Audio analysis UI
├── theme/
│   └── app_theme.dart       # Material Design 3 theming
└── utils/
    ├── constants.dart       # API endpoints, modes, limits
    ├── logger.dart          # Structured logging
    └── permissions.dart     # Permission handling
```

## Features Implemented

### ✅ Phase 5.1: Project Setup
- Flutter 3.41.7, Dart 3.11.5
- 28+ dependencies installed
- Material Design 3 theme with light/dark mode

### ✅ Phase 5.2: Core Services
- **ApiService**: REST client for cloud watermarking
- **AudioService**: File picker, metadata extraction, validation
- **StorageService**: Secure storage with FlutterSecureStorage + Hive
- **LocalService**: TFLite inference engine

### ✅ Phase 5.3: State Management
- Riverpod 2.6.1 reactive state
- StateNotifiers for complex operations
- AsyncValue for async state handling

### ✅ Phase 5.4: UI Screens
- HomeScreen with dashboard and mode selector
- EncodeScreen for watermark embedding
- DecodeScreen for watermark extraction

### ✅ Phase 5.5: Platform Integration
- Android permissions configured
- iOS permissions (microphone, music library)
- Permission handler utility

## Building & Running

### Development
```bash
# Run on Android emulator
flutter run

# Run on iOS simulator
flutter run -d iPhone

# Release mode
flutter run --release
```

## Deployment

### iOS Build
```bash
# Release IPA
flutter build ios --release
```

### Android Build
```bash
# Release APK
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release
```

## Architecture

**Three Processing Modes:**
1. **Local**: Device-embedded TFLite model
2. **Cloud**: REST API for accuracy
3. **Hybrid**: Local with cloud fallback

**State Management:** Riverpod with StateNotifiers

**Services:** ApiService, LocalService, AudioService, StorageService

## Performance Targets

- Encoding: < 5s per 1-minute audio
- Decoding: < 3s per 1-minute audio
- TFLite cold start: < 2s
- App startup: < 2s
- Memory: < 150MB

## Security

- JWT tokens in FlutterSecureStorage
- Encrypted Hive preferences
- HTTPS-only API calls
- Input validation on all forms

## Support

- **Backend**: See `../api/README.md`
- **Architecture**: See Phase 5 documentation
