import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/ui_provider.dart';
import '../models/watermark_model.dart';
import '../utils/constants.dart';

/// Analysis screen - analyze audio and detect watermark presence
class AnalyzeScreen extends ConsumerWidget {
  const AnalyzeScreen({super.key});

  Future<void> _pickAudioFile(WidgetRef ref) async {
    final audioService = ref.read(audioServiceProvider);
    final file = await audioService.pickAudioFile();
    if (file != null) {
      ref.read(selectedAudioFileProvider.notifier).state = file.path;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPath = ref.watch(selectedAudioFileProvider);
    final analysisState = ref.watch(analysisProvider);
    final mode = ref.watch(watermarkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyze Watermark'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(currentScreenProvider.notifier).state = CurrentScreen.home;
          },
        ),
        elevation: 0,
      ),
      body: audioPath == null
          ? _buildEmptyState(context, ref)
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
                                          .bodySmall,
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
                            onPressed: () => _pickAudioFile(ref),
                            child: const Text('Change File'),
                          ),
                        ],
                      ),
                    ),
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
                              audioFilePath: audioPath,
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
                                : error.toString()),
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
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
            onPressed: () => _pickAudioFile(ref),
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
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
