import 'package:shared_preferences/shared_preferences.dart';

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
    return _prefs.getString('api_base_url') ?? 
           'https://audioguard-api.onrender.com';
  }

  /// Set API base URL
  Future<void> setApiBaseUrl(String url) async {
    await _prefs.setString('api_base_url', url);
  }

  /// Get API timeout in seconds
  int getApiTimeout() {
    return _prefs.getInt('api_timeout') ?? 30;
  }

  /// Set API timeout in seconds
  Future<void> setApiTimeout(int seconds) async {
    await _prefs.setInt('api_timeout', seconds);
  }

  /// Get file upload timeout in seconds
  int getFileUploadTimeout() {
    return _prefs.getInt('file_upload_timeout') ?? 300;
  }

  /// Set file upload timeout in seconds
  Future<void> setFileUploadTimeout(int seconds) async {
    await _prefs.setInt('file_upload_timeout', seconds);
  }

  /// Get verify confidence threshold
  double getVerifyConfidenceThreshold() {
    return _prefs.getDouble('verify_confidence_threshold') ?? 0.7;
  }

  /// Set verify confidence threshold
  Future<void> setVerifyConfidenceThreshold(double threshold) async {
    await _prefs.setDouble('verify_confidence_threshold', threshold);
  }

  /// Get analyze confidence threshold
  double getAnalyzeConfidenceThreshold() {
    return _prefs.getDouble('analyze_confidence_threshold') ?? 0.5;
  }

  /// Set analyze confidence threshold
  Future<void> setAnalyzeConfidenceThreshold(double threshold) async {
    await _prefs.setDouble('analyze_confidence_threshold', threshold);
  }

  /// Get decode confidence threshold
  double getDecodeConfidenceThreshold() {
    return _prefs.getDouble('decode_confidence_threshold') ?? 0.8;
  }

  /// Set decode confidence threshold
  Future<void> setDecodeConfidenceThreshold(double threshold) async {
    await _prefs.setDouble('decode_confidence_threshold', threshold);
  }
}
