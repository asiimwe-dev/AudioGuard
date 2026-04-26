import 'package:uuid/uuid.dart';

/// Represents metadata about an audio file
class AudioMetadata {
  final String filename;
  final Duration duration;
  final int sampleRate;
  final int bitrate;
  final int fileSize;
  final String format;
  final DateTime loadedAt;

  AudioMetadata({
    required this.filename,
    required this.duration,
    required this.sampleRate,
    required this.bitrate,
    required this.fileSize,
    required this.format,
    DateTime? loadedAt,
  }) : loadedAt = loadedAt ?? DateTime.now();

  /// Get human-readable duration string
  String get durationString {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final paddedSeconds = seconds.toString().padLeft(2, '0');
    return '$minutes:$paddedSeconds';
  }

  /// Get human-readable file size
  String get fileSizeString {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  String toString() =>
      'AudioMetadata($filename, $durationString, ${sampleRate}Hz, $fileSizeString)';
}

/// Represents a watermark message with metadata
class WatermarkMessage {
  final String id;
  final String message;
  final DateTime timestamp;
  final String? author;
  final String? metadata;

  WatermarkMessage({
    String? id,
    required this.message,
    DateTime? timestamp,
    this.author,
    this.metadata,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'author': author,
        'metadata': metadata,
      };

  factory WatermarkMessage.fromJson(Map<String, dynamic> json) =>
      WatermarkMessage(
        id: json['id'] as String?,
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        author: json['author'] as String?,
        metadata: json['metadata'] as String?,
      );

  @override
  String toString() => 'WatermarkMessage($id, "$message", $author)';
}

/// Result of encoding operation
class EncodingResult {
  final String id;
  final String encodedFilePath;
  final String? fileId; // Server-assigned file ID for subsequent operations
  final Duration processingTime;
  final String mode; // 'local', 'cloud', 'hybrid'
  final double confidence;
  final int originalFileSize;
  final int encodedFileSize;
  final DateTime timestamp;
  final bool success;

  EncodingResult({
    String? id,
    required this.encodedFilePath,
    this.fileId,
    required this.processingTime,
    required this.mode,
    required this.confidence,
    required this.originalFileSize,
    required this.encodedFileSize,
    DateTime? timestamp,
    bool? success,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        success = success ?? (encodedFilePath.isNotEmpty || fileId != null);

  /// Size increase percentage
  double get sizeIncreasePercent =>
      ((encodedFileSize - originalFileSize) / originalFileSize) * 100;

  @override
  String toString() =>
      'EncodingResult($mode, ${processingTime.inMilliseconds}ms, ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Result of decoding operation
class DecodingResult {
  final String id;
  final String? message;
  final double confidence;
  final String mode; // 'local', 'cloud', 'hybrid'
  final Duration processingTime;
  final List<String> suggestions; // auto-detected alternatives
  final DateTime timestamp;
  final bool success;

  DecodingResult({
    String? id,
    this.message,
    required this.confidence,
    required this.mode,
    required this.processingTime,
    List<String>? suggestions,
    DateTime? timestamp,
    bool? success,
  })  : id = id ?? const Uuid().v4(),
        suggestions = suggestions ?? [],
        timestamp = timestamp ?? DateTime.now(),
        success = success ?? (message != null && confidence > 0.5);

  @override
  String toString() =>
      'DecodingResult("$message", ${(confidence * 100).toStringAsFixed(1)}%, $mode)';
}

/// Result of verification operation
class VerifyResult {
  final String id;
  final bool isValid;
  final double confidence;
  final WatermarkMessage? detectedMessage;
  final String mode; // 'local', 'cloud', 'hybrid'
  final Duration processingTime;
  final DateTime timestamp;

  VerifyResult({
    String? id,
    required this.isValid,
    required this.confidence,
    this.detectedMessage,
    required this.mode,
    required this.processingTime,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'VerifyResult(${isValid ? 'VALID' : 'INVALID'}, ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Result of audio analysis operation
class AnalysisResult {
  final String id;
  final bool watermarkPresent;
  final double signalStrength;
  final Map<String, dynamic> spectralInfo;
  final String mode; // 'local', 'cloud', 'hybrid'
  final Duration processingTime;
  final DateTime timestamp;

  AnalysisResult({
    String? id,
    required this.watermarkPresent,
    required this.signalStrength,
    required this.spectralInfo,
    required this.mode,
    required this.processingTime,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'AnalysisResult(watermarkPresent: $watermarkPresent, strength: ${(signalStrength * 100).toStringAsFixed(1)}%)';

  /// Get confidence level (same as signalStrength)
  double get confidence => signalStrength;
}

/// Error response from API or local processing
class ProcessingError implements Exception {
  final String message;
  final String code;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final String? details;

  ProcessingError({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
    this.details,
  });

  @override
  String toString() => 'ProcessingError($code): $message';
}
