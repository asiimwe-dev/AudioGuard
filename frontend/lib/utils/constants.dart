/// Application-wide constants for AudioGuard Mobile
class AppConstants {
  // API Configuration
  static const String defaultApiBaseUrl = 'http://10.10.11.153:8000'; // Physical device on local network
  static const String devApiBaseUrl = 'http://localhost:8000'; // Local development
  static const String emulatorApiBaseUrl = 'http://10.0.2.2:8000'; // Android emulator
  static const String stagingApiBaseUrl = 'https://staging-api.audioguard.io';// Staging server

  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration fileUploadTimeout = Duration(minutes: 5);

  // API Endpoints
  static const String healthEndpoint = '/health';
  static const String encodeEndpoint = '/api/v1/encode';
  static const String decodeEndpoint = '/api/v1/decode';
  static const String verifyEndpoint = '/api/v1/verify';
  static const String analyzeEndpoint = '/api/v1/analyze';

  // Audio Configuration
  static const List<String> supportedAudioFormats = [
    'wav',
    'mp3',
    'm4a',
    'ogg',
  ];
  static const int maxAudioFileSizeBytes = 104857600; // 100MB
  static const int minAudioFileSizeBytes = 10240; // 10KB

  // Watermark Configuration
  static const int minMessageLength = 1;
  static const int maxMessageLength = 256;
  static const int defaultBitsPerFrame = 4;
  static const double defaultAmplitudeFactor = 0.05;

  // TFLite Model
  static const String tfliteModelPath =
      'assets/models/watermark_detector.tflite';
  static const Duration tfliteLoadTimeout = Duration(seconds: 5);

  // Storage
  static const String storageKeyApiToken = 'api_token';
  static const String storageKeyApiBaseUrl = 'api_base_url';
  static const String storageKeyWatermarkMode = 'watermark_mode';
  static const String storageKeyAppTheme = 'app_theme';

  // UI
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration progressUpdateInterval = Duration(milliseconds: 100);

  // Error Messages
  static const String errorNoInternet =
      'No internet connection. Using local mode.';
  static const String errorInvalidAudioFile = 'Invalid audio file format.';
  static const String errorFileTooLarge = 'Audio file exceeds 100MB limit.';
  static const String errorFileTooSmall = 'Audio file is too small.';
  static const String errorMessageTooLong =
      'Message exceeds 256 character limit.';
  static const String errorApiUnreachable = 'API server is unreachable.';
  static const String errorTfliteModelNotLoaded =
      'TFLite model failed to load.';
  static const String errorUnknown = 'An unexpected error occurred.';

  // Success Messages
  static const String successEncodingComplete =
      'Watermark embedded successfully.';
  static const String successDecodingComplete =
      'Watermark extracted successfully.';
  static const String successVerificationPassed =
      'Watermark verification passed.';
  static const String successAnalysisComplete = 'Audio analysis complete.';
}

/// Watermark processing modes
enum WatermarkMode {
  local('Local Processing'),
  cloud('Cloud Processing'),
  hybrid('Hybrid (Intelligent Fallback)');

  final String label;
  const WatermarkMode(this.label);

  static WatermarkMode fromString(String value) {
    return WatermarkMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => WatermarkMode.hybrid,
    );
  }
}

/// Processing status states
enum ProcessingStatus { idle, loading, processing, success, error }
