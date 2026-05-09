import 'package:uuid/uuid.dart';

/// Represents an encoded audio file in the library
class EncodedAudioFile {
  final String id;
  final String? serverFileId;
  final String filename;
  final String filePath;
  final String message;
  final double amplitudeFactor;
  final String format;
  final int fileSizeBytes;
  final DateTime encodedAt;
  final String? originalFilename;

  EncodedAudioFile({
    String? id,
    this.serverFileId,
    required this.filename,
    required this.filePath,
    required this.message,
    required this.amplitudeFactor,
    required this.format,
    required this.fileSizeBytes,
    DateTime? encodedAt,
    this.originalFilename,
  })  : id = id ?? const Uuid().v4(),
        encodedAt = encodedAt ?? DateTime.now();

  /// Get human-readable file size
  String get fileSizeString {
    if (fileSizeBytes < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get formatted timestamp
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fileDate = DateTime(encodedAt.year, encodedAt.month, encodedAt.day);

    if (fileDate == today) {
      return 'Today ${encodedAt.hour.toString().padLeft(2, '0')}:${encodedAt.minute.toString().padLeft(2, '0')}';
    } else if (fileDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${encodedAt.hour.toString().padLeft(2, '0')}:${encodedAt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${encodedAt.month.toString().padLeft(2, '0')}/${encodedAt.day.toString().padLeft(2, '0')}/${encodedAt.year}';
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'serverFileId': serverFileId,
        'filename': filename,
        'filePath': filePath,
        'message': message,
        'amplitudeFactor': amplitudeFactor,
        'format': format,
        'fileSizeBytes': fileSizeBytes,
        'encodedAt': encodedAt.toIso8601String(),
        'originalFilename': originalFilename,
      };

  /// Create from JSON
  factory EncodedAudioFile.fromJson(Map<String, dynamic> json) {
    return EncodedAudioFile(
      id: json['id'] as String?,
      serverFileId: json['serverFileId'] as String?,
      filename: json['filename'] as String,
      filePath: json['filePath'] as String,
      message: json['message'] as String,
      amplitudeFactor: (json['amplitudeFactor'] as num).toDouble(),
      format: json['format'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int,
      encodedAt: DateTime.parse(json['encodedAt'] as String),
      originalFilename: json['originalFilename'] as String?,
    );
  }

  /// Create a copy with modified fields
  EncodedAudioFile copyWith({
    String? id,
    String? serverFileId,
    String? filename,
    String? filePath,
    String? message,
    double? amplitudeFactor,
    String? format,
    int? fileSizeBytes,
    DateTime? encodedAt,
    String? originalFilename,
  }) {
    return EncodedAudioFile(
      id: id ?? this.id,
      serverFileId: serverFileId ?? this.serverFileId,
      filename: filename ?? this.filename,
      filePath: filePath ?? this.filePath,
      message: message ?? this.message,
      amplitudeFactor: amplitudeFactor ?? this.amplitudeFactor,
      format: format ?? this.format,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      encodedAt: encodedAt ?? this.encodedAt,
      originalFilename: originalFilename ?? this.originalFilename,
    );
  }

  @override
  String toString() => 'EncodedAudioFile($id, $filename, "$message", $format)';
}
