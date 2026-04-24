import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/ui_provider.dart';
import '../utils/constants.dart';
import '../models/watermark_model.dart';

/// Decoding screen - extract watermark from audio
class DecodeScreen extends ConsumerStatefulWidget {
  const DecodeScreen({super.key});

  @override
  ConsumerState<DecodeScreen> createState() => _DecodeScreenState();
}

class _DecodeScreenState extends ConsumerState<DecodeScreen> {
  late final TextEditingController _messageLengthController;

  @override
  void initState() {
    super.initState();
    _messageLengthController = TextEditingController();
  }

  @override
  void dispose() {
    _messageLengthController.dispose();
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
    final decoding = ref.watch(decodingProvider);
    final mode = ref.watch(watermarkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Decode Watermark'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(currentScreenProvider.notifier).state = CurrentScreen.home;
          },
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audio File Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.music_note,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Audio File',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (audioPath == null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Select Audio File'),
                        onPressed: _pickAudioFile,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                audioPath.split('/').last,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: _pickAudioFile,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Message Length (Optional)
            Text(
              'Message Length (Optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageLengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Leave empty for auto-detection (slower)',
                helperText: 'Hint: Knowing the length speeds up decoding',
              ),
            ),
            const SizedBox(height: 24),

            // Mode Selector
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
              onSelectionChanged: (selected) {
                ref.read(watermarkModeProvider.notifier).state = selected.first;
              },
            ),
            const SizedBox(height: 24),

            // Decoding Result
            if (decoding.isProcessing) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Decoding in progress...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: decoding.progress,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            decoding.result.when(
              data: (result) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            result.success
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: result.success ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result.success
                                  ? 'Watermark Extracted'
                                  : 'No watermark detected',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (result.message != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Extracted Message:',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result.message!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _ResultRow(
                        label: 'Confidence',
                        value:
                            '${(result.confidence * 100).toStringAsFixed(1)}%',
                      ),
                      _ResultRow(
                        label: 'Processing Time',
                        value:
                            '${result.processingTime.inMilliseconds}ms',
                      ),
                      if (result.suggestions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Suggestions:',
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                        ...result.suggestions.map((suggestion) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '• $suggestion',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              error: (error, _) => Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Decoding Failed',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        error is ProcessingError && error.details != null
                            ? error.details!
                            : error.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Decode Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cloud_download),
                label: const Text('Decode Watermark'),
                onPressed: audioPath != null && !decoding.isProcessing
                    ? () {
                        final messageLength =
                            int.tryParse(_messageLengthController.text);
                        ref.read(decodingProvider.notifier).decode(
                              audioFilePath: audioPath,
                              messageLength: messageLength,
                              mode: mode,
                            );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
