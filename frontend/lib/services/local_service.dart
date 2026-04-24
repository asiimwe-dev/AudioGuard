import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import '../models/watermark_model.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// TensorFlow Lite service for local watermark processing
class LocalService {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  /// Load TFLite model from assets
  Future<void> loadModel() async {
    if (_isModelLoaded) return;

    try {
      AppLogger.info('Loading TFLite model...');

      _interpreter = await Interpreter.fromAsset(
        AppConstants.tfliteModelPath,
      );

      _isModelLoaded = true;
      AppLogger.info('✅ TFLite model loaded successfully');
    } catch (e) {
      AppLogger.error('Failed to load TFLite model', e);
      _isModelLoaded = false;
      rethrow;
    }
  }

  /// Check if model is loaded
  bool isModelReady() => _isModelLoaded && _interpreter != null;

  /// Run TFLite inference for encoding
  /// Input: audio samples (Float32List)
  /// Output: encoded audio with watermark
  Future<List<double>> encodeLocal({
    required List<double> audioSamples,
    required String message,
    double amplitudeFactor = AppConstants.defaultAmplitudeFactor,
  }) async {
    if (!isModelReady()) {
      throw ProcessingError(
        message: AppConstants.errorTfliteModelNotLoaded,
        code: 'MODEL_NOT_LOADED',
      );
    }

    try {
      final startTime = DateTime.now();
      AppLogger.info('Starting local encoding...');

      // Prepare input
      final input = [Float32List.fromList(audioSamples)];

      // Prepare output buffer (same size as input)
      final output = [Float32List(audioSamples.length)];

      // Run inference
      _interpreter!.run(input, output);

      final duration = DateTime.now().difference(startTime);

      AppLogger.logWatermarkOperation(
        operation: 'encode',
        mode: 'local',
        processingTime: duration,
        confidence: 0.95, // Placeholder
      );

      return output[0].toList();
    } catch (e) {
      AppLogger.error('Local encoding failed', e);
      throw ProcessingError(
        message: 'Local encoding failed: $e',
        code: 'ENCODING_FAILED',
        originalError: e,
      );
    }
  }

  /// Run TFLite inference for decoding
  /// Input: encoded audio samples
  /// Output: extracted watermark message + confidence
  Future<DecodingResult> decodeLocal({
    required List<double> audioSamples,
    int? messageLength,
  }) async {
    if (!isModelReady()) {
      throw ProcessingError(
        message: AppConstants.errorTfliteModelNotLoaded,
        code: 'MODEL_NOT_LOADED',
      );
    }

    try {
      final startTime = DateTime.now();
      AppLogger.info('Starting local decoding...');

      // Prepare input
      final input = [Float32List.fromList(audioSamples)];

      // Prepare output buffers:
      // [0] = message bits (variable length)
      // [1] = confidence score
      final messageOutput = Float32List(256); // Max 256 chars
      final confidenceOutput = Float32List(1);
      final outputs = {
        0: messageOutput,
        1: confidenceOutput,
      };

      // Run inference
      _interpreter!.runForMultipleInputs([input], outputs);

      final duration = DateTime.now().difference(startTime);
      final confidence = confidenceOutput[0];

      // Reconstruct message from bits (placeholder)
      final message = _reconstructMessage(messageOutput, messageLength);

      AppLogger.logWatermarkOperation(
        operation: 'decode',
        mode: 'local',
        processingTime: duration,
        confidence: confidence,
      );

      return DecodingResult(
        message: message,
        confidence: confidence,
        mode: 'local',
        processingTime: duration,
        success: message != null && confidence > 0.5,
      );
    } catch (e) {
      AppLogger.error('Local decoding failed', e);
      throw ProcessingError(
        message: 'Local decoding failed: $e',
        code: 'DECODING_FAILED',
        originalError: e,
      );
    }
  }

