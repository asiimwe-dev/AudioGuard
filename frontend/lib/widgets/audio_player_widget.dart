import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_player_provider.dart';

/// Audio player widget - reusable playback control
class AudioPlayerWidget extends ConsumerWidget {
  final String filePath;
  final String? fileName;
  final VoidCallback? onClose;

  const AudioPlayerWidget({
    super.key,
    required this.filePath,
    this.fileName,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final player = ref.read(audioPlayerProvider.notifier);

    final isCurrentFile = playerState.currentFile == filePath;
    final isPlaying = isCurrentFile && playerState.isPlaying;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with filename and close button
            Row(
              children: [
                Expanded(
                  child: Text(
                    fileName ?? 'Audio File',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Time display and progress bar
            Row(
              children: [
                Text(
                  player.formatDuration(playerState.position),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: playerState.duration.inMilliseconds > 0
                        ? playerState.position.inMilliseconds.toDouble()
                        : 0,
                    max: playerState.duration.inMilliseconds > 0
                        ? playerState.duration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: (value) {
                      player.seek(
                        Duration(milliseconds: value.toInt()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  player.formatDuration(playerState.duration),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play/Pause button
                ElevatedButton.icon(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  label: Text(isPlaying ? 'Pause' : 'Play'),
                  onPressed: () {
                    if (isCurrentFile) {
                      if (isPlaying) {
                        player.pause();
                      } else {
                        player.resume();
                      }
                    } else {
                      player.playAudio(filePath);
                    }
                  },
                ),
                const SizedBox(width: 12),
                // Stop button
                if (isCurrentFile && playerState.position > Duration.zero)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed: () => player.stop(),
                  ),
              ],
            ),

            // Error message
            if (playerState.error != null && isCurrentFile)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Theme.of(context).colorScheme.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playerState.error!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact audio player for small spaces
class CompactAudioPlayer extends ConsumerWidget {
  final String filePath;
  final String? label;

  const CompactAudioPlayer({
    super.key,
    required this.filePath,
    this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final player = ref.read(audioPlayerProvider.notifier);

    final isCurrentFile = playerState.currentFile == filePath;
    final isPlaying = isCurrentFile && playerState.isPlaying;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Play/Pause button
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
            ),
            onPressed: () {
              if (isCurrentFile) {
                if (isPlaying) {
                  player.pause();
                } else {
                  player.resume();
                }
              } else {
                player.playAudio(filePath);
              }
            },
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // Time info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '${player.formatDuration(playerState.position)} / ${player.formatDuration(playerState.duration)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
