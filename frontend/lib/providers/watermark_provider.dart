import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/watermark_model.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/local_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';

// ===== Service Providers =====

final storageServiceProvider = Provider((ref) {
  return StorageService();
});

final apiServiceProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  return ApiService(
    baseUrl: settings.apiBaseUrl,
    authToken: settings.authToken,
  );
});

final localServiceProvider = Provider((ref) {
  return LocalService();
});

final audioServiceProvider = Provider((ref) {
  return AudioService();
});

// ===== Audio State Providers =====

/// Selected audio file
final selectedAudioFileProvider = StateProvider<String?>((ref) => null);

/// Audio metadata for selected file
final audioMetadataProvider = FutureProvider<AudioMetadata?>((ref) async {
  final audioPath = ref.watch(selectedAudioFileProvider);
  final audioService = ref.watch(audioServiceProvider);
  
  if (audioPath == null) return null;
  
  return await audioService.getAudioMetadata(audioPath);
});

// ===== Watermark Mode Provider =====

/// Current watermarking mode (local/cloud/hybrid)
final watermarkModeProvider = StateProvider<WatermarkMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.defaultMode;
});

// ===== History State =====

class HistoryEntry {
  final String operationType;
  final String mode;
  final DateTime timestamp;
  final bool success;
  final double? confidence;

  HistoryEntry({
    required this.operationType,
    required this.mode,
    required this.timestamp,
    required this.success,
    this.confidence,
  });
}

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  HistoryNotifier() : super([]);

  void addEntry(HistoryEntry entry) {
    state = [entry, ...state];
  }

  void clear() {
    state = [];
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  return HistoryNotifier();
});

// ===== Stats State =====

class OperationStats {
  final int totalOperations;
  final double successRate;
  final double averageConfidence;

  OperationStats({
    this.totalOperations = 0,
    this.successRate = 0.0,
    this.averageConfidence = 0.0,
  });
}

final statsProvider = Provider<OperationStats>((ref) {
  final history = ref.watch(historyProvider);
  
  if (history.isEmpty) return OperationStats();
  
  final total = history.length;
  final successful = history.where((e) => e.success).length;
  final avgConf = history.map((e) => e.confidence ?? 0.0).fold(0.0, (a, b) => a + b) / total;
      
  return OperationStats(
    totalOperations: total,
    successRate: successful / total,
    averageConfidence: avgConf,
  );
});

// ===== Encoding State =====

class EncodingState {
  final AsyncValue<EncodingResult> result;
  final double progress; // 0.0 to 1.0
  final bool isProcessing;

  EncodingState({
    this.result = const AsyncValue.loading(),
    this.progress = 0.0,
    this.isProcessing = false,
  });

  EncodingState copyWith({
    AsyncValue<EncodingResult>? result,
    double? progress,
    bool? isProcessing,
  }) {
    return EncodingState(
      result: result ?? this.result,
      progress: progress ?? this.progress,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class EncodingNotifier extends StateNotifier<EncodingState> {
  final ApiService _apiService;
  final LocalService _localService;
  final Ref _ref;

  EncodingNotifier(this._apiService, this._localService, this._ref) : super(EncodingState());

  Future<void> encode({
    required String audioFilePath,
    required String message,
    required WatermarkMode mode,
  }) async {
    state = state.copyWith(isProcessing: true, progress: 0.1);

    try {
      EncodingResult result;

      if (mode == WatermarkMode.cloud || (mode == WatermarkMode.hybrid)) {
        // For cloud/hybrid, try cloud first
        try {
          result = await _apiService.encode(
            audioFilePath: audioFilePath,
            message: message,
          );
        } catch (e) {
          if (mode == WatermarkMode.hybrid) {
            // Fallback to local
            state = state.copyWith(progress: 0.5);
            throw ProcessingError(
              message: 'Cloud processing failed. Local fallback not yet available.',
              code: 'LOCAL_FALLBACK_UNAVAILABLE',
              originalError: e,
              details: 'Please ensure your device has internet connectivity or the backend server is reachable.',
            );
          } else {
            rethrow;
          }
        }
      } else {
        // Local mode
        throw ProcessingError(
          message: 'Local processing not yet available',
          code: 'LOCAL_PROCESSING_UNAVAILABLE',
          details: 'Local processing mode is currently in development. Please use Cloud mode instead.\n\n'
              'For Cloud mode to work, ensure your device:\n'
              '1. Has internet connectivity\n'
              '2. Can reach the AudioGuard backend server\n'
              '3. Is on the same network as the backend if using local IP',
        );
      }

      state = state.copyWith(
        result: AsyncValue.data(result),
        progress: 1.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'encode',
        mode: result.mode,
        timestamp: DateTime.now(),
        success: true,
        confidence: result.confidence,
      ));
    } catch (error, stackTrace) {
      state = state.copyWith(
        result: AsyncValue.error(error, stackTrace),
        isProcessing: false,
      );
      
      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'encode',
        mode: mode.name,
        timestamp: DateTime.now(),
        success: false,
      ));
    }
  }

