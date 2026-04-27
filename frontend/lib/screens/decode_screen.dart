import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/watermark_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/ui_provider.dart';
import '../utils/constants.dart';
import '../models/watermark_model.dart';
import '../widgets/audio_player_widget.dart';

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
    
    // Clear the global selection when entering the decode screen 
    // to ensure the user supplies a fresh file as requested.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedAudioFileProvider.notifier).state = null;
      ref.read(decodingProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _messageLengthController.dispose();
    super.dispose();
  }

  String _getErrorMessage(Object error) {
    if (error is ProcessingError) {
      return error.details ?? error.message;
    }
    final message = error.toString();
    // Clean up stack traces
    if (message.contains('Exception:')) {
      return message.split('Exception:').last.trim().split('\n').first;
    }
    return message.split('\n').first;
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
            _buildFileSelector(audioPath),
            const SizedBox(height: 24),

            // Message Length (Optional)
            TextField(
              controller: _messageLengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Expected Message Length (Optional)',
                hintText: 'e.g. 14',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Decode Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_open),
                label: const Text('EXTRACT WATERMARK'),
                onPressed: audioPath == null || decoding.isProcessing
                    ? null
                    : () {
                        final messageLength =
                            int.tryParse(_messageLengthController.text);
                        ref.read(decodingProvider.notifier).decode(
                              fileId: null,
                              messageLength: messageLength,
                              mode: mode,
                            );
                      },
              ),
            ),
            const SizedBox(height: 24),

            // Decoding Result
            decoding.result.when(
              data: (result) => _buildResultCard(result),
              error: (error, _) => _buildErrorCard(error),
              loading: () => decoding.isProcessing ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector(String? audioPath) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (audioPath == null)
              OutlinedButton.icon(
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.audio_file),
                label: const Text('Select Audio File'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(audioPath.split('/').last, overflow: TextOverflow.ellipsis),
                trailing: TextButton(onPressed: _pickAudioFile, child: const Text('Change')),
              ),
              AudioPlayerWidget(filePath: audioPath, fileName: audioPath.split('/').last),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(DecodingResult result) {
    if (!result.success) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No watermark detected.')));
    }
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Watermark Integrity Report', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            _ResultRow(label: 'Extracted Message', value: result.message ?? 'N/A'),
            _ResultRow(label: 'Confidence', value: '${(result.confidence * 100).toStringAsFixed(1)}%'),
            _ResultRow(label: 'Method', value: result.mode),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Share.share('Extracted Watermark: ${result.message} (Confidence: ${result.confidence})'),
              icon: const Icon(Icons.share),
              label: const Text('Share Result'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(Object error) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: ${_getErrorMessage(error)}', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
