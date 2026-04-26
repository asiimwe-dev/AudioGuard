import 'package:dio/dio.dart';
import '../models/watermark_model.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// API Response Models

class EncodeResponse {
  final bool success;
  final String fileId;
  final double embeddingStrength;
  final int processingTimeMs;
  final String? message;

  EncodeResponse({
    required this.success,
    required this.fileId,
    required this.embeddingStrength,
    required this.processingTimeMs,
    this.message,
  });

  factory EncodeResponse.fromJson(Map<String, dynamic> json) => EncodeResponse(
        success: json['success'] as bool,
        fileId: json['file_id'] as String,
        embeddingStrength: (json['embedding_strength'] as num).toDouble(),
        processingTimeMs: (json['processing_time_ms'] as num).toInt(),
        message: json['message'] as String?,
      );
}

class DecodeResponse {
  final bool success;
  final String? message;
  final double confidence;
  final int processingTimeMs;
  final String? method;
  final double? snrDb;
  final String? error;

  DecodeResponse({
    required this.success,
    this.message,
    required this.confidence,
    required this.processingTimeMs,
    this.method,
    this.snrDb,
    this.error,
  });

  factory DecodeResponse.fromJson(Map<String, dynamic> json) => DecodeResponse(
        success: json['success'] as bool,
        message: json['message'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
        processingTimeMs: (json['processing_time_ms'] as num).toInt(),
        method: json['method'] as String?,
        snrDb: json['snr_db'] != null ? (json['snr_db'] as num).toDouble() : null,
        error: json['error'] as String?,
      );
}

class VerifyResponse {
  final bool success;
  final bool watermarkDetected;
  final double confidence;
  final int processingTimeMs;

  VerifyResponse({
    required this.success,
    required this.watermarkDetected,
    required this.confidence,
    required this.processingTimeMs,
  });

  factory VerifyResponse.fromJson(Map<String, dynamic> json) => VerifyResponse(
        success: json['success'] as bool,
        watermarkDetected: json['watermark_detected'] as bool,
        confidence: (json['confidence'] as num).toDouble(),
        processingTimeMs: (json['processing_time_ms'] as num).toInt(),
      );
}

class AnalyzeResponse {
  final bool success;
  final bool watermarkPresent;
  final double signalStrength;
  final Map<String, dynamic> spectralInfo;
  final int processingTimeMs;

  AnalyzeResponse({
    required this.success,
    required this.watermarkPresent,
    required this.signalStrength,
    required this.spectralInfo,
    required this.processingTimeMs,
  });

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) =>
      AnalyzeResponse(
        success: json['success'] as bool,
        watermarkPresent: json['watermark_present'] as bool,
        signalStrength: (json['signal_strength'] as num).toDouble(),
        spectralInfo: json['spectral_info'] as Map<String, dynamic>? ?? {},
        processingTimeMs: (json['processing_time_ms'] as num).toInt(),
      );
}

class HealthResponse {
  final String status;
  final String version;
  final Map<String, dynamic> services;

  HealthResponse({
    required this.status,
    required this.version,
    required this.services,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) =>
      HealthResponse(
        status: json['status'] as String,
        version: json['version'] as String,
        services: json['services'] as Map<String, dynamic>,
      );
}

/// REST API Client for AudioGuard Backend (no code generation)
class AudioGuardApiClient {
  final Dio dio;
  final String baseUrl;

  AudioGuardApiClient({
    required this.dio,
    required this.baseUrl,
  });

  /// Check API health
  Future<HealthResponse> getHealth() async {
    try {
      final response = await dio.get('$baseUrl${AppConstants.healthEndpoint}');
      return HealthResponse.fromJson(response.data);
    } catch (e) {
      throw ProcessingError(
        message: 'Health check failed',
        code: 'HEALTH_CHECK_FAILED',
        originalError: e,
      );
    }
  }

  /// Encode with watermark
  Future<EncodeResponse> encode({
    required String audioFilePath,
    required String message,
    int? messageLength,
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio_file': await MultipartFile.fromFile(audioFilePath),
        'message': message,
        if (messageLength != null) 'message_length': messageLength,
      });

      final response = await dio.post(
        '$baseUrl${AppConstants.encodeEndpoint}',
        data: formData,
      );

      return EncodeResponse.fromJson(response.data);
    } catch (e) {
      throw ProcessingError(
        message: 'Encoding failed',
        code: 'ENCODING_FAILED',
        originalError: e,
      );
    }
  }

  /// Decode watermark
  Future<DecodeResponse> decode({
    required String fileId,
    int? messageLength,
  }) async {
    try {
      final requestBody = {
        'file_id': fileId,
        'use_cnn': false,
        'confidence_threshold': 0.5,
      };

      final response = await dio.post(
        '$baseUrl${AppConstants.decodeEndpoint}',
        data: requestBody,
      );

      return DecodeResponse.fromJson(response.data);
    } catch (e) {
      throw ProcessingError(
        message: 'Decoding failed',
        code: 'DECODING_FAILED',
        originalError: e,
      );
    }
  }

  /// Verify watermark
  Future<VerifyResponse> verify({
    required String fileId,
    required String message,
  }) async {
    try {
      final requestBody = {
        'file_id': fileId,
        'expected_message': message,
      };

      final response = await dio.post(
        '$baseUrl${AppConstants.verifyEndpoint}',
        data: requestBody,
      );

      return VerifyResponse.fromJson(response.data);
    } catch (e) {
      throw ProcessingError(
        message: 'Verification failed',
        code: 'VERIFICATION_FAILED',
        originalError: e,
      );
    }
  }

  /// Analyze audio
  Future<AnalyzeResponse> analyze({
    required String fileId,
  }) async {
    try {
      final requestBody = {
        'file_id': fileId,
      };

      final response = await dio.post(
        '$baseUrl${AppConstants.analyzeEndpoint}',
        data: requestBody,
      );

      return AnalyzeResponse.fromJson(response.data);
    } catch (e) {
      throw ProcessingError(
        message: 'Analysis failed',
        code: 'ANALYSIS_FAILED',
        originalError: e,
      );
    }
  }
}