  void reset() {
    state = EncodingState();
  }
}

final encodingProvider =
    StateNotifierProvider<EncodingNotifier, EncodingState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final local = ref.watch(localServiceProvider);
  return EncodingNotifier(api, local, ref);
});

// ===== Decoding State =====

class DecodingState {
  final AsyncValue<DecodingResult> result;
  final double progress;
  final bool isProcessing;

  DecodingState({
    this.result = const AsyncValue.loading(),
    this.progress = 0.0,
    this.isProcessing = false,
  });

  DecodingState copyWith({
    AsyncValue<DecodingResult>? result,
    double? progress,
    bool? isProcessing,
  }) {
    return DecodingState(
      result: result ?? this.result,
      progress: progress ?? this.progress,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class DecodingNotifier extends StateNotifier<DecodingState> {
  final ApiService _apiService;
  final LocalService _localService;
  final Ref _ref;

  DecodingNotifier(this._apiService, this._localService, this._ref) : super(DecodingState());

  Future<void> decode({
    required String audioFilePath,
    int? messageLength,
    required WatermarkMode mode,
  }) async {
    state = state.copyWith(isProcessing: true, progress: 0.1);

    try {
      DecodingResult result;

      if (mode == WatermarkMode.cloud || mode == WatermarkMode.hybrid) {
        try {
          result = await _apiService.decode(
            audioFilePath: audioFilePath,
            messageLength: messageLength,
          );
        } catch (e) {
          if (mode == WatermarkMode.hybrid) {
            state = state.copyWith(progress: 0.5);
            throw ProcessingError(
              message: 'Cloud processing failed. Local fallback not yet available.',
              code: 'LOCAL_FALLBACK_UNAVAILABLE',
              originalError: e,
              details: 'Please ensure your device has internet connectivity or the backend server is reachable.',
            );
          } else {
            rethrow;
          }
        }
      } else {
        throw ProcessingError(
          message: 'Local processing not yet available',
          code: 'LOCAL_PROCESSING_UNAVAILABLE',
          details: 'Local processing mode is currently in development. Please use Cloud mode instead.\n\n'
              'For Cloud mode to work, ensure your device:\n'
              '1. Has internet connectivity\n'
              '2. Can reach the AudioGuard backend server\n'
              '3. Is on the same network as the backend if using local IP',
        );
      }

      state = state.copyWith(
        result: AsyncValue.data(result),
        progress: 1.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'decode',
        mode: result.mode,
        timestamp: DateTime.now(),
        success: result.success,
        confidence: result.confidence,
      ));
    } catch (error, stackTrace) {
      state = state.copyWith(
        result: AsyncValue.error(error, stackTrace),
        isProcessing: false,
      );
      
      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'decode',
        mode: mode.name,
        timestamp: DateTime.now(),
        success: false,
      ));
    }
  }

  void reset() {
    state = DecodingState();
  }
}

final decodingProvider =
    StateNotifierProvider<DecodingNotifier, DecodingState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final local = ref.watch(localServiceProvider);
  return DecodingNotifier(api, local, ref);
});

// ===== Verification State =====

class VerificationState {
  final AsyncValue<VerifyResult> result;
  final double progress;
  final bool isProcessing;

  VerificationState({
    this.result = const AsyncValue.loading(),
    this.progress = 0.0,
    this.isProcessing = false,
  });

