import 'dart:io';
import 'package:dio/dio.dart';
import '../models/watermark_model.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../utils/circuit_breaker.dart';
import './config_service.dart';

/// API Response Models

class EncodeResponse {
  final bool success;
  final String fileId;
  final double embeddingStrength;
  final int processingTimeMs;
  final String? message;
  final double? originalDuration;
  final int? sampleRate;
  final int? messageLength;

  EncodeResponse({
    required this.success,
    required this.fileId,
    required this.embeddingStrength,
    required this.processingTimeMs,
    this.message,
    this.originalDuration,
    this.sampleRate,
    this.messageLength,
  });

  factory EncodeResponse.fromJson(Map<String, dynamic> json) => EncodeResponse(
        success: json['success'] as bool,
        fileId: json['file_id'] as String,
        embeddingStrength: (json['embedding_strength'] as num).toDouble(),
        processingTimeMs: (json['processing_time_ms'] as num).toInt(),
        message: json['message'] as String?,
        originalDuration: json['original_duration'] != null 
          ? (json['original_duration'] as num).toDouble() 
          : null,
        sampleRate: json['sample_rate'] as int?,
        messageLength: json['message_length'] as int?,
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
  final List<dynamic> modelsAvailable;
  final double uptimeSeconds;

  HealthResponse({
    required this.status,
    required this.version,
    required this.modelsAvailable,
    required this.uptimeSeconds,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) =>
      HealthResponse(
        status: json['status'] as String,
        version: json['version'] as String,
        modelsAvailable: json['models_available'] as List<dynamic>,
        uptimeSeconds: (json['uptime_seconds'] as num).toDouble(),
      );
}

/// REST API Client for AudioGuard Backend (no code generation)
class AudioGuardApiClient {
  final Dio dio;
  
  // Circuit breakers for each endpoint
  late final CircuitBreaker _healthBreaker;
  late final CircuitBreaker _encodeBreaker;
  late final CircuitBreaker _decodeBreaker;
  late final CircuitBreaker _verifyBreaker;
  late final CircuitBreaker _analyzeBreaker;

  AudioGuardApiClient({
    required this.dio,
  }) {
    _healthBreaker = CircuitBreaker(name: 'health');
    _encodeBreaker = CircuitBreaker(name: 'encode');
    _decodeBreaker = CircuitBreaker(name: 'decode');
    _verifyBreaker = CircuitBreaker(name: 'verify');
    _analyzeBreaker = CircuitBreaker(name: 'analyze');
  }

  /// Check API health
  Future<HealthResponse> getHealth() async {
    if (!_healthBreaker.canAttempt()) {
      throw ProcessingError(
        message: 'Health check temporarily unavailable (circuit open)',
        code: 'HEALTH_CHECK_FAILED',
        originalError: _healthBreaker.toString(),
      );
    }
    
    try {
      final response = await dio.get(AppConstants.healthEndpoint);
      _healthBreaker.recordSuccess();
      return HealthResponse.fromJson(response.data);
    } catch (e) {
      _healthBreaker.recordFailure();
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
    if (!_encodeBreaker.canAttempt()) {
      throw ProcessingError(
        message: 'Encoding temporarily unavailable (backend recovering)',
        code: 'ENCODING_FAILED',
        originalError: _encodeBreaker.toString(),
      );
    }
    
    try {
      // Validate file exists
      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw ProcessingError(
          message: 'Audio file not found',
          code: 'FILE_NOT_FOUND',
          originalError: 'File does not exist at: $audioFilePath',
        );
      }

      // Validate file is not empty
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw ProcessingError(
          message: 'Audio file is empty',
          code: 'EMPTY_FILE',
          originalError: 'File size is 0 bytes',
        );
      }

      // Validate message
      if (message.isEmpty || message.length > 255) {
        throw ProcessingError(
          message: 'Message must be 1-255 characters',
          code: 'INVALID_MESSAGE',
          originalError: 'Message length: ${message.length}',
        );
      }

      final formData = FormData.fromMap({
        'audio_file': await MultipartFile.fromFile(audioFilePath),
        'message': message,
        if (messageLength != null) 'message_length': messageLength,
      });

      final endpoint = AppConstants.encodeEndpoint;
      
      final response = await dio.post(
        endpoint,
        data: formData,
      );

      if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
        _encodeBreaker.recordFailure();
        throw ProcessingError(
          message: 'Encoding failed with status ${response.statusCode}: ${response.data}',
          code: 'ENCODING_FAILED',
          originalError: response.data,
        );
      }

      if (response.data == null) {
        _encodeBreaker.recordFailure();
        throw ProcessingError(
          message: 'Encoding failed: empty response',
          code: 'ENCODING_FAILED',
          originalError: 'No data in response',
        );
      }

      final result = EncodeResponse.fromJson(response.data as Map<String, dynamic>);
      _encodeBreaker.recordSuccess();
      return result;
    } on ProcessingError {
      _encodeBreaker.recordFailure();
      rethrow;
    } catch (e) {
      _encodeBreaker.recordFailure();
      throw ProcessingError(
        message: 'Encoding failed: $e',
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
    if (!_decodeBreaker.canAttempt()) {
      throw ProcessingError(
        message: 'Decoding temporarily unavailable (backend recovering)',
        code: 'DECODING_FAILED',
        originalError: _decodeBreaker.toString(),
      );
    }
    
    try {
      final requestBody = {
        'file_id': fileId,
        'use_cnn': false,
        'confidence_threshold': ConfigService().getDecodeConfidenceThreshold(),
        'max_message_length': messageLength ?? AppConstants.maxMessageLength,
      };

      final response = await dio.post(
        AppConstants.decodeEndpoint,
        data: requestBody,
      );

      final result = DecodeResponse.fromJson(response.data);
      _decodeBreaker.recordSuccess();
      return result;
    } on ProcessingError {
      _decodeBreaker.recordFailure();
      rethrow;
    } catch (e) {
      _decodeBreaker.recordFailure();
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
    if (!_verifyBreaker.canAttempt()) {
      throw ProcessingError(
        message: 'Verification temporarily unavailable (backend recovering)',
        code: 'VERIFICATION_FAILED',
        originalError: _verifyBreaker.toString(),
      );
    }
    
    try {
      final requestBody = {
        'file_id': fileId,
        'expected_message': message,
        'confidence_threshold': ConfigService().getVerifyConfidenceThreshold(),
        'max_message_length': AppConstants.maxMessageLength,
      };

      final response = await dio.post(
        AppConstants.verifyEndpoint,
        data: requestBody,
      );

      final result = VerifyResponse.fromJson(response.data);
      _verifyBreaker.recordSuccess();
      return result;
    } on ProcessingError {
      _verifyBreaker.recordFailure();
      rethrow;
    } catch (e) {
      _verifyBreaker.recordFailure();
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
    if (!_analyzeBreaker.canAttempt()) {
      throw ProcessingError(
        message: 'Analysis temporarily unavailable (backend recovering)',
        code: 'ANALYSIS_FAILED',
        originalError: _analyzeBreaker.toString(),
      );
    }
    
    try {
      final requestBody = {
        'file_id': fileId,
        'confidence_threshold': ConfigService().getAnalyzeConfidenceThreshold(),
        'max_message_length': AppConstants.maxMessageLength,
      };

      final response = await dio.post(
        AppConstants.analyzeEndpoint,
        data: requestBody,
      );

      final result = AnalyzeResponse.fromJson(response.data);
      _analyzeBreaker.recordSuccess();
      return result;
    } on ProcessingError {
      _analyzeBreaker.recordFailure();
      rethrow;
    } catch (e) {
      _analyzeBreaker.recordFailure();
      throw ProcessingError(
        message: 'Analysis failed',
        code: 'ANALYSIS_FAILED',
        originalError: e,
      );
    }
  }

  /// Download watermarked audio file
  Future<void> downloadFile({
    required String fileId,
    required String savePath,
  }) async {
    try {
      final response = await dio.get(
        '/api/v1/download/$fileId',
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      // Write bytes to file
      final file = File(savePath);
      await file.writeAsBytes(response.data);
    } catch (e) {
      throw ProcessingError(
        message: 'File download failed',
        code: 'DOWNLOAD_FAILED',
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
    final apiTimeout = ConfigService().getApiTimeout();
    final uploadTimeout = ConfigService().getFileUploadTimeout();
    
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: Duration(seconds: apiTimeout),
        receiveTimeout: Duration(seconds: uploadTimeout), // Use upload timeout for receive
        sendTimeout: Duration(seconds: uploadTimeout),     // Use upload timeout for send
        headers: {
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Configure SSL/TLS for HTTPS connections (fixes Android 12 cert issues)
    (_dio.httpClientAdapter as dynamic).onHttpClientCreate = (HttpClient httpClient) {
      httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Accept certificates from onrender.com and subdomains
        return host.contains('onrender.com') || host.contains('audioguard');
      };
      return httpClient;
    };

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

    _client = AudioGuardApiClient(dio: _dio);
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
      ).timeout(Duration(seconds: ConfigService().getFileUploadTimeout()));

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

  /// Upload audio file and get fileId (without encoding)
  /// Used for files from library that need fileId for verification/analysis/decode
  Future<String> uploadAudioFile({
    required String audioFilePath,
  }) async {
    try {
      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw ProcessingError(
          message: 'File not found',
          code: 'FILE_NOT_FOUND',
          details: audioFilePath,
        );
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioFilePath,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        AppConstants.uploadEndpoint,
        data: formData,
      );

      if (response.statusCode == 200 && response.data is Map) {
        final fileId = response.data['file_id'] as String?;
        if (fileId != null && fileId.isNotEmpty) {
          AppLogger.info('File uploaded successfully, fileId: $fileId');
          return fileId;
        }
      }

      throw ProcessingError(
        message: 'Failed to upload file',
        code: 'UPLOAD_FAILED',
        details: 'No file_id in response',
      );
    } catch (e) {
      AppLogger.error('File upload failed', e);
      throw ProcessingError(
        message: 'Failed to upload file',
        code: 'UPLOAD_FAILED',
        originalError: e,
      );
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
      ).timeout(Duration(seconds: ConfigService().getFileUploadTimeout()));

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
      ).timeout(Duration(seconds: ConfigService().getFileUploadTimeout()));

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
      ).timeout(Duration(seconds: ConfigService().getFileUploadTimeout()));

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

  /// Download watermarked audio file
  Future<void> downloadFile({
    required String fileId,
    required String savePath,
  }) async {
    try {
      AppLogger.info('Downloading file: $fileId to $savePath');
      await _client.downloadFile(fileId: fileId, savePath: savePath);
      AppLogger.info('File downloaded successfully: $savePath');
    } catch (e) {
      AppLogger.error('File download failed', e);
      rethrow;
    }
  }

  void dispose() {
    _dio.close();
  }
}
