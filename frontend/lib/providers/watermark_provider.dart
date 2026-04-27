import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/watermark_model.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/local_service.dart';
import '../services/smart_processing_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import 'ui_provider.dart';

// ===== Service Providers =====

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

final connectivityProvider = Provider((ref) {
  return Connectivity();
});

/// Smart processing service - Cloud first with local fallback
final smartProcessingServiceProvider = Provider((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final connectivity = ref.watch(connectivityProvider);

  return SmartProcessingService(
    cloudService: apiService,
    connectivity: connectivity,
  );
});

// ===== Audio State Providers =====

/// Selected audio file
final selectedAudioFileProvider = StateProvider<String?>((ref) => null);

/// Currently selected encoded file ID (from encoding response)
final selectedEncodedFileIdProvider = StateProvider<String?>((ref) => null);

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

// ===== Stats State =====

class OperationStats {
  final int totalOperations;
  final double successRate;
  final double averageConfidence;
  final Map<String, int> typeBreakdown;
  final int successfulOperations;
  final int failedOperations;

  OperationStats({
    this.totalOperations = 0,
    this.successRate = 0.0,
    this.averageConfidence = 0.0,
    this.typeBreakdown = const {},
    this.successfulOperations = 0,
    this.failedOperations = 0,
  });
}

final statsProvider = Provider<OperationStats>((ref) {
  final history = ref.watch(historyProvider);
  
  if (history.isEmpty) return OperationStats();
  
  final total = history.length;
  final successful = history.where((e) => e.success).length;
  final failed = total - successful;
  final avgConf = history.isEmpty ? 0.0 : history.map((e) => e.confidence ?? 0.0).fold(0.0, (a, b) => a + b) / total;

  final Map<String, int> breakdown = {};
  for (final entry in history) {
    breakdown[entry.operationType] = (breakdown[entry.operationType] ?? 0) + 1;
  }
      
  return OperationStats(
    totalOperations: total,
    successRate: successful / total,
    averageConfidence: avgConf,
    typeBreakdown: breakdown,
    successfulOperations: successful,
    failedOperations: failed,
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
  final SmartProcessingService _smartProcessing;
  final Ref _ref;

  EncodingNotifier(this._apiService, this._ref, this._smartProcessing) : super(EncodingState());

  Future<void> encode({
    required String audioFilePath,
    required String message,
    required WatermarkMode mode,
  }) async {
    state = state.copyWith(isProcessing: true, progress: 0.1);

    try {
      EncodingResult result;

      if (mode == WatermarkMode.hybrid) {
        result = await _smartProcessing.encode(
          audioFilePath: audioFilePath,
          message: message,
        );
      } else if (mode == WatermarkMode.cloud) {
        result = await _apiService.encode(
          audioFilePath: audioFilePath,
          message: message,
        );
      } else {
        throw ProcessingError(
          message: 'Local processing not available',
          code: 'LOCAL_NOT_AVAILABLE',
          details: 'Local processing is currently in development. Please use Cloud or Hybrid mode.',
        );
      }

      // Store the file_id from the response for subsequent operations
      if (result.fileId != null && result.fileId!.isNotEmpty) {
        _ref.read(selectedEncodedFileIdProvider.notifier).state = result.fileId;
      }

      state = state.copyWith(
        result: AsyncValue.data(result),
        progress: 1.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'encode',
        filename: audioFilePath.split('/').last,
        timestamp: DateTime.now(),
        success: result.success,
        confidence: result.confidence,
        mode: mode.label,
        message: message,
      ));
    } catch (e) {
      state = state.copyWith(
        result: AsyncValue.error(e, StackTrace.current),
        progress: 0.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'encode',
        filename: audioFilePath.split('/').last,
        timestamp: DateTime.now(),
        success: false,
        mode: mode.label,
      ));

      rethrow;
    }
  }

  void reset() {
    state = EncodingState();
  }
}

final encodingProvider =
    StateNotifierProvider<EncodingNotifier, EncodingState>((ref) {
  final smartProcessing = ref.watch(smartProcessingServiceProvider);
  final api = ref.watch(apiServiceProvider);
  return EncodingNotifier(api, ref, smartProcessing);
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
  final SmartProcessingService _smartProcessing;
  final Ref _ref;

  DecodingNotifier(this._apiService, this._ref, this._smartProcessing) : super(DecodingState());

  Future<void> decode({
    required String? fileId,
    int? messageLength,
    required WatermarkMode mode,
  }) async {
    state = state.copyWith(isProcessing: true, progress: 0.1);
    final audioPath = _ref.read(selectedAudioFileProvider);

    try {
      final id = fileId ?? _ref.read(selectedEncodedFileIdProvider);
      if (id == null || id.isEmpty) {
        throw ProcessingError(
          message: 'No file to decode',
          code: 'NO_FILE_PROVIDED',
          details: 'Please encode a file first or provide a file ID',
        );
      }

      DecodingResult result;

      if (mode == WatermarkMode.hybrid) {
        result = await _smartProcessing.decode(
          fileId: id,
          messageLength: messageLength,
        );
      } else if (mode == WatermarkMode.cloud) {
        result = await _apiService.decode(
          fileId: id,
          messageLength: messageLength,
        );
      } else {
        throw ProcessingError(
          message: 'Local processing not available',
          code: 'LOCAL_NOT_AVAILABLE',
          details: 'Local processing is currently in development. Please use Cloud or Hybrid mode.',
        );
      }

      state = state.copyWith(
        result: AsyncValue.data(result),
        progress: 1.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'decode',
        filename: audioPath?.split('/').last ?? 'Unknown',
        timestamp: DateTime.now(),
        success: result.success,
        confidence: result.confidence,
        mode: mode.label,
        message: result.message,
      ));
    } catch (e) {
      state = state.copyWith(
        result: AsyncValue.error(e, StackTrace.current),
        progress: 0.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'decode',
        filename: audioPath?.split('/').last ?? 'Unknown',
        timestamp: DateTime.now(),
        success: false,
        mode: mode.label,
      ));

      rethrow;
    }
  }

  void reset() {
    state = DecodingState();
  }
}