  VerificationState copyWith({
    AsyncValue<VerifyResult>? result,
    double? progress,
    bool? isProcessing,
  }) {
    return VerificationState(
      result: result ?? this.result,
      progress: progress ?? this.progress,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class VerificationNotifier extends StateNotifier<VerificationState> {
  final ApiService _apiService;
  final LocalService _localService;
  final Ref _ref;

  VerificationNotifier(this._apiService, this._localService, this._ref) : super(VerificationState());

  Future<void> verify({
    required String audioFilePath,
    required String expectedMessage,
    required WatermarkMode mode,
  }) async {
    state = state.copyWith(isProcessing: true, progress: 0.1);

    try {
      VerifyResult result;

      if (mode == WatermarkMode.cloud || mode == WatermarkMode.hybrid) {
        try {
          result = await _apiService.verify(
            audioFilePath: audioFilePath,
            message: expectedMessage,
          );
        } catch (e) {
          if (mode == WatermarkMode.hybrid) {
            state = state.copyWith(progress: 0.5);
            throw ProcessingError(
              message: 'Cloud processing failed. Local fallback not yet available.',
              code: 'LOCAL_FALLBACK_UNAVAILABLE',
              originalError: e,
              details: 'Please ensure your device has internet connectivity or the backend server is reachable.',
            );
          } else {
            rethrow;
          }
        }
      } else {
        throw ProcessingError(
          message: 'Local processing not yet available',
          code: 'LOCAL_PROCESSING_UNAVAILABLE',
          details: 'Local processing mode is currently in development. Please use Cloud mode instead.\n\n'
              'For Cloud mode to work, ensure your device:\n'
              '1. Has internet connectivity\n'
              '2. Can reach the AudioGuard backend server\n'
              '3. Is on the same network as the backend if using local IP',
        );
      }

      state = state.copyWith(
        result: AsyncValue.data(result),
        progress: 1.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'verify',
        mode: result.mode,
        timestamp: DateTime.now(),
        success: true,
        confidence: result.confidence,
      ));
    } catch (error, stackTrace) {
      state = state.copyWith(
        result: AsyncValue.error(error, stackTrace),
        isProcessing: false,
      );
      
      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'verify',
        mode: mode.name,
        timestamp: DateTime.now(),
        success: false,
      ));
    }
  }

  void reset() {
    state = VerificationState();
  }
}

final verificationProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final local = ref.watch(localServiceProvider);
  return VerificationNotifier(api, local, ref);
});

// ===== Analysis State =====

class AnalysisState {
  final AsyncValue<AnalysisResult> result;
  final double progress;
  final bool isProcessing;

  AnalysisState({
    this.result = const AsyncValue.loading(),
    this.progress = 0.0,
    this.isProcessing = false,
  });

  AnalysisState copyWith({
    AsyncValue<AnalysisResult>? result,
    double? progress,
    bool? isProcessing,
  }) {
    return AnalysisState(
      result: result ?? this.result,
      progress: progress ?? this.progress,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  final ApiService _apiService;
  final LocalService _localService;
  final Ref _ref;

  AnalysisNotifier(this._apiService, this._localService, this._ref) : super(AnalysisState());

  Future<void> analyze({
    required String audioFilePath,
    required WatermarkMode mode,
  }) async {
    state = state.copyWith(isProcessing: true, progress: 0.1);

    try {
      AnalysisResult result;

      if (mode == WatermarkMode.cloud || mode == WatermarkMode.hybrid) {
        try {
          result = await _apiService.analyze(audioFilePath: audioFilePath);
        } catch (e) {
          if (mode == WatermarkMode.hybrid) {
            state = state.copyWith(progress: 0.5);
            throw ProcessingError(
              message: 'Cloud processing failed. Local fallback not yet available.',
              code: 'LOCAL_FALLBACK_UNAVAILABLE',
              originalError: e,
              details: 'Please ensure your device has internet connectivity or the backend server is reachable.',
            );
          } else {
            rethrow;
          }
        }
      } else {
        throw ProcessingError(
          message: 'Local processing not yet available',
          code: 'LOCAL_PROCESSING_UNAVAILABLE',
          details: 'Local processing mode is currently in development. Please use Cloud mode instead.\n\n'
              'For Cloud mode to work, ensure your device:\n'
              '1. Has internet connectivity\n'
              '2. Can reach the AudioGuard backend server\n'
              '3. Is on the same network as the backend if using local IP',
        );
      }

      state = state.copyWith(
        result: AsyncValue.data(result),
        progress: 1.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'analyze',
        mode: result.mode,
        timestamp: DateTime.now(),
        success: true,
        confidence: result.confidence,
      ));
    } catch (error, stackTrace) {
      state = state.copyWith(
        result: AsyncValue.error(error, stackTrace),
        isProcessing: false,
      );
      
      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'analyze',
        mode: mode.name,
        timestamp: DateTime.now(),
        success: false,
      ));
    }
  }

  void reset() {
    state = AnalysisState();
  }
}

