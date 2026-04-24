import 'package:dio/dio.dart';
import '../models/watermark_model.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// API Response Models

class EncodeResponse {
  final String status;
  final String? encodedFile; // Base64 or file URL
  final double confidence;
  final int processingTimeMs;

  EncodeResponse({
    required this.status,
    this.encodedFile,
    required this.confidence,
    required this.processingTimeMs,
  });

  factory EncodeResponse.fromJson(Map<String, dynamic> json) => EncodeResponse(
        status: json['status'] as String,
        encodedFile: json['encoded_file'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
        processingTimeMs: json['processing_time_ms'] as int,
      );
}

class DecodeResponse {
  final String status;
  final String? message;
  final double confidence;
  final int processingTimeMs;
  final List<String> suggestions;

  DecodeResponse({
    required this.status,
    this.message,
    required this.confidence,
    required this.processingTimeMs,
    List<String>? suggestions,
  }) : suggestions = suggestions ?? [];

  factory DecodeResponse.fromJson(Map<String, dynamic> json) => DecodeResponse(
        status: json['status'] as String,
        message: json['message'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
        processingTimeMs: json['processing_time_ms'] as int,
        suggestions: List<String>.from(json['suggestions'] as List? ?? []),
      );
}

class VerifyResponse {
  final String status;
  final bool isValid;
  final double confidence;
  final int processingTimeMs;

  VerifyResponse({
    required this.status,
    required this.isValid,
    required this.confidence,
    required this.processingTimeMs,
  });

  factory VerifyResponse.fromJson(Map<String, dynamic> json) => VerifyResponse(
        status: json['status'] as String,
        isValid: json['is_valid'] as bool,
        confidence: (json['confidence'] as num).toDouble(),
        processingTimeMs: json['processing_time_ms'] as int,
      );
}

class AnalyzeResponse {
  final String status;
  final bool watermarkPresent;
  final double signalStrength;
  final Map<String, dynamic> spectralInfo;
  final int processingTimeMs;

  AnalyzeResponse({
    required this.status,
    required this.watermarkPresent,
    required this.signalStrength,
    required this.spectralInfo,
    required this.processingTimeMs,
  });

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) =>
      AnalyzeResponse(
        status: json['status'] as String,
        watermarkPresent: json['watermark_present'] as bool,
        signalStrength: (json['signal_strength'] as num).toDouble(),
        spectralInfo: json['spectral_info'] as Map<String, dynamic>,
        processingTimeMs: json['processing_time_ms'] as int,
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
        'message_length': ?messageLength,
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
    required String audioFilePath,
    int? messageLength,
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio_file': await MultipartFile.fromFile(audioFilePath),
        'message_length': ?messageLength,
      });

      final response = await dio.post(
        '$baseUrl${AppConstants.decodeEndpoint}',
        data: formData,
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
    required String audioFilePath,
    required String message,
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio_file': await MultipartFile.fromFile(audioFilePath),
        'message': message,
      });

      final response = await dio.post(
        '$baseUrl${AppConstants.verifyEndpoint}',
        data: formData,
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
    required String audioFilePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio_file': await MultipartFile.fromFile(audioFilePath),
      });

      final response = await dio.post(
        '$baseUrl${AppConstants.analyzeEndpoint}',
        data: formData,
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
      await _client.getHealth().timeout(
            const Duration(seconds: 5),
          );
      return true;
    } catch (e) {
      AppLogger.warning('Health check failed: $e');
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
        processingTime: duration,
        mode: 'cloud',
        confidence: response.confidence,
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
    required String audioFilePath,
    int? messageLength,
  }) async {
    try {
      final startTime = DateTime.now();

      final response = await _client.decode(
        audioFilePath: audioFilePath,
        messageLength: messageLength,
      ).timeout(AppConstants.fileUploadTimeout);

      final duration = DateTime.now().difference(startTime);

      return DecodingResult(
        message: response.message,
        confidence: response.confidence,
        mode: 'cloud',
        processingTime: duration,
        suggestions: response.suggestions,
        success: response.status == 'ok',
      );
    } catch (e) {
      AppLogger.error('Decoding failed', e);
      rethrow;
    }
  }

  /// Verify watermark
  Future<VerifyResult> verify({
    required String audioFilePath,
    required String message,
  }) async {
    try {
      final startTime = DateTime.now();

      final response = await _client.verify(
        audioFilePath: audioFilePath,
        message: message,
      ).timeout(AppConstants.fileUploadTimeout);

      final duration = DateTime.now().difference(startTime);

      return VerifyResult(
        isValid: response.isValid,
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
    required String audioFilePath,
  }) async {
    try {
      final startTime = DateTime.now();

      final response = await _client.analyze(
        audioFilePath: audioFilePath,
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
