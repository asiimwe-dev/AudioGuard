import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/file_library_model.dart';
import '../utils/logger.dart';

/// Service for managing encoded audio file library
class FileLibraryService {
  static const String _libraryFileName = 'audioguard_library.json';
  static const String _libraryDirName = 'audioguard_library';
  static const int _maxStoredFiles = 50;

  /// Get the library directory (persistent app storage)
  Future<Directory> _getLibraryDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final libDir = Directory('${docDir.path}/$_libraryDirName');
    
    if (!await libDir.exists()) {
      await libDir.create(recursive: true);
      AppLogger.info('Created library directory: ${libDir.path}');
    }
    
    return libDir;
  }

  /// Get the library index file
  Future<File> _getLibraryIndexFile() async {
    final docDir = await getApplicationDocumentsDirectory();
    return File('${docDir.path}/$_libraryFileName');
  }

  /// Load library index from disk
  Future<List<EncodedAudioFile>> _loadLibraryIndex() async {
    try {
      final indexFile = await _getLibraryIndexFile();
      
      if (!await indexFile.exists()) {
        AppLogger.info('Library index does not exist, starting fresh');
        return [];
      }
      
      final jsonString = await indexFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      return jsonList
          .map((item) => EncodedAudioFile.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to load library index', e);
      return [];
    }
  }

  /// Save library index to disk
  Future<void> _saveLibraryIndex(List<EncodedAudioFile> files) async {
    try {
      final indexFile = await _getLibraryIndexFile();
      final jsonList = files.map((f) => f.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(jsonList), flush: true);
      AppLogger.info('Saved library index with ${files.length} files');
    } catch (e) {
      AppLogger.error('Failed to save library index', e);
      rethrow;
    }
  }

  /// Add an encoded file to the library
  Future<EncodedAudioFile> addEncodedFile({
    required File sourceFile,
    required String message,
    required double amplitudeFactor,
    required String originalFilename,
  }) async {
    try {
      final libDir = await _getLibraryDirectory();
      final fileSize = await sourceFile.length();
      final sourceExt = sourceFile.path.split('.').last.toLowerCase();
      
      // Create a safe filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFilename = 'watermarked_${timestamp}_${originalFilename.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_')}';
      final destPath = '${libDir.path}/$safeFilename';
      
      // Copy file to library
      await sourceFile.copy(destPath);
      AppLogger.info('Copied encoded file to library: $destPath');
      
      // Create metadata
      final encodedFile = EncodedAudioFile(
        filename: safeFilename,
        filePath: destPath,
        message: message,
        amplitudeFactor: amplitudeFactor,
        format: sourceExt.toUpperCase(),
        fileSizeBytes: fileSize,
        originalFilename: originalFilename,
      );
      
      // Update index
      final index = await _loadLibraryIndex();
      index.insert(0, encodedFile); // Add to beginning (newest first)
      
      // Keep only last 50 files
      if (index.length > _maxStoredFiles) {
        final filesToRemove = index.sublist(_maxStoredFiles);
        for (final file in filesToRemove) {
          await _deleteFileFromDisk(file.filePath);
        }
        index.removeRange(_maxStoredFiles, index.length);
      }
      
      await _saveLibraryIndex(index);
      AppLogger.info('Added encoded file to library: ${encodedFile.id}');
      
      return encodedFile;
    } catch (e) {
      AppLogger.error('Failed to add encoded file to library', e);
      rethrow;
    }
  }

  /// Get all encoded files from library
  Future<List<EncodedAudioFile>> getAllEncodedFiles() async {
    try {
      final files = await _loadLibraryIndex();
      
      // Filter out files that don't exist
      final validFiles = <EncodedAudioFile>[];
      for (final file in files) {
        if (await File(file.filePath).exists()) {
          validFiles.add(file);
        } else {
          AppLogger.warning('Library file missing: ${file.filePath}');
        }
      }
      
      // Update index if any files were missing
      if (validFiles.length != files.length) {
        await _saveLibraryIndex(validFiles);
      }
      
      return validFiles;
    } catch (e) {
      AppLogger.error('Failed to get all encoded files', e);
      return [];
    }
  }

  /// Get a specific encoded file by ID
  Future<EncodedAudioFile?> getEncodedFile(String fileId) async {
    try {
      final files = await getAllEncodedFiles();
      return files.firstWhere(
        (f) => f.id == fileId,
        orElse: () => throw 'File not found',
      ) as EncodedAudioFile?;
    } catch (e) {
      AppLogger.warning('Encoded file not found: $fileId');
      return null;
    }
  }

  /// Delete an encoded file from library
  Future<void> deleteEncodedFile(String fileId) async {
    try {
      final files = await _loadLibraryIndex();
      final fileToDelete = files.firstWhere((f) => f.id == fileId);
      
      // Delete from disk
      await _deleteFileFromDisk(fileToDelete.filePath);
      
      // Remove from index
      files.removeWhere((f) => f.id == fileId);
      await _saveLibraryIndex(files);
      
      AppLogger.info('Deleted encoded file: $fileId');
    } catch (e) {
      AppLogger.error('Failed to delete encoded file', e);
      rethrow;
    }
  }

  /// Delete all encoded files from library
  Future<void> clearLibrary() async {
    try {
      final files = await _loadLibraryIndex();
      
      for (final file in files) {
        await _deleteFileFromDisk(file.filePath);
      }
      
      await _saveLibraryIndex([]);
      AppLogger.info('Cleared entire library');
    } catch (e) {
      AppLogger.error('Failed to clear library', e);
      rethrow;
    }
  }

  /// Delete a file from disk safely
  Future<void> _deleteFileFromDisk(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.info('Deleted file: $filePath');
      }
    } catch (e) {
      AppLogger.error('Failed to delete file: $filePath', e);
    }
  }

  /// Get library statistics
  Future<Map<String, dynamic>> getLibraryStats() async {
    try {
      final files = await getAllEncodedFiles();
      int totalSize = 0;
      final formats = <String, int>{};
      
      for (final file in files) {
        totalSize += file.fileSizeBytes;
        formats[file.format] = (formats[file.format] ?? 0) + 1;
      }
      
      return {
        'totalFiles': files.length,
        'totalSizeBytes': totalSize,
        'formats': formats,
        'oldestFile': files.isNotEmpty ? files.last.encodedAt : null,
        'newestFile': files.isNotEmpty ? files.first.encodedAt : null,
      };
    } catch (e) {
      AppLogger.error('Failed to get library stats', e);
      return {};
    }
  }
}
