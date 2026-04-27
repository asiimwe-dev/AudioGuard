import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/ui_provider.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';

/// API Configuration screen - dedicated tab for backend configuration
class ApiConfigScreen extends ConsumerStatefulWidget {
  const ApiConfigScreen({super.key});

  @override
  ConsumerState<ApiConfigScreen> createState() => _ApiConfigScreenState();
}

class _ApiConfigScreenState extends ConsumerState<ApiConfigScreen> {
  late final TextEditingController _apiUrlController;
  late final TextEditingController _authTokenController;
  bool _isTestingConnection = false;
  bool _isUrlEditable = false;

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
              ? 'Connection successful! Backend is responding.'
              : 'Connection failed. Please check the URL and your network.'),
          backgroundColor: isHealthy ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing connection: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTestingConnection = false);
      }
    }
  }

  Future<void> _showEditConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Backend URL?'),
        content: const Text(
          'Changing the backend URL to a custom or local address may affect application stability and security. Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isUrlEditable = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // Initialize controllers with settings values if empty
    if (_apiUrlController.text.isEmpty) {
      _apiUrlController.text = settings.apiBaseUrl;
    }
    if (_authTokenController.text.isEmpty && settings.authToken != null) {
      _authTokenController.text = settings.authToken ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Configuration'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API URL Section
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
                          'Backend URL',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (!_isUrlEditable)
                          TextButton.icon(
                            onPressed: _showEditConfirmation,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit Custom'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                        else
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isUrlEditable = false;
                                _apiUrlController.text = AppConstants.defaultApiBaseUrl;
                                ref.read(settingsProvider.notifier).setApiBaseUrl(AppConstants.defaultApiBaseUrl);
                              });
                            },
                            icon: const Icon(Icons.undo),
                            tooltip: 'Reset to Cloud Default',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The default cloud URL is optimized for production. Only change this for local development or private server use.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiUrlController,
                      readOnly: !_isUrlEditable,
                      style: _isUrlEditable ? null : TextStyle(color: Theme.of(context).disabledColor),
                      decoration: InputDecoration(
                        hintText: AppConstants.defaultApiBaseUrl,
                        filled: !_isUrlEditable,
                        fillColor: _isUrlEditable ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.language),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Backend URL Format'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Examples:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('Local (device on same network):'),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'http://192.168.1.100:8000',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('Emulator (local machine):'),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'http://10.0.2.2:8000',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('Production (cloud):'),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'https://api.audioguard.io',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      onChanged: (value) {
                        ref
                            .read(settingsProvider.notifier)
                            .setApiBaseUrl(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Authentication Token Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authentication Token (Optional)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'JWT token for authenticated API requests.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _authTokenController,
                      decoration: InputDecoration(
                        hintText: 'Paste JWT token here',
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
                        ref
                            .read(settingsProvider.notifier)
                            .setAuthToken(value.isEmpty ? null : value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Connection Status
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_queue,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connection Test',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Verify your backend is accessible',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isTestingConnection
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isTestingConnection
                              ? 'Testing...'
                              : 'Test Connection',
                        ),
                        onPressed: _isTestingConnection ? null : _testConnection,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Backend Info
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Backend Requirements',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Python 3.11+ with FastAPI\n'
                      '• AudioGuard engine installed\n'
                      '• Access to port 8000\n'
                      '• Network connectivity from device',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
