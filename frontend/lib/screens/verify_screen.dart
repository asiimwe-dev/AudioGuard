import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/watermark_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/ui_provider.dart';
import '../models/watermark_model.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/waveform_loading_indicator.dart';

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

    // Clear selection when entering verify screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedAudioFileProvider.notifier).state = null;
      ref.read(verificationProvider.notifier).reset();
    });
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
    final authorIdentity = ref.watch(userIdentityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Authenticity'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(currentHomeScreenProvider.notifier).state = HomeSubScreen.dashboard,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (audioPath != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.audio_file_rounded),
                        title: Text(audioPath.split('/').last, overflow: TextOverflow.ellipsis),
                        trailing: TextButton(onPressed: _pickAudioFile, child: const Text('Change')),
                      ),
                      AudioPlayerWidget(filePath: audioPath, fileName: audioPath.split('/').last),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (audioPath != null) ...[
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Expected Message',
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(verificationProvider.notifier).verify(
                  fileId: null,
                  expectedMessage: _messageController.text,
                  mode: mode,
                ),
                child: const Text('VERIFY AUTHENTICITY'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.audio_file),
                label: const Text('Select Audio to Verify'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),

            const SizedBox(height: 24),
            
            if (verifyState.isProcessing)
              const Center(child: WaveformLoadingIndicator(label: 'Verifying Integrity...')),

            verifyState.result.when(
              data: (result) => _buildCertificate(result, authorIdentity),
              error: (err, _) => Text('Error: $err', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              loading: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificate(VerifyResult result, String author) {
    final theme = Theme.of(context);
    final isValid = result.isValid;
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isValid ? theme.colorScheme.tertiary : theme.colorScheme.error, width: 2),
        boxShadow: [
          BoxShadow(
            color: isValid ? theme.colorScheme.tertiary.withValues(alpha: 0.2) : theme.colorScheme.error.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(isValid ? Icons.verified_rounded : Icons.warning_amber_rounded, size: 64, color: isValid ? theme.colorScheme.tertiary : theme.colorScheme.error),
          Text(isValid ? 'AUTHENTIC' : 'TAMPERED', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Divider(),
          _CertificateField('Confidence Score', '${(result.confidence * 100).toStringAsFixed(1)}%'),
          _CertificateField('Verified By', author),
          _CertificateField('Timestamp', now),
          _CertificateField('Signature Hash', '0x${result.id.substring(0, 8).toUpperCase()}...'),
          const Divider(),
          Text('Digital Identity verified by AudioGuard Core.', style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
        ],
      ),
    );
  }
}

class _CertificateField extends StatelessWidget {
  final String label;
  final String value;
  const _CertificateField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
          Text(value, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontFamily: 'RobotoMono', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