final decodingProvider =
    StateNotifierProvider<DecodingNotifier, DecodingState>((ref) {
  final smartProcessing = ref.watch(smartProcessingServiceProvider);
  final api = ref.watch(apiServiceProvider);
  return DecodingNotifier(api, ref, smartProcessing);
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
  final Ref _ref;
  final SmartProcessingService _smartProcessing;

  VerificationNotifier(this._apiService, this._ref, this._smartProcessing) : super(VerificationState());

  Future<void> verify({
    required String? fileId,
    required String expectedMessage,
    required WatermarkMode mode,
  }) async {
    state = state.copyWith(isProcessing: true, progress: 0.1);
    final audioPath = _ref.read(selectedAudioFileProvider);

    try {
      final id = fileId ?? _ref.read(selectedEncodedFileIdProvider);
      if (id == null || id.isEmpty) {
        throw ProcessingError(
          message: 'No file to verify',
          code: 'NO_FILE_PROVIDED',
          details: 'Please encode a file first or provide a file ID',
        );
      }

      VerifyResult result;

      if (mode == WatermarkMode.hybrid) {
        result = await _smartProcessing.verify(
          fileId: id,
          message: expectedMessage,
        );
      } else if (mode == WatermarkMode.cloud) {
        result = await _apiService.verify(
          fileId: id,
          message: expectedMessage,
        );
      } else {
        throw ProcessingError(
          message: 'Local processing not available',
          code: 'LOCAL_NOT_AVAILABLE',
          details: 'Local processing is currently in development. Please use Cloud or Hybrid mode.',
        );
      }

      state = state.copyWith(
        result: AsyncValue.data(result),
        progress: 1.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'verify',
        filename: audioPath?.split('/').last ?? 'Unknown',
        timestamp: DateTime.now(),
        success: result.isValid,
        confidence: result.confidence,
        mode: mode.label,
        message: expectedMessage,
      ));
    } catch (e) {
      state = state.copyWith(
        result: AsyncValue.error(e, StackTrace.current),
        progress: 0.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'verify',
        filename: audioPath?.split('/').last ?? 'Unknown',
        timestamp: DateTime.now(),
        success: false,
        mode: mode.label,
      ));

      rethrow;
    }
  }

  void reset() {
    state = VerificationState();
  }
}

final verificationProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>((ref) {
  final smartProcessing = ref.watch(smartProcessingServiceProvider);
  final api = ref.watch(apiServiceProvider);
  return VerificationNotifier(api, ref, smartProcessing);
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
  final Ref _ref;
  final SmartProcessingService _smartProcessing;

  AnalysisNotifier(this._apiService, this._ref, this._smartProcessing) : super(AnalysisState());

  Future<void> analyze({
    required String? fileId,
    required WatermarkMode mode,
  }) async {
    state = state.copyWith(isProcessing: true, progress: 0.1);
    final audioPath = _ref.read(selectedAudioFileProvider);

    try {
      final id = fileId ?? _ref.read(selectedEncodedFileIdProvider);
      if (id == null || id.isEmpty) {
        throw ProcessingError(
          message: 'No file to analyze',
          code: 'NO_FILE_PROVIDED',
          details: 'Please encode a file first or provide a file ID',
        );
      }

      AnalysisResult result;

      if (mode == WatermarkMode.hybrid) {
        result = await _smartProcessing.analyze(fileId: id);
      } else if (mode == WatermarkMode.cloud) {
        result = await _apiService.analyze(fileId: id);
      } else {
        throw ProcessingError(
          message: 'Local processing not available',
          code: 'LOCAL_NOT_AVAILABLE',
          details: 'Local processing is currently in development. Please use Cloud or Hybrid mode.',
        );
      }

      state = state.copyWith(
        result: AsyncValue.data(result),
        progress: 1.0,
        isProcessing: false,
      );

      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'analyze',
        filename: audioPath?.split('/').last ?? 'Unknown',
        timestamp: DateTime.now(),
        success: true,
        confidence: result.confidence,
        mode: mode.label,
      ));
    } catch (error, stackTrace) {
      state = state.copyWith(
        result: AsyncValue.error(error, stackTrace),
        isProcessing: false,
      );
      
      _ref.read(historyProvider.notifier).addEntry(HistoryEntry(
        operationType: 'analyze',
        filename: audioPath?.split('/').last ?? 'Unknown',
        timestamp: DateTime.now(),
        success: false,
        mode: mode.label,
      ));
      
      rethrow;
    }
  }

  void reset() {
    state = AnalysisState();
  }
}

final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AnalysisState>((ref) {
  final smartProcessing = ref.watch(smartProcessingServiceProvider);
  final api = ref.watch(apiServiceProvider);
  return AnalysisNotifier(api, ref, smartProcessing);
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
