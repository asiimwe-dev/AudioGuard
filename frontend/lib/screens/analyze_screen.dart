import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/navigation_provider.dart';
import '../models/watermark_model.dart';
import '../utils/constants.dart';
import '../widgets/audio_player_widget.dart';

/// Analysis screen - analyze audio and detect watermark presence
class AnalyzeScreen extends ConsumerStatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  ConsumerState<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends ConsumerState<AnalyzeScreen> {
  @override
  void initState() {
    super.initState();
    // Only clear selection if no file is already selected
    // (to allow navigation from file library with pre-selected file)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentPath = ref.read(selectedAudioFileProvider);
      if (currentPath == null) {
        ref.read(analysisProvider.notifier).reset();
      }
    });
  }

  Future<void> _pickAudioFile() async {
    final audioService = ref.read(audioServiceProvider);
    final file = await audioService.pickAudioFile();
    if (file != null) {
      ref.read(selectedAudioFileProvider.notifier).state = file.path;
    }
  }

  String _getUserFriendlyErrorMessage(Object error) {
    final errorString = error.toString();
    
    if (errorString.contains('FILE_NOT_FOUND')) {
      return 'Audio file not found. Please select a valid file.';
    } else if (errorString.contains('EMPTY_FILE')) {
      return 'The audio file is empty.';
    } else if (errorString.contains('bad response') && errorString.contains('400')) {
      return 'The audio file format is not supported.';
    } else if (errorString.contains('SocketException') || errorString.contains('Connection refused')) {
      return 'Cannot connect to the server. Check your internet connection.';
    } else if (errorString.contains('TimeoutException') || errorString.contains('timeout')) {
      return 'The request took too long. Please try again.';
    }
    
    return 'Failed to analyze audio. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final audioPath = ref.watch(selectedAudioFileProvider);
    final analysisState = ref.watch(analysisProvider);
    final mode = ref.watch(watermarkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyze Watermark'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(currentHomeScreenProvider.notifier).state =
                HomeSubScreen.dashboard;
          },
        ),
        elevation: 0,
      ),
      body: audioPath == null
          ? _buildEmptyState(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Audio file card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.audio_file,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      audioPath.split('/').last,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      audioPath,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _pickAudioFile,
                            child: const Text('Change File'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Audio Player Widget
                  AudioPlayerWidget(
                    filePath: audioPath,
                    fileName: audioPath.split('/').last,
                  ),
                  const SizedBox(height: 20),

                  // Mode selector
                  Text(
                    'Analysis Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<WatermarkMode>(
                    segments: WatermarkMode.values
                        .map(
                          (m) => ButtonSegment(
                            value: m,
                            label: Text(m.label),
                          ),
                        )
                        .toList(),
                    selected: {mode},
                    onSelectionChanged: (selection) {
                      ref.read(watermarkModeProvider.notifier).state =
                          selection.first;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Analyze button
                  if (analysisState.isProcessing)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: analysisState.progress,
                        ),
                        const SizedBox(height: 8),
                        Text('Analyzing... ${(analysisState.progress * 100).toStringAsFixed(0)}%'),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: () async {
                        await ref
                            .read(analysisProvider.notifier)
                            .analyze(
                              fileId: null,
                              mode: mode,
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Analyze Audio'),
                    ),
                  const SizedBox(height: 24),

                  // Result display
                  analysisState.result.when(
                    data: (result) => _buildResultCard(context, result),
                    loading: () => const CircularProgressIndicator(),
                    error: (error, _) => Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error),
                                const SizedBox(width: 12),
                                const Text('Analysis Failed'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(error is ProcessingError && error.details != null
                                ? error.details!
                                : _getUserFriendlyErrorMessage(error)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audio_file,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No audio file selected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _pickAudioFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Select Audio File'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, AnalysisResult result) {
    final hasWatermark = result.watermarkPresent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: hasWatermark
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasWatermark ? Icons.check_circle : Icons.help_outline,
                      color: hasWatermark
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      hasWatermark
                          ? 'Watermark Detected'
                          : 'No Watermark Detected',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Processing time: ${result.processingTime.inMilliseconds}ms',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
