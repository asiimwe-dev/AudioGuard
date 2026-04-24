import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/ui_provider.dart';
import '../utils/constants.dart';
import '../models/watermark_model.dart';
import '../widgets/audio_player_widget.dart';

/// Encoding screen - add watermark to audio
class EncodeScreen extends ConsumerStatefulWidget {
  const EncodeScreen({super.key});

  @override
  ConsumerState<EncodeScreen> createState() => _EncodeScreenState();
}

class _EncodeScreenState extends ConsumerState<EncodeScreen> {
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
    final audioMetadata = ref.watch(audioMetadataProvider);
    final encoding = ref.watch(encodingProvider);
    final mode = ref.watch(watermarkModeProvider);
    final messageError =
        ref.watch(messageValidationProvider(_messageController.text));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Encode Watermark'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(currentHomeScreenProvider.notifier).state =
                HomeSubScreen.dashboard;
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
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              audioMetadata.when(
                                data: (metadata) => metadata?.filename ?? 'Unknown',
                                loading: () => 'Loading...',
                                error: (_, _) => 'Error loading metadata',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            audioMetadata.when(
                              data: (metadata) => Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Duration: ${metadata?.durationString}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    'Size: ${metadata?.fileSizeString}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              loading: () =>
                                  const CircularProgressIndicator(),
                              error: (_, _) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _pickAudioFile,
                        child: const Text('Change File'),
                      ),
                      const SizedBox(height: 16),
                      // Audio Player Widget
                      AudioPlayerWidget(
                        filePath: audioPath,
                        fileName: audioMetadata.maybeWhen(
                          data: (metadata) => metadata?.filename,
                          orElse: () => null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Message Input
            Text(
              'Watermark Message',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLength: AppConstants.maxMessageLength,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter the message to embed (max 256 characters)',
                errorText: messageError?.message,
                errorMaxLines: 2,
              ),
              onChanged: (_) {
                setState(() {});
              },
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

            // Encoding Result
            if (encoding.isProcessing) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Encoding in progress...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: encoding.progress,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            encoding.result.when(
              data: (result) => Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Encoding Successful',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ResultRow(
                        label: 'Mode',
                        value: result.mode,
                      ),
                      _ResultRow(
                        label: 'Processing Time',
                        value: '${result.processingTime.inMilliseconds}ms',
                      ),
                      _ResultRow(
                        label: 'Confidence',
                        value: '${(result.confidence * 100).toStringAsFixed(1)}%',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Download'),
                          onPressed: () {
                            // TODO: Download file
                          },
                        ),
                      ),
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
                          Expanded(
                            child: Text(
                              'Encoding Failed',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.red[900],
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
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Encode Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Encode Watermark'),
                onPressed: audioPath != null &&
                        _messageController.text.isNotEmpty &&
                        messageError == null &&
                        !encoding.isProcessing
                    ? () {
                        ref.read(encodingProvider.notifier).encode(
                              audioFilePath: audioPath,
                              message: _messageController.text,
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
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.green[900],
            ),
          ),
        ],
      ),
    );
  }
}
