import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/constants.dart';

/// Settings screen - main settings hub with navigation to other screens
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final mode = ref.watch(watermarkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Processing Mode Section
            _buildSectionTitle(context, 'Processing Mode'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Mode',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    ...WatermarkMode.values.map((m) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<WatermarkMode>(
                          value: m,
                          groupValue: mode,
                          onChanged: (value) {
                            if (value != null) {
                              ref.read(watermarkModeProvider.notifier).state =
                                  value;
                              ref.read(settingsProvider.notifier).setDefaultMode(value);
                            }
                          },
                          title: Text(m.label),
                          subtitle: Text(_getModeDescription(m)),
                          dense: true,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // General Settings Section
            _buildSectionTitle(context, 'General Settings'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Save Processing History'),
                      subtitle: const Text(
                          'Keep a log of encode/decode operations'),
                      value: settings.saveHistory,
                      onChanged: (value) {
                        ref
                            .read(settingsProvider.notifier)
                            .setSaveHistory(value);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Show Notifications'),
                      subtitle:
                          const Text('Get notified when operations complete'),
                      value: settings.showNotifications,
                      onChanged: (value) {
                        ref
                            .read(settingsProvider.notifier)
                            .setShowNotifications(value);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Enable Analytics'),
                      subtitle: const Text(
                          'Help improve AudioGuard by sending usage stats'),
                      value: settings.enableAnalytics,
                      onChanged: (value) {
                        ref
                            .read(settingsProvider.notifier)
                            .setEnableAnalytics(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Advanced Section
            _buildSectionTitle(context, 'Advanced'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cache & Data',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(storageServiceProvider).clearAll();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cache and storage cleared')),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear Cache'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('All settings reset to default')),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset to Default'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Appearance Settings Section
            _buildSectionTitle(context, 'Customization'),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Appearance'),
                subtitle: const Text('Font, size, theme, contrast'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  ref.read(currentSettingsScreenProvider.notifier).state =
                      SettingsSubScreen.appearance;
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  String _getModeDescription(WatermarkMode mode) {
    switch (mode) {
      case WatermarkMode.local:
        return 'Process on device (fast, offline)';
      case WatermarkMode.cloud:
        return 'Process on server (accurate, requires network)';
      case WatermarkMode.hybrid:
        return 'Try local first, fall back to cloud';
    }
  }
}
