import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// About screen - app info, credits, and links
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'About AudioGuard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Icon & Title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AudioGuard',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Audio Watermarking & Verification System',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Version Info
                  _InfoRow(
                    icon: Icons.tag,
                    label: 'Version',
                    value: '1.0.0',
                  ),
                  _InfoRow(
                    icon: Icons.build,
                    label: 'Build',
                    value: '1 (Release)',
                  ),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Release Date',
                    value: 'April 2024',
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'About',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AudioGuard is a high-fidelity digital watermarking system designed for audio authenticity and attribution. It uses advanced signal processing to embed invisible signatures into audio files, enabling creators and journalists to prove content authenticity.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Features
                  Text(
                    'Features',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _FeatureItem('STFT-based watermark embedding'),
                  _FeatureItem('Cloud & local processing modes'),
                  _FeatureItem('High watermark robustness'),
                  _FeatureItem('Multi-format audio support'),
                  _FeatureItem('Cross-platform (iOS, Android)'),
                  const SizedBox(height: 24),

                  // Links
                  Text(
                    'Resources',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _LinkButton(
                    icon: Icons.code,
                    label: 'View on GitHub',
                    url: 'https://github.com/asiimwe-dev/AudioGuard',
                  ),
                  _LinkButton(
                    icon: Icons.description,
                    label: 'Documentation',
                    url: 'https://github.com/asiimwe-dev/AudioGuard#readme',
                  ),
                  _LinkButton(
                    icon: Icons.bug_report,
                    label: 'Report Issue',
                    url: 'https://github.com/asiimwe-dev/AudioGuard/issues',
                  ),
                  const SizedBox(height: 24),

                  // Licenses
                  ExpansionTile(
                    title: Text(
                      'Open Source Licenses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'This app uses the following open source libraries:\n\n'
                          '• Flutter (BSD 3-Clause License)\n'
                          '• Riverpod (MIT License)\n'
                          '• audio_players (MIT License)\n'
                          '• file_picker (MIT License)\n'
                          '• url_launcher (BSD 3-Clause License)\n'
                          '• permission_handler (MIT License)\n\n'
                          'For full licenses, visit github.com/asiimwe-dev/AudioGuard',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Footer
                  Center(
                    child: Text(
                      '© 2024 AudioGuard. All rights reserved.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;

  const _FeatureItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _LinkButton({
    required this.icon,
    required this.label,
    required this.url,
  });

  Future<void> _launchUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        child: InkWell(
          onTap: _launchUrl,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 10),
                Text(label),
                const Spacer(),
                const Icon(Icons.open_in_new, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
