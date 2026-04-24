import 'package:logger/logger.dart';

/// Centralized logger for AudioGuard Mobile
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void trace(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log audio file details
  static void logAudioMetadata({
    required String filename,
    required Duration duration,
    required int sampleRate,
    required int bitrate,
  }) {
    info(
      'Audio File: $filename\n'
      '  Duration: ${duration.inSeconds}s\n'
      '  Sample Rate: ${sampleRate}Hz\n'
      '  Bitrate: ${bitrate}kbps',
    );
  }

  /// Log watermark operation
  static void logWatermarkOperation({
    required String operation,
    required String mode,
    required Duration processingTime,
    required double confidence,
  }) {
    info(
      'Watermark $operation\n'
      '  Mode: $mode\n'
      '  Time: ${processingTime.inMilliseconds}ms\n'
      '  Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
    );
  }

  /// Log API request
  static void logApiRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? queryParams,
  }) {
    debug(
      'API Request: $method $endpoint'
      '${queryParams != null ? '\nParams: $queryParams' : ''}',
    );
  }

  /// Log API response
  static void logApiResponse({
    required int statusCode,
    required String endpoint,
    required Duration duration,
  }) {
    debug(
      'API Response: $statusCode $endpoint (${duration.inMilliseconds}ms)',
    );
  }
}
