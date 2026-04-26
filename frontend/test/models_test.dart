import 'package:flutter_test/flutter_test.dart';
import 'package:audioguard_mobile/models/watermark_model.dart';

void main() {
  group('AudioMetadata Tests', () {
    test('AudioMetadata durationString formats correctly', () {
      final metadata = AudioMetadata(
        filename: 'test.wav',
        duration: const Duration(minutes: 2, seconds: 30),
        sampleRate: 44100,
        bitrate: 192000,
        fileSize: 1024000,
        format: 'WAV',
      );

      expect(metadata.durationString, '2:30');
    });

    test('AudioMetadata durationString pads seconds', () {
      final metadata = AudioMetadata(
        filename: 'test.wav',
        duration: const Duration(minutes: 1, seconds: 5),
        sampleRate: 44100,
        bitrate: 192000,
        fileSize: 512000,
        format: 'WAV',
      );

      expect(metadata.durationString, '1:05');
    });

    test('AudioMetadata has loadedAt timestamp', () {
      final beforeCreation = DateTime.now();
      final metadata = AudioMetadata(
        filename: 'test.wav',
        duration: const Duration(seconds: 60),
        sampleRate: 44100,
        bitrate: 192000,
        fileSize: 512000,
        format: 'WAV',
      );
      final afterCreation = DateTime.now().add(const Duration(milliseconds: 1));

      expect(metadata.loadedAt.isAfter(beforeCreation), true);
      expect(metadata.loadedAt.isBefore(afterCreation), true);
    });
  });

  group('EncodingResult Tests', () {
    test('EncodingResult has required fields', () {
      final result = EncodingResult(
        id: 'test-id',
        encodedFilePath: '/path/to/output.wav',
        processingTime: const Duration(seconds: 2),
        mode: 'local',
        confidence: 0.95,
        originalFileSize: 1024000,
        encodedFileSize: 1024000,
      );

      expect(result.id, 'test-id');
      expect(result.encodedFilePath, '/path/to/output.wav');
      expect(result.mode, 'local');
      expect(result.confidence, 0.95);
    });

    test('EncodingResult generates unique ID if not provided', () {
      final result1 = EncodingResult(
        encodedFilePath: '/path/to/output.wav',
        processingTime: const Duration(seconds: 1),
        mode: 'local',
        confidence: 0.9,
        originalFileSize: 512000,
        encodedFileSize: 512000,
      );

      final result2 = EncodingResult(
        encodedFilePath: '/path/to/output.wav',
        processingTime: const Duration(seconds: 1),
        mode: 'local',
        confidence: 0.9,
        originalFileSize: 512000,
        encodedFileSize: 512000,
      );

      expect(result1.id != result2.id, true);
    });
  });

  group('DecodingResult Tests', () {
    test('DecodingResult has required fields', () {
      const message = 'extracted message';
      final result = DecodingResult(
        id: 'test-id',
        message: message,
        confidence: 0.95,
        mode: 'cloud',
        processingTime: const Duration(seconds: 1),
      );

      expect(result.id, 'test-id');
      expect(result.message, message);
      expect(result.confidence, 0.95);
      expect(result.mode, 'cloud');
    });

    test('DecodingResult confidence is clamped 0-1', () {
      final result = DecodingResult(
        message: 'test',
        confidence: 0.5,
        mode: 'local',
        processingTime: const Duration(seconds: 1),
      );

      expect(result.confidence >= 0, true);
      expect(result.confidence <= 1, true);
    });
  });

  group('VerifyResult Tests', () {
    test('VerifyResult has required fields', () {
      final result = VerifyResult(
        isValid: true,
        confidence: 0.92,
        detectedMessage: WatermarkMessage(message: 'expected'),
        mode: 'hybrid',
        processingTime: const Duration(milliseconds: 500),
      );

      expect(result.isValid, true);
      expect(result.confidence, 0.92);
      expect(result.detectedMessage?.message, 'expected');
      expect(result.mode, 'hybrid');
    });

    test('VerifyResult message returns detected message', () {
      final detectedMsg = WatermarkMessage(message: 'detected');
      final result = VerifyResult(
        isValid: true,
        confidence: 0.85,
        detectedMessage: detectedMsg,
        mode: 'local',
        processingTime: const Duration(seconds: 1),
      );

      expect(result.detectedMessage?.message, detectedMsg.message);
    });
  });

  group('AnalysisResult Tests', () {
    test('AnalysisResult has confidence getter', () {
      final result = AnalysisResult(
        watermarkPresent: true,
        signalStrength: 0.78,
        spectralInfo: {'frequency': 8000},
        mode: 'local',
        processingTime: const Duration(seconds: 1),
      );

      expect(result.confidence, 0.78);
    });

    test('AnalysisResult generates unique ID', () {
      final result1 = AnalysisResult(
        watermarkPresent: false,
        signalStrength: 0.2,
        spectralInfo: {},
        mode: 'cloud',
        processingTime: const Duration(seconds: 1),
      );

      final result2 = AnalysisResult(
        watermarkPresent: false,
        signalStrength: 0.2,
        spectralInfo: {},
        mode: 'cloud',
        processingTime: const Duration(seconds: 1),
      );

      expect(result1.id != result2.id, true);
    });

    test('AnalysisResult has timestamp', () {
      final beforeCreation = DateTime.now();
      final result = AnalysisResult(
        watermarkPresent: true,
        signalStrength: 0.5,
        spectralInfo: {},
        mode: 'local',
        processingTime: const Duration(seconds: 1),
      );
      final afterCreation = DateTime.now().add(const Duration(milliseconds: 1));

      expect(result.timestamp.isAfter(beforeCreation), true);
      expect(result.timestamp.isBefore(afterCreation), true);
    });
  });

  group('ProcessingError Tests', () {
    test('ProcessingError has all fields', () {
      final error = ProcessingError(
        message: 'Test error',
        code: 'TEST_ERROR',
      );

      expect(error.message, 'Test error');
      expect(error.code, 'TEST_ERROR');
    });

    test('ProcessingError toString includes code and message', () {
      final error = ProcessingError(
        message: 'Something went wrong',
        code: 'ERROR_CODE',
      );

      expect(error.toString(), contains('ERROR_CODE'));
      expect(error.toString(), contains('Something went wrong'));
    });
  });
}
