import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Audio player state
class AudioPlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String? currentFile;
  final String? error;

  AudioPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentFile,
    this.error,
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? currentFile,
    String? error,
  }) {
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentFile: currentFile ?? this.currentFile,
      error: error,
    );
  }
}

/// Audio player provider - manages audio playback
class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  late final AudioPlayer _player;

  AudioPlayerNotifier() : super(AudioPlayerState()) {
    _initPlayer();
  }

  void _initPlayer() {
    _player = AudioPlayer();

    _player.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    _player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    _player.playerStateStream.listen((playerState) {
      state = state.copyWith(
        isPlaying: playerState.playing,
        error: playerState.processingState == ProcessingState.idle ? null : state.error,
      );
    });
  }

  /// Load and play audio file
  Future<void> playAudio(String filePath) async {
    try {
      await _player.setFilePath(filePath);
      await _player.play();
      state = state.copyWith(
        currentFile: filePath,
        isPlaying: true,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to play audio: $e',
        isPlaying: false,
      );
    }
  }

  /// Pause playback
  void pause() {
    _player.pause();
    state = state.copyWith(isPlaying: false);
  }

  /// Resume playback
  void resume() {
    _player.play();
    state = state.copyWith(isPlaying: true);
  }

  /// Stop playback and reset
  void stop() {
    _player.stop();
    state = state.copyWith(
      isPlaying: false,
      position: Duration.zero,
      currentFile: null,
    );
  }

  /// Seek to position
  void seek(Duration position) {
    _player.seek(position);
  }

  /// Get formatted time string
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

/// Audio player provider
final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  (ref) => AudioPlayerNotifier(),
);
