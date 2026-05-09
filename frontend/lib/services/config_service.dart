import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Runtime configuration service for API URLs and timeouts
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  late SharedPreferences _prefs;
  bool _initialized = false;

  ConfigService._internal();

  factory ConfigService() {
    return _instance;
  }

  /// Initialize config service
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Get API base URL (reads from preferences, falls back to default)
  String getApiBaseUrl() {
    if (!_initialized) return AppConstants.defaultApiBaseUrl;
    try {
      return _prefs.getString('api_base_url') ?? AppConstants.defaultApiBaseUrl;
    } catch (_) {
      return AppConstants.defaultApiBaseUrl;
    }
  }

  /// Set API base URL
  Future<void> setApiBaseUrl(String url) async {
    if (!_initialized) await init();
    await _prefs.setString('api_base_url', url);
  }

  /// Get API timeout in seconds
  int getApiTimeout() {
    if (!_initialized) return 30;
    try {
      return _prefs.getInt('api_timeout') ?? 30;
    } catch (_) {
      return 30;
    }
  }

  /// Set API timeout in seconds
  Future<void> setApiTimeout(int seconds) async {
    if (!_initialized) await init();
    await _prefs.setInt('api_timeout', seconds);
  }

  /// Get file upload timeout in seconds
  int getFileUploadTimeout() {
    if (!_initialized) return 300;
    try {
      return _prefs.getInt('file_upload_timeout') ?? 300;
    } catch (_) {
      return 300;
    }
  }

  /// Set file upload timeout in seconds
  Future<void> setFileUploadTimeout(int seconds) async {
    if (!_initialized) await init();
    await _prefs.setInt('file_upload_timeout', seconds);
  }

  /// Get verify confidence threshold
  double getVerifyConfidenceThreshold() {
    if (!_initialized) return 0.7;
    try {
      return _prefs.getDouble('verify_confidence_threshold') ?? 0.7;
    } catch (_) {
      return 0.7;
    }
  }

  /// Set verify confidence threshold
  Future<void> setVerifyConfidenceThreshold(double threshold) async {
    if (!_initialized) await init();
    await _prefs.setDouble('verify_confidence_threshold', threshold);
  }

  /// Get analyze confidence threshold
  double getAnalyzeConfidenceThreshold() {
    if (!_initialized) return 0.5;
    try {
      return _prefs.getDouble('analyze_confidence_threshold') ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  /// Set analyze confidence threshold
  Future<void> setAnalyzeConfidenceThreshold(double threshold) async {
    if (!_initialized) await init();
    await _prefs.setDouble('analyze_confidence_threshold', threshold);
  }

  /// Get decode confidence threshold
  double getDecodeConfidenceThreshold() {
    if (!_initialized) return 0.8;
    try {
      return _prefs.getDouble('decode_confidence_threshold') ?? 0.8;
    } catch (_) {
      return 0.8;
    }
  }

  /// Set decode confidence threshold
  Future<void> setDecodeConfidenceThreshold(double threshold) async {
    if (!_initialized) await init();
    await _prefs.setDouble('decode_confidence_threshold', threshold);
  }
}
