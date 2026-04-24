import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:audioguard_mobile/services/api_service.dart';
import 'package:audioguard_mobile/models/watermark_model.dart';
import 'package:audioguard_mobile/utils/logger.dart';

/// Smart processing service that handles cloud-first processing
/// 
/// This service implements the following strategy:
/// 1. Check internet connectivity
/// 2. Try cloud processing
/// 3. Provide clear user feedback about which mode was used
class SmartProcessingService {
  final ApiService _cloudService;
  final Connectivity _connectivity;

  SmartProcessingService({
    required ApiService cloudService,
    required Connectivity connectivity,
  })  : _cloudService = cloudService,
        _connectivity = connectivity;

  /// Get current connectivity status
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      AppLogger.warning('Failed to check connectivity: $e');
      return false;
    }
  }

  /// Encode with smart cloud processing
  Future<EncodingResult> encode({
    required String audioFilePath,
    required String message,
    int? messageLength,
  }) async {
    AppLogger.info('Smart Encode: Processing...');
    
    try {
      final result = await _cloudService.encode(
        audioFilePath: audioFilePath,
        message: message,
      );
      return result;
    } catch (e) {
      AppLogger.error('Smart Encode failed: $e');
      rethrow;
    }
  }

  /// Decode with smart cloud processing
  Future<DecodingResult> decode({
    required String audioFilePath,
    int? messageLength,
  }) async {
    AppLogger.info('Smart Decode: Processing...');
    
    try {
      final result = await _cloudService.decode(
        audioFilePath: audioFilePath,
        messageLength: messageLength,
      );
      return result;
    } catch (e) {
      AppLogger.error('Smart Decode failed: $e');
      rethrow;
    }
  }

  /// Verify with smart cloud processing
  Future<VerifyResult> verify({
    required String audioFilePath,
    required String message,
  }) async {
    AppLogger.info('Smart Verify: Processing...');
    
    try {
      final result = await _cloudService.verify(
        audioFilePath: audioFilePath,
        message: message,
      );
      return result;
    } catch (e) {
      AppLogger.error('Smart Verify failed: $e');
      rethrow;
    }
  }

  /// Analyze with smart cloud processing
  Future<AnalysisResult> analyze({
    required String audioFilePath,
  }) async {
    AppLogger.info('Smart Analyze: Processing...');
    
    try {
      final result = await _cloudService.analyze(
        audioFilePath: audioFilePath,
      );
      return result;
    } catch (e) {
      AppLogger.error('Smart Analyze failed: $e');
      rethrow;
    }
  }
}
