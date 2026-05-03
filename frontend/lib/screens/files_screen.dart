import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/audio_player_widget.dart';

/// Files library screen - browse and manage encoded files
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  @override
  Widget build(BuildContext context) {
    final encodedFiles = ref.watch(encodedFilesLibraryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Files Library', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(currentHomeScreenProvider.notifier).state =
                HomeSubScreen.dashboard;
          },
        ),
      ),
      body: encodedFiles.when(
        data: (files) {
          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No Files Yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Encoded files will appear here.\nStart by encoding an audio file.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return _buildFileCard(theme, file);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading files', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error.toString(), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard(ThemeData theme, dynamic file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    file.format,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.filename,
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file.formattedDate,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Message and metadata
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file.message,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'File Size',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              file.fileSizeString,
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amplitude',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${(file.amplitudeFactor * 100).toStringAsFixed(1)}%',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Audio preview (only show if file path is accessible)
            _buildAudioPreview(theme, file),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onVerify(file),
                    icon: const Icon(Icons.verified_user),
                    label: const Text('VERIFY'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onAnalyze(file),
                    icon: const Icon(Icons.analytics),
                    label: const Text('ANALYZE'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _onDelete(file),
                  tooltip: 'Delete file',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPreview(ThemeData theme, dynamic file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AudioPlayerWidget(
        filePath: file.filePath,
        fileName: file.filename,
      ),
    );
  }

  void _onVerify(dynamic file) {
    // Set the selected file and navigate to verify
    ref.read(selectedAudioFileProvider.notifier).state = file.filePath;
    ref.read(currentHomeScreenProvider.notifier).state = HomeSubScreen.verify;
  }

  void _onAnalyze(dynamic file) {
    // Set the selected file and navigate to analyze
    ref.read(selectedAudioFileProvider.notifier).state = file.filePath;
    ref.read(currentHomeScreenProvider.notifier).state = HomeSubScreen.analyze;
  }

  void _onDelete(dynamic file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete "${file.filename}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final fileLibraryService = ref.read(fileLibraryServiceProvider);
                await fileLibraryService.deleteEncodedFile(file.id);
                ref.invalidate(encodedFilesLibraryProvider);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File deleted')),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting file: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
