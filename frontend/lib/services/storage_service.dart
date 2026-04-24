import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Secure storage service for credentials and sensitive data
class StorageService {
  static const String _boxName = 'audioguard_storage';
  static const _secureStorage = FlutterSecureStorage();
  late Box _box;
  bool _initialized = false;

  /// Initialize storage (must be called once at app startup)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      _initialized = true;
      AppLogger.info('✅ Storage service initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize storage', e);
      rethrow;
    }
  }

  /// Save API token securely
  Future<void> saveApiToken(String token) async {
    try {
      await _secureStorage.write(
        key: AppConstants.storageKeyApiToken,
        value: token,
      );
      AppLogger.debug('✅ API token saved');
    } catch (e) {
      AppLogger.error('Failed to save API token', e);
      rethrow;
    }
  }

  /// Get API token
  Future<String?> getApiToken() async {
    try {
      final token = await _secureStorage.read(
        key: AppConstants.storageKeyApiToken,
      );
      return token;
    } catch (e) {
      AppLogger.error('Failed to get API token', e);
      return null;
    }
  }

  /// Delete API token
  Future<void> deleteApiToken() async {
    try {
      await _secureStorage.delete(
        key: AppConstants.storageKeyApiToken,
      );
      AppLogger.debug('✅ API token deleted');
    } catch (e) {
      AppLogger.error('Failed to delete API token', e);
    }
  }

  /// Save string preference
  Future<void> setString(String key, String value) async {
    try {
      if (!_initialized) await initialize();
      await _box.put(key, value);
      AppLogger.debug('✅ Preference saved: $key');
    } catch (e) {
      AppLogger.error('Failed to save preference: $key', e);
      rethrow;
    }
  }

  /// Get string preference
  Future<String?> getString(String key) async {
    try {
      if (!_initialized) await initialize();
      return _box.get(key) as String?;
    } catch (e) {
      AppLogger.error('Failed to get preference: $key', e);
      return null;
    }
  }

  /// Save boolean preference
  Future<void> setBool(String key, bool value) async {
    try {
      if (!_initialized) await initialize();
      await _box.put(key, value);
      AppLogger.debug('✅ Boolean preference saved: $key = $value');
    } catch (e) {
      AppLogger.error('Failed to save boolean preference: $key', e);
      rethrow;
    }
  }

  /// Get boolean preference
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    try {
      if (!_initialized) await initialize();
      return _box.get(key, defaultValue: defaultValue) as bool;
    } catch (e) {
      AppLogger.error('Failed to get boolean preference: $key', e);
      return defaultValue;
    }
  }

  /// Save integer preference
  Future<void> setInt(String key, int value) async {
    try {
      if (!_initialized) await initialize();
      await _box.put(key, value);
      AppLogger.debug('✅ Integer preference saved: $key = $value');
    } catch (e) {
      AppLogger.error('Failed to save integer preference: $key', e);
      rethrow;
    }
  }

  /// Get integer preference
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    try {
      if (!_initialized) await initialize();
      return _box.get(key, defaultValue: defaultValue) as int;
    } catch (e) {
      AppLogger.error('Failed to get integer preference: $key', e);
      return defaultValue;
    }
  }

  /// Save API base URL
  Future<void> setApiBaseUrl(String url) async {
    try {
      await setString(AppConstants.storageKeyApiBaseUrl, url);
      AppLogger.info('API base URL saved: $url');
    } catch (e) {
      AppLogger.error('Failed to save API base URL', e);
      rethrow;
    }
  }

  /// Get API base URL
  Future<String> getApiBaseUrl() async {
    final url = await getString(AppConstants.storageKeyApiBaseUrl);
    return url ?? AppConstants.defaultApiBaseUrl;
  }

  /// Save watermark mode
  Future<void> setWatermarkMode(String mode) async {
    try {
      await setString(AppConstants.storageKeyWatermarkMode, mode);
      AppLogger.info('Watermark mode saved: $mode');
    } catch (e) {
      AppLogger.error('Failed to save watermark mode', e);
      rethrow;
    }
  }

  /// Get watermark mode
  Future<String> getWatermarkMode() async {
    final mode = await getString(AppConstants.storageKeyWatermarkMode);
    return mode ?? 'hybrid';
  }

  /// Clear all data (including secure storage)
  Future<void> clearAll() async {
    try {
      if (_initialized) {
        await _box.clear();
      }
      await _secureStorage.deleteAll();
      AppLogger.info('✅ All storage cleared');
    } catch (e) {
      AppLogger.error('Failed to clear storage', e);
      rethrow;
    }
  }

  /// Dispose storage
  Future<void> dispose() async {
    try {
      if (_initialized) {
        await _box.close();
      }
      AppLogger.debug('✅ Storage service disposed');
    } catch (e) {
      AppLogger.error('Failed to dispose storage', e);
    }
  }
}
