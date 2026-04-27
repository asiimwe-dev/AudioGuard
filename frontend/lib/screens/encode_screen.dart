import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
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
  late final TextEditingController _amplitudeController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _amplitudeController =
        TextEditingController(text: AppConstants.defaultAmplitudeFactor.toString());
        
    // Pre-populate with author name if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final author = ref.read(userIdentityProvider);
      if (author != 'Anonymous' && _messageController.text.isEmpty) {
        _messageController.text = author;
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _amplitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    final audioService = ref.read(audioServiceProvider);
    final file = await audioService.pickAudioFile();
    if (file != null) {
      ref.read(selectedAudioFileProvider.notifier).state = file.path;
    }
  }

  Future<void> _shareFile(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'Check out my watermarked audio via AudioGuard!');
  }

  @override
  Widget build(BuildContext context) {
    final audioPath = ref.watch(selectedAudioFileProvider);
    final encoding = ref.watch(encodingProvider);
    final mode = ref.watch(watermarkModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Encode Watermark', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(currentHomeScreenProvider.notifier).state =
                HomeSubScreen.dashboard;
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Header
            _buildInfoCard(theme),
            const SizedBox(height: 24),

            // Audio File Selector
            _buildFileSelector(theme, audioPath),
            const SizedBox(height: 24),

            // Watermark Message
            Text(
              'Watermark Signature',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g., AUTHOR_ID_2026',
                helperText: 'This message will be invisibly woven into the audio.',
                prefixIcon: const Icon(Icons.edit_note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLength: AppConstants.maxMessageLength,
            ),
            const SizedBox(height: 16),

            // Settings Expansion
            ExpansionTile(
              title: Text('Advanced Encoding Settings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _amplitudeController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Amplitude Factor',
                          helperText: 'Higher = More robust but more audible (0.01 - 0.1)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Processing Mode:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                          Text(mode.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Encoding Status & Results
            if (encoding.isProcessing) _buildProcessingCard(theme, encoding.progress),
            
            encoding.result.when(
              data: (result) => _buildResultCard(theme, result),
              error: (error, _) => _buildErrorCard(theme, error),
              loading: () => const SizedBox.shrink(),
            ),
            
            const SizedBox(height: 32),

            // Main Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_outline),
                label: const Text('EMBED WATERMARK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: audioPath == null || encoding.isProcessing
                    ? null
                    : () {
                        ref.read(encodingProvider.notifier).encode(
                              audioFilePath: audioPath,
                              message: _messageController.text,
                              mode: mode,
                            );
                      },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Sign your work with a spectral digital signature that survives conversion and noise.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelector(ThemeData theme, String? audioPath) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Input Audio', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            if (audioPath == null)
              OutlinedButton.icon(
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.audio_file),
                label: Text('Choose Audio File', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              )
            else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      audioPath.split('/').last,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(onPressed: _pickAudioFile, child: const Text('Change')),
                ],
              ),
              const SizedBox(height: 12),
              AudioPlayerWidget(filePath: audioPath, fileName: audioPath.split('/').last),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingCard(ThemeData theme, double progress) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Applying Fourier Transformation...', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, borderRadius: BorderRadius.circular(8)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, EncodingResult result) {
    if (!result.success) return const SizedBox.shrink();

    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.green, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
                         Row(
              children: [
                Icon(Icons.verified, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  'SUCCESSFULLY SIGNED',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Your audio has been watermarked. The signature is now part of the spectral data.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareFile(result.encodedFilePath),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('SHARE FILE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme, Object error) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Failed to encode: $error',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
