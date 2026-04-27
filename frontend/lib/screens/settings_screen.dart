import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/constants.dart';

/// Settings screen for application configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _authorController;

  @override
  void initState() {
    super.initState();
    _authorController = TextEditingController();
  }

  @override
  void dispose() {
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final appearance = ref.watch(appearanceProvider);
    final currentAuthor = ref.watch(userIdentityProvider);

    if (_authorController.text.isEmpty && currentAuthor != 'Anonymous') {
      _authorController.text = currentAuthor;
    } else if (_authorController.text.isEmpty && currentAuthor == 'Anonymous') {
       _authorController.text = '';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Profile Section
          _SectionHeader(title: 'User Profile'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Author Identity',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This name will be used as the default watermark message when encoding new audio.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _authorController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Enter your name or ID',
                      prefixIcon: const Icon(Icons.person_outline),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          if (_authorController.text.isNotEmpty) {
                            ref.read(userIdentityProvider.notifier).setAuthorName(_authorController.text);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Identity updated')),
                            );
                            FocusScope.of(context).unfocus();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Customization Section
          _SectionHeader(title: 'Appearance'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme and Font Size'),
              subtitle: Text('Current: ${appearance.themeMode.name.toUpperCase()}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(currentSettingsScreenProvider.notifier).state = SettingsSubScreen.appearance;
              },
            ),
          ),
          const SizedBox(height: 24),

          // Processing Settings
          _SectionHeader(title: 'Processing Mode'),
          Card(
            child: Column(
              children: WatermarkMode.values.map((mode) {
                return RadioListTile<WatermarkMode>(
                  title: Text(mode.label),
                  subtitle: Text(_getModeDescription(mode)),
                  value: mode,
                  groupValue: settings.defaultMode,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(settingsProvider.notifier).setDefaultMode(value);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Connectivity Section
          _SectionHeader(title: 'Connectivity & API'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('API Configuration'),
              subtitle: const Text('Backend URL and Authentication'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(currentTabProvider.notifier).state = NavigationTab.apiConfig;
              },
            ),
          ),
          const SizedBox(height: 24),

          // General Settings
          _SectionHeader(title: 'Data & Privacy'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Save History'),
                  subtitle: const Text('Keep track of previous operations locally'),
                  value: settings.saveHistory,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setSaveHistory(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Enable Analytics'),
                  subtitle: const Text('Anonymous usage data to help us improve'),
                  value: settings.enableAnalytics,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setEnableAnalytics(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  title: Text(
                    'Clear All Data',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () => _showClearDataDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // App Info
          _SectionHeader(title: 'About'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('Version'),
                  trailing: Text('${AppConstants.appVersion}+${AppConstants.buildNumber}'),
                ),
                const Divider(height: 1),
                const ListTile(
                  title: Text('Developer'),
                  trailing: Text(AppConstants.developerName),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {
                    // Open URL
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
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

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Clear all data?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This will delete all history, custom settings, and identity info. This action cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              await ref.read(storageServiceProvider).clearAll();
              ref.read(historyProvider.notifier).clearHistory();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
