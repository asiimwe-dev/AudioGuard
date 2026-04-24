import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/watermark_model.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Audio file handling service
class AudioService {
  static const List<String> _supportedFormats = ['wav', 'mp3', 'm4a', 'ogg'];

  /// Pick audio file from device storage
  Future<File?> pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final fileSize = await file.length();

        // Validate file size
        if (fileSize > AppConstants.maxAudioFileSizeBytes) {
          AppLogger.warning(
            'Audio file exceeds max size: $fileSize bytes',
          );
          throw ProcessingError(
            message: AppConstants.errorFileTooLarge,
            code: 'FILE_TOO_LARGE',
          );
        }

        if (fileSize < AppConstants.minAudioFileSizeBytes) {
          AppLogger.warning(
            'Audio file is too small: $fileSize bytes',
          );
          throw ProcessingError(
            message: AppConstants.errorFileTooSmall,
            code: 'FILE_TOO_SMALL',
          );
        }

        AppLogger.info('✅ Audio file selected: ${file.path}');
        return file;
      }
    } catch (e) {
      AppLogger.error('Failed to pick audio file', e);
      rethrow;
    }

    return null;
  }

  /// Validate audio file format
  bool isValidAudioFormat(String filePath) {
    final extension = _getFileExtension(filePath).toLowerCase();
    return _supportedFormats.contains(extension);
  }

  /// Get file extension
  String _getFileExtension(String filePath) {
    return filePath.split('.').last;
  }

  /// Get audio file metadata (duration, sample rate, etc.)
  /// Note: Requires native implementation or using FFmpeg plugin
  /// This is a placeholder that would integrate with native code
  Future<AudioMetadata?> getAudioMetadata(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw ProcessingError(
          message: 'Audio file not found',
          code: 'FILE_NOT_FOUND',
        );
      }

      // Validate format
      if (!isValidAudioFormat(filePath)) {
        throw ProcessingError(
          message: AppConstants.errorInvalidAudioFile,
          code: 'INVALID_FORMAT',
        );
      }

      final fileSize = await file.length();
      final filename = file.path.split('/').last;

      // Placeholder metadata - would be extracted from actual audio file
      // In production, use flutter_audio_service or ffmpeg_kit_flutter
      final metadata = AudioMetadata(
        filename: filename,
        duration: const Duration(seconds: 60), // Placeholder
        sampleRate: 44100,                      // Placeholder
        bitrate: 128,                           // Placeholder
        fileSize: fileSize,
        format: _getFileExtension(filePath).toUpperCase(),
      );

      AppLogger.logAudioMetadata(
        filename: metadata.filename,
        duration: metadata.duration,
        sampleRate: metadata.sampleRate,
        bitrate: metadata.bitrate,
      );

      return metadata;
    } catch (e) {
      AppLogger.error('Failed to get audio metadata', e);
      rethrow;
    }
  }

  /// Get temp directory for storing encoded/decoded files
  Future<String> getTempDirectory() async {
    try {
      final tempDir = await getTemporaryDirectory();
      return tempDir.path;
    } catch (e) {
      AppLogger.error('Failed to get temp directory', e);
      rethrow;
    }
  }

  /// Get app documents directory
  Future<String> getAppDocumentsDirectory() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      return docDir.path;
    } catch (e) {
      AppLogger.error('Failed to get app documents directory', e);
      rethrow;
    }
  }

  /// Save processed audio file
  Future<File> saveAudioFile({
    required String sourceFilePath,
    required String outputFileName,
    bool useAppDir = true,
  }) async {
    try {
      final sourceFile = File(sourceFilePath);

      if (!await sourceFile.exists()) {
        throw ProcessingError(
          message: 'Source file not found',
          code: 'SOURCE_FILE_NOT_FOUND',
        );
      }

      final baseDir = useAppDir
          ? await getAppDocumentsDirectory()
          : await getTempDirectory();

      final outputFile = File('$baseDir/$outputFileName');

      // Ensure directory exists
      await outputFile.parent.create(recursive: true);

      // Copy file
      await sourceFile.copy(outputFile.path);

      AppLogger.info(
        '✅ Audio file saved: ${outputFile.path}',
      );

      return outputFile;
    } catch (e) {
      AppLogger.error('Failed to save audio file', e);
      rethrow;
    }
  }

  /// Delete audio file
  Future<void> deleteAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.debug('✅ Audio file deleted: $filePath');
      }
    } catch (e) {
      AppLogger.warning('Failed to delete audio file: $filePath', e);
    }
  }

  /// Clean up temp files
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = Directory(await getTempDirectory());
      if (await tempDir.exists()) {
        final files = tempDir.listSync();
        for (final file in files) {
          if (file is File) {
            await file.delete();
          }
        }
        AppLogger.debug('✅ Temp files cleaned up');
      }
    } catch (e) {
      AppLogger.warning('Failed to cleanup temp files', e);
    }
  }

  /// Get human-readable file size
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// List all audio files in app directory
  Future<List<File>> listAudioFiles() async {
    try {
      final appDir = Directory(await getAppDocumentsDirectory());
      final files = <File>[];

      if (await appDir.exists()) {
        final items = appDir.listSync();
        for (final item in items) {
          if (item is File && isValidAudioFormat(item.path)) {
            files.add(item);
          }
        }
      }

      AppLogger.info('Found ${files.length} audio files');
      return files;
    } catch (e) {
      AppLogger.error('Failed to list audio files', e);
      return [];
    }
  }
}
