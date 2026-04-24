import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// Handles app permissions for audio/file operations
class PermissionsManager {
  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    try {
      final status = await Permission.microphone.request();
      AppLogger.info('Microphone permission: ${status.name}');
      return status.isGranted;
    } catch (e) {
      AppLogger.error('Failed to request microphone permission', e);
      return false;
    }
  }

  /// Request storage permission
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    try {
      final status = await Permission.storage.request();
      AppLogger.info('Storage permission: ${status.name}');
      return status.isGranted;
    } catch (e) {
      AppLogger.error('Failed to request storage permission', e);
      return false;
    }
  }

  /// Request media library permission (iOS)
  static Future<bool> requestMediaLibraryPermission() async {
    if (!Platform.isIOS) {
      return true;
    }

    try {
      final status = await Permission.mediaLibrary.request();
      AppLogger.info('Media library permission: ${status.name}');
      return status.isGranted;
    } catch (e) {
      AppLogger.error('Failed to request media library permission', e);
      return false;
    }
  }

  /// Request internet permission (implicit on Android)
  static Future<bool> checkInternetPermission() async {
    // Internet permission is granted by default on Android
    // iOS doesn't require explicit permission
    return true;
  }

  /// Request all required permissions
  static Future<bool> requestAllPermissions() async {
    try {
      final results = await Future.wait([
        requestMicrophonePermission(),
        requestStoragePermission(),
        requestMediaLibraryPermission(),
      ]);

      final allGranted = results.every((granted) => granted);
      AppLogger.info('All permissions requested: $allGranted');
      return allGranted;
    } catch (e) {
      AppLogger.error('Failed to request all permissions', e);
      return false;
    }
  }

  /// Check if microphone permission is granted
  static Future<bool> hasMicrophonePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      AppLogger.warning('Failed to check microphone permission', e);
      return false;
    }
  }

  /// Check if storage permission is granted
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    try {
      final status = await Permission.storage.status;
      return status.isGranted;
    } catch (e) {
      AppLogger.warning('Failed to check storage permission', e);
      return false;
    }
  }

  /// Open app settings to enable permissions
  static Future<void> openAppSettings() async {
    try {
      await openAppSettings();
      AppLogger.info('Opened app settings');
    } catch (e) {
      AppLogger.warning('Failed to open app settings', e);
    }
  }
}