  /// Verify watermark presence
  Future<VerifyResult> verifyLocal({
    required List<double> audioSamples,
    required String expectedMessage,
  }) async {
    if (!isModelReady()) {
      throw ProcessingError(
        message: AppConstants.errorTfliteModelNotLoaded,
        code: 'MODEL_NOT_LOADED',
      );
    }

    try {
      final startTime = DateTime.now();
      AppLogger.info('Starting local verification...');

      // Run decoding first
      final decodingResult = await decodeLocal(
        audioSamples: audioSamples,
        messageLength: expectedMessage.length,
      );

      final isValid = decodingResult.message == expectedMessage &&
          decodingResult.confidence > 0.7;

      final duration = DateTime.now().difference(startTime);

      AppLogger.logWatermarkOperation(
        operation: 'verify',
        mode: 'local',
        processingTime: duration,
        confidence: isValid ? decodingResult.confidence : 0.0,
      );

      return VerifyResult(
        isValid: isValid,
        confidence: decodingResult.confidence,
        detectedMessage: isValid
            ? WatermarkMessage(
                message: decodingResult.message!,
              )
            : null,
        mode: 'local',
        processingTime: duration,
      );
    } catch (e) {
      AppLogger.error('Local verification failed', e);
      throw ProcessingError(
        message: 'Local verification failed: $e',
        code: 'VERIFICATION_FAILED',
        originalError: e,
      );
    }
  }

  /// Analyze audio for watermark presence
  Future<AnalysisResult> analyzeLocal({
    required List<double> audioSamples,
  }) async {
    if (!isModelReady()) {
      throw ProcessingError(
        message: AppConstants.errorTfliteModelNotLoaded,
        code: 'MODEL_NOT_LOADED',
      );
    }

    try {
      final startTime = DateTime.now();
      AppLogger.info('Starting local analysis...');

      // Prepare input
      final input = [Float32List.fromList(audioSamples)];

      // Prepare output buffers:
      // [0] = watermark presence (0-1)
      // [1] = signal strength (0-1)
      // [2] = spectral info (variable)
      final watermarkOutput = Float32List(1);
      final strengthOutput = Float32List(1);
      final spectralOutput = Float32List(256);
      final outputs = {
        0: watermarkOutput,
        1: strengthOutput,
        2: spectralOutput,
      };

      // Run inference
      _interpreter!.runForMultipleInputs([input], outputs);

      final duration = DateTime.now().difference(startTime);
      final watermarkPresent = watermarkOutput[0] > 0.5;
      final signalStrength = strengthOutput[0];

      AppLogger.logWatermarkOperation(
        operation: 'analyze',
        mode: 'local',
        processingTime: duration,
        confidence: signalStrength,
      );

      return AnalysisResult(
        watermarkPresent: watermarkPresent,
        signalStrength: signalStrength,
        spectralInfo: {
          'frequency_bins': 256,
          'watermark_present': watermarkPresent,
          'signal_strength': signalStrength,
        },
        mode: 'local',
        processingTime: duration,
      );
    } catch (e) {
      AppLogger.error('Local analysis failed', e);
      throw ProcessingError(
        message: 'Local analysis failed: $e',
        code: 'ANALYSIS_FAILED',
        originalError: e,
      );
    }
  }

  /// Reconstruct message from bit output
  String? _reconstructMessage(Float32List bits, int? expectedLength) {
    try {
      // This is a placeholder - actual implementation would:
      // 1. Threshold the bits (> 0.5 = 1, < 0.5 = 0)
      // 2. Decode using error correction
      // 3. Convert binary to ASCII characters

      if (expectedLength != null && expectedLength > 0) {
        // Use expected length for decoding
        final charBits = <int>[];
        for (int i = 0; i < expectedLength * 8 && i < bits.length; i++) {
          charBits.add(bits[i] > 0.5 ? 1 : 0);
        }

        final chars = <String>[];
        for (int i = 0; i < charBits.length; i += 8) {
          if (i + 8 <= charBits.length) {
            int charCode = 0;
            for (int j = 0; j < 8; j++) {
              charCode = (charCode << 1) | charBits[i + j];
            }
            if (charCode >= 32 && charCode <= 126) {
              chars.add(String.fromCharCode(charCode));
            }
          }
        }

        return chars.join();
      }
    } catch (e) {
      AppLogger.warning('Failed to reconstruct message', e);
    }

    return null;
  }

  /// Get model input/output shapes
  Map<String, dynamic> getModelInfo() {
    if (!isModelReady()) {
      return {'loaded': false};
    }

    try {
      return {
        'loaded': true,
        'inputs': _interpreter!.getInputTensors().length,
        'outputs': _interpreter!.getOutputTensors().length,
        'model_path': AppConstants.tfliteModelPath,
      };
    } catch (e) {
      AppLogger.error('Failed to get model info', e);
      return {'loaded': true, 'error': e.toString()};
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      if (_interpreter != null) {
        _interpreter!.close();
      }
      _isModelLoaded = false;
      AppLogger.debug('✅ LocalService disposed');
    } catch (e) {
      AppLogger.warning('Failed to dispose LocalService', e);
    }
  }
}
