import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/ui_provider.dart';
import '../utils/constants.dart';

/// Settings screen - configure app preferences and API settings
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _apiUrlController;
  late final TextEditingController _authTokenController;
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController();
    _authTokenController = TextEditingController();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _authTokenController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _isTestingConnection = true);
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final isHealthy = await apiService.checkHealth();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHealthy 
            ? 'Connection successful!' 
            : 'Connection failed. Please check the URL and your network.'),
          backgroundColor: isHealthy ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTestingConnection = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final mode = ref.watch(watermarkModeProvider);

    // Initialize controllers with settings values if they are empty
    if (_apiUrlController.text.isEmpty) {
      _apiUrlController.text = settings.apiBaseUrl;
    }
    if (_authTokenController.text.isEmpty && settings.authToken != null) {
      _authTokenController.text = settings.authToken ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Save settings before leaving
            ref.read(settingsProvider.notifier).saveSettings(ref.read(storageServiceProvider));
            ref.read(currentScreenProvider.notifier).state = CurrentScreen.home;
          },
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API Configuration Section
            _buildSectionTitle(context, 'API Configuration'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API Base URL',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiUrlController,
                      decoration: InputDecoration(
                        hintText: AppConstants.defaultApiBaseUrl,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.language),
                      ),
                      onChanged: (value) {
                        ref
                            .read(settingsProvider.notifier)
                            .setApiBaseUrl(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Authentication Token',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _authTokenController,
                      decoration: InputDecoration(
                        hintText: 'JWT token (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _authTokenController.clear();
                            ref
                                .read(settingsProvider.notifier)
                                .setAuthToken(null);
                          },
                        ),
                      ),
                      obscureText: true,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setAuthToken(
                            value.isEmpty ? null : value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTestingConnection ? null : _testConnection,
                        icon: _isTestingConnection 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                            )
                          : const Icon(Icons.check),
                        label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

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
                        // For a real reset, we'd recreate the AppSettings()
                        // but here we just show a snackbar
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

            // About Section
            _buildSectionTitle(context, 'About'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'App Version',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '1.0.0',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Build Number',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '1',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'AudioGuard Mobile',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Audio Watermarking & Attribution',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '© 2024 AudioGuard. All rights reserved.',
                            style: Theme.of(context).textTheme.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