final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AnalysisState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final local = ref.watch(localServiceProvider);
  return AnalysisNotifier(api, local, ref);
});

// ===== Settings State =====

class AppSettings {
  final String apiBaseUrl;
  final WatermarkMode defaultMode;
  final bool autoSelectBestMode;
  final String? authToken;
  final bool darkModeEnabled;
  final bool saveHistory;
  final bool showNotifications;
  final bool enableAnalytics;

  AppSettings({
    this.apiBaseUrl = AppConstants.defaultApiBaseUrl,
    this.defaultMode = WatermarkMode.hybrid,
    this.autoSelectBestMode = true,
    this.authToken,
    this.darkModeEnabled = false,
    this.saveHistory = true,
    this.showNotifications = true,
    this.enableAnalytics = false,
  });

  AppSettings copyWith({
    String? apiBaseUrl,
    WatermarkMode? defaultMode,
    bool? autoSelectBestMode,
    String? authToken,
    bool? darkModeEnabled,
    bool? saveHistory,
    bool? showNotifications,
    bool? enableAnalytics,
  }) {
    return AppSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      defaultMode: defaultMode ?? this.defaultMode,
      autoSelectBestMode: autoSelectBestMode ?? this.autoSelectBestMode,
      authToken: authToken ?? this.authToken,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      saveHistory: saveHistory ?? this.saveHistory,
      showNotifications: showNotifications ?? this.showNotifications,
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings());

  void setApiBaseUrl(String url) {
    state = state.copyWith(apiBaseUrl: url);
  }

  void setDefaultMode(WatermarkMode mode) {
    state = state.copyWith(defaultMode: mode);
  }

  void setAutoSelectMode(bool enabled) {
    state = state.copyWith(autoSelectBestMode: enabled);
  }

  void setAuthToken(String? token) {
    state = state.copyWith(authToken: token);
  }

  void setDarkMode(bool enabled) {
    state = state.copyWith(darkModeEnabled: enabled);
  }

  void setSaveHistory(bool enabled) {
    state = state.copyWith(saveHistory: enabled);
  }

  void setShowNotifications(bool enabled) {
    state = state.copyWith(showNotifications: enabled);
  }

  void setEnableAnalytics(bool enabled) {
    state = state.copyWith(enableAnalytics: enabled);
  }

  Future<void> loadSettings(StorageService storage) async {
    try {
      final url = await storage.getApiBaseUrl();
      final modeStr = await storage.getWatermarkMode();
      final mode = WatermarkMode.fromString(modeStr);
      final token = await storage.getApiToken();
      final darkMode = await storage.getBool('dark_mode', defaultValue: false);

      state = AppSettings(
        apiBaseUrl: url,
        defaultMode: mode,
        authToken: token,
        darkModeEnabled: darkMode,
      );
    } catch (e) {
      // Keep default settings if loading fails
    }
  }

  Future<void> saveSettings(StorageService storage) async {
    try {
      await storage.setApiBaseUrl(state.apiBaseUrl);
      await storage.setWatermarkMode(state.defaultMode.name);
      if (state.authToken != null) {
        await storage.saveApiToken(state.authToken!);
      }
      await storage.setBool('dark_mode', state.darkModeEnabled);
    } catch (e) {
      // Log error but don't crash
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

// ===== Computed Providers =====

/// Check if any operation is currently processing
final isProcessingProvider = Provider<bool>((ref) {
  final encoding = ref.watch(encodingProvider);
  final decoding = ref.watch(decodingProvider);
  final verification = ref.watch(verificationProvider);
  final analysis = ref.watch(analysisProvider);

  return encoding.isProcessing ||
      decoding.isProcessing ||
      verification.isProcessing ||
      analysis.isProcessing;
});

/// Get overall progress (average of all operations)
final overallProgressProvider = Provider<double>((ref) {
  final encoding = ref.watch(encodingProvider);
  final decoding = ref.watch(decodingProvider);
  final verification = ref.watch(verificationProvider);
  final analysis = ref.watch(analysisProvider);

  if (!ref.watch(isProcessingProvider)) return 0.0;

  final total =
      encoding.progress + decoding.progress + verification.progress + analysis.progress;
  return total / 4;
});

/// Check if audio file is selected and valid
final hasValidAudioProvider = Provider<bool>((ref) {
  final audioPath = ref.watch(selectedAudioFileProvider);
  return audioPath != null && audioPath.isNotEmpty;
});
