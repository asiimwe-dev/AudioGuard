import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/constants.dart';

// ===== Message Validation =====

class MessageValidationError {
  final String message;
  final String code;

  MessageValidationError({
    required this.message,
    required this.code,
  });
}

/// Validate watermark message
final messageValidationProvider =
    Provider.family<MessageValidationError?, String>((ref, message) {
  if (message.isEmpty) {
    return MessageValidationError(
      message: 'Message cannot be empty',
      code: 'EMPTY_MESSAGE',
    );
  }

  if (message.length > AppConstants.maxMessageLength) {
    return MessageValidationError(
      message:
          'Message exceeds ${AppConstants.maxMessageLength} character limit',
      code: 'MESSAGE_TOO_LONG',
    );
  }

  if (message.length < AppConstants.minMessageLength) {
    return MessageValidationError(
      message: 'Message must be at least 1 character',
      code: 'MESSAGE_TOO_SHORT',
    );
  }

  // Check for non-ASCII characters
  try {
    message.codeUnits; // This checks if all chars are valid
    return null; // Valid
  } catch (_) {
    return MessageValidationError(
      message: 'Message contains invalid characters',
      code: 'INVALID_CHARACTERS',
    );
  }
});

// ===== Recent Files =====

class RecentFile {
  final String path;
  final String filename;
  final DateTime lastModified;
  final int fileSize;

  RecentFile({
    required this.path,
    required this.filename,
    required this.lastModified,
    required this.fileSize,
  });
}

class RecentFilesNotifier extends StateNotifier<List<RecentFile>> {
  static const int maxRecentFiles = 20;

  RecentFilesNotifier() : super([]);

  void addFile(RecentFile file) {
    state = state.where((f) => f.path != file.path).toList();
    state = [file, ...state];
    if (state.length > maxRecentFiles) {
      state = state.sublist(0, maxRecentFiles);
    }
  }

  void removeFile(String path) {
    state = state.where((f) => f.path != path).toList();
  }

  void clearRecent() {
    state = [];
  }
}

final recentFilesProvider =
    StateNotifierProvider<RecentFilesNotifier, List<RecentFile>>((ref) {
  return RecentFilesNotifier();
});

// ===== Screen Navigation =====

enum CurrentScreen {
  home,
  encode,
  decode,
  verify,
  analyze,
  settings,
}

final currentScreenProvider = StateProvider<CurrentScreen>((ref) {
  return CurrentScreen.home;
});

/// Bottom sheet visibility
final showBottomSheetProvider = StateProvider<bool>((ref) {
  return false;
});

/// Loading overlay visibility
final showLoadingProvider = StateProvider<bool>((ref) {
  return false;
});

/// Snackbar message
final snackbarMessageProvider =
    StateProvider<({String message, bool isError})?>((ref) {
  return null;
});
