import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../models/watermark_model.dart';
import 'dart:convert';

// ===== Message Validation =====

class MessageValidationError {
  final String message;
  final String code;

  MessageValidationError({
    required this.message,
    required this.code,
  });
}

/// Validate watermark message
final messageValidationProvider =
    Provider.family<MessageValidationError?, String>((ref, message) {
  if (message.isEmpty) {
    return MessageValidationError(
      message: 'Message cannot be empty',
      code: 'EMPTY_MESSAGE',
    );
  }

  if (message.length > AppConstants.maxMessageLength) {
    return MessageValidationError(
      message:
          'Message exceeds ${AppConstants.maxMessageLength} character limit',
      code: 'MESSAGE_TOO_LONG',
    );
  }

  if (message.length < AppConstants.minMessageLength) {
    return MessageValidationError(
      message: 'Message must be at least 1 character',
      code: 'MESSAGE_TOO_SHORT',
    );
  }

  // Check for non-ASCII characters
  try {
    message.codeUnits; // This checks if all chars are valid
    return null; // Valid
  } catch (_) {
    return MessageValidationError(
      message: 'Message contains invalid characters',
      code: 'INVALID_CHARACTERS',
    );
  }
});

// ===== Operation History =====

class HistoryEntry {
  final String operationType;
  final String filename;
  final DateTime timestamp;
  final bool success;
  final double? confidence;
  final String? message;
  final String mode;

  HistoryEntry({
    required this.operationType,
    required this.filename,
    required this.timestamp,
    required this.success,
    this.confidence,
    this.message,
    required this.mode,
  });

  Map<String, dynamic> toJson() => {
        'operationType': operationType,
        'filename': filename,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        'confidence': confidence,
        'message': message,
        'mode': mode,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        operationType: json['operationType'],
        filename: json['filename'],
        timestamp: DateTime.parse(json['timestamp']),
        success: json['success'],
        confidence: json['confidence']?.toDouble(),
        message: json['message'],
        mode: json['mode'] ?? 'cloud',
      );
}

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  final StorageService _storage;
  static const String _storageKey = 'operation_history';

  HistoryNotifier(this._storage) : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await _storage.getString(_storageKey);
    if (data != null) {
      try {
        final List<dynamic> jsonList = json.decode(data);
        state = jsonList.map((e) => HistoryEntry.fromJson(e)).toList();
      } catch (_) {
        state = [];
      }
    }
  }

  Future<void> addEntry(HistoryEntry entry) async {
    state = [entry, ...state].take(50).toList();
    await _storage.setString(_storageKey, json.encode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> clearHistory() async {
    state = [];
    await _storage.setString(_storageKey, json.encode([]));
  }
}

final storageServiceProvider = Provider((ref) => StorageService());

final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return HistoryNotifier(storage);
});

// ===== Appearance Settings =====

enum AppThemeMode { light, dark, system }

class AppearanceSettings {
  final AppThemeMode themeMode;
  final double fontSizeScale; // 0.8 to 1.4

  AppearanceSettings({
    required this.themeMode,
    required this.fontSizeScale,
  });

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    double? fontSizeScale,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
    );
  }
}

class AppearanceNotifier extends StateNotifier<AppearanceSettings> {
  final StorageService _storage;

  AppearanceNotifier(this._storage)
      : super(AppearanceSettings(
          themeMode: AppThemeMode.system,
          fontSizeScale: 1.0,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final themeStr = await _storage.getString('theme_mode');
    final scale = await _storage.getInt('font_size_scale', defaultValue: 100);

    state = AppearanceSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => AppThemeMode.system,
      ),
      fontSizeScale: scale / 100.0,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _storage.setString('theme_mode', mode.name);
  }

  Future<void> setFontSizeScale(double scale) async {
    state = state.copyWith(fontSizeScale: scale);
    await _storage.setInt('font_size_scale', (scale * 100).toInt());
  }
}

final appearanceProvider = StateNotifierProvider<AppearanceNotifier, AppearanceSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AppearanceNotifier(storage);
});

// ===== User Identity =====

class UserIdentityNotifier extends StateNotifier<String> {
  final StorageService _storage;

  UserIdentityNotifier(this._storage) : super('Anonymous') {
    _loadAuthorName();
  }

  Future<void> _loadAuthorName() async {
    final name = await _storage.getString(AppConstants.storageKeyAuthorName);
    if (name != null) state = name;
  }

  Future<void> setAuthorName(String name) async {
    state = name;
    await _storage.setString(AppConstants.storageKeyAuthorName, name);
  }
}

final userIdentityProvider = StateNotifierProvider<UserIdentityNotifier, String>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return UserIdentityNotifier(storage);
});

// ===== Screen Navigation =====

enum CurrentScreen {
  home,
  encode,
  decode,
  verify,
  analyze,
  settings,
}

final currentScreenProvider = StateProvider<CurrentScreen>((ref) {
  return CurrentScreen.home;
});

/// Bottom sheet visibility
final showBottomSheetProvider = StateProvider<bool>((ref) {
  return false;
});

/// Loading overlay visibility
final showLoadingProvider = StateProvider<bool>((ref) {
  return false;
});

/// Snackbar message
final snackbarMessageProvider =
    StateProvider<({String message, bool isError})?>((ref) {
  return null;
});
