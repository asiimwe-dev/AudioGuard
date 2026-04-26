import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/navigation_provider.dart';
import '../models/watermark_model.dart';
import '../utils/constants.dart';
import '../widgets/audio_player_widget.dart';

/// Verification screen - verify watermark authenticity
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    final audioService = ref.read(audioServiceProvider);
    final file = await audioService.pickAudioFile();
    if (file != null) {
      ref.read(selectedAudioFileProvider.notifier).state = file.path;
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioPath = ref.watch(selectedAudioFileProvider);
    final verifyState = ref.watch(verificationProvider);
    final mode = ref.watch(watermarkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Watermark'),
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

                  // Expected message input
                  Text(
                    'Expected Watermark Message',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter the watermark message to verify',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.message),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  // Mode selector
                  Text(
                    'Processing Mode',
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

                  // Verify button
                  if (verifyState.isProcessing)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: verifyState.progress,
                        ),
                        const SizedBox(height: 8),
                        Text('Verifying... ${(verifyState.progress * 100).toStringAsFixed(0)}%'),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _messageController.text.isEmpty
                          ? null
                          : () async {
                              await ref
                                  .read(verificationProvider.notifier)
                                  .verify(
                                    fileId: null,
                                    expectedMessage:
                                        _messageController.text,
                                    mode: mode,
                                  );
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Verify Watermark'),
                    ),
                  const SizedBox(height: 24),

                  // Result display
                  verifyState.result.when(
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
                                const Text('Verification Failed'),
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

  Widget _buildResultCard(BuildContext context, VerifyResult result) {
    final isValid = result.isValid;
    return Card(
      color: isValid
          ? Theme.of(context).colorScheme.tertiaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.cancel,
                  color: isValid
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.error,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isValid ? 'Watermark Valid' : 'Watermark Invalid',
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
              'Mode: ${result.mode}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