/// API Service wrapper with error handling and logging
class ApiService {
  late final AudioGuardApiClient _client;
  late final Dio _dio;
  String _baseUrl = AppConstants.defaultApiBaseUrl;
  String? _authToken;

  ApiService({String? baseUrl, String? authToken}) {
    _baseUrl = baseUrl ?? AppConstants.defaultApiBaseUrl;
    _authToken = authToken;
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: AppConstants.apiTimeout,
        receiveTimeout: AppConstants.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      ),
    );

    // Add logging interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          AppLogger.logApiRequest(
            method: options.method,
            endpoint: options.path,
            queryParams: options.queryParameters,
          );
          return handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.logApiResponse(
            statusCode: response.statusCode ?? 0,
            endpoint: response.requestOptions.path,
            duration: const Duration(milliseconds: 0),
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          AppLogger.error(
            'API Error: ${error.message}',
            error.error,
            error.stackTrace,
          );
          return handler.next(error);
        },
      ),
    );

    _client = AudioGuardApiClient(dio: _dio, baseUrl: _baseUrl);
  }

  /// Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Change API base URL
  void setBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    _dio.options.baseUrl = baseUrl;
  }

  /// Check API health
  Future<bool> checkHealth() async {
    try {
      AppLogger.info('Testing connection to: $_baseUrl/health');
      await _client.getHealth().timeout(
            const Duration(seconds: 10),
          );
      AppLogger.info('Health check successful');
      return true;
    } catch (e) {
      AppLogger.error('Health check failed', e);
      print('HEALTH CHECK ERROR: $e');
      return false;
    }
  }

  /// Encode audio with watermark
  Future<EncodingResult> encode({
    required String audioFilePath,
    required String message,
    int? messageLength,
  }) async {
    try {
      final startTime = DateTime.now();

      final response = await _client.encode(
        audioFilePath: audioFilePath,
        message: message,
        messageLength: messageLength,
      ).timeout(AppConstants.fileUploadTimeout);

      final duration = DateTime.now().difference(startTime);

      return EncodingResult(
        encodedFilePath: audioFilePath,
        fileId: response.fileId,
        processingTime: duration,
        mode: 'cloud',
        confidence: response.embeddingStrength,
        originalFileSize: 0,
        encodedFileSize: 0,
      );
    } catch (e) {
      AppLogger.error('Encoding failed', e);
      rethrow;
    }
  }

  /// Decode watermark from audio
  Future<DecodingResult> decode({
    required String fileId,
    int? messageLength,
  }) async {
    try {
      final startTime = DateTime.now();

      final response = await _client.decode(
        fileId: fileId,
        messageLength: messageLength,
      ).timeout(AppConstants.fileUploadTimeout);

      final duration = DateTime.now().difference(startTime);

      return DecodingResult(
        message: response.message,
        confidence: response.confidence,
        mode: 'cloud',
        processingTime: duration,
        suggestions: [],
        success: response.success,
      );
    } catch (e) {
      AppLogger.error('Decoding failed', e);
      rethrow;
    }
  }

  /// Verify watermark
  Future<VerifyResult> verify({
    required String fileId,
    required String message,
  }) async {
    try {
      final startTime = DateTime.now();

      final response = await _client.verify(
        fileId: fileId,
        message: message,
      ).timeout(AppConstants.fileUploadTimeout);

      final duration = DateTime.now().difference(startTime);

      return VerifyResult(
        isValid: response.watermarkDetected,
        confidence: response.confidence,
        mode: 'cloud',
        processingTime: duration,
      );
    } catch (e) {
      AppLogger.error('Verification failed', e);
      rethrow;
    }
  }

  /// Analyze audio for watermark presence
  Future<AnalysisResult> analyze({
    required String fileId,
  }) async {
    try {
      final startTime = DateTime.now();

      final response = await _client.analyze(
        fileId: fileId,
      ).timeout(AppConstants.fileUploadTimeout);

      final duration = DateTime.now().difference(startTime);

      return AnalysisResult(
        watermarkPresent: response.watermarkPresent,
        signalStrength: response.signalStrength,
        spectralInfo: response.spectralInfo,
        mode: 'cloud',
        processingTime: duration,
      );
    } catch (e) {
      AppLogger.error('Analysis failed', e);
      rethrow;
    }
  }

  void dispose() {
    _dio.close();
  }
}
