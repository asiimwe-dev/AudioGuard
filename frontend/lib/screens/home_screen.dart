import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/ui_provider.dart' show currentScreenProvider, CurrentScreen;
import '../utils/constants.dart';

/// Home screen - main dashboard
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(watermarkModeProvider);
    final stats = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AudioGuard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ref.read(currentScreenProvider.notifier).state = CurrentScreen.settings;
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Selector Card
            _ModeCard(currentMode: mode),
            const SizedBox(height: 24),

            // Quick Stats
            _QuickStatsCard(stats: stats),
            const SizedBox(height: 24),

            // Action Grid
            const Text(
              'Watermark Operations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _ActionGrid(),
            const SizedBox(height: 24),

            // Recent Operations
            Text(
              'Recent Operations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _RecentOperations(),
          ],
        ),
      ),
    );
  }
}

/// Mode selector card
class _ModeCard extends ConsumerWidget {
  final WatermarkMode currentMode;

  const _ModeCard({
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Processing Mode',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Icon(
                  _getModeIcon(currentMode),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              currentMode.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getModeDescription(currentMode),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showModeSelector(context, ref);
                },
                child: const Text('Change Mode'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getModeIcon(WatermarkMode mode) {
    return switch (mode) {
      WatermarkMode.local => Icons.smartphone,
      WatermarkMode.cloud => Icons.cloud,
      WatermarkMode.hybrid => Icons.sync_alt,
    };
  }

  String _getModeDescription(WatermarkMode mode) {
    return switch (mode) {
      WatermarkMode.local =>
        'Process audio on device. Fast, offline, no internet required.',
      WatermarkMode.cloud =>
        'Use cloud API. Better accuracy, requires internet connection.',
      WatermarkMode.hybrid =>
        'Try local first, fall back to cloud. Best of both worlds.',
    };
  }

  void _showModeSelector(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Processing Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: WatermarkMode.values.map((mode) {
            return RadioListTile<WatermarkMode>(
              title: Text(mode.label),
              subtitle: Text(_getModeDescription(mode)),
              value: mode,
              groupValue: currentMode,
              onChanged: (selectedMode) {
                if (selectedMode != null) {
                  ref.read(watermarkModeProvider.notifier).state = selectedMode;
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Quick statistics card
class _QuickStatsCard extends StatelessWidget {
  final OperationStats stats;

  const _QuickStatsCard({
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Operations',
                    value: '${stats.totalOperations}',
                    icon: Icons.check_circle_outline,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Success Rate',
                    value: '${(stats.successRate * 100).toStringAsFixed(0)}%',
                    icon: Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Avg Confidence',
                    value: '${(stats.averageConfidence * 100).toStringAsFixed(0)}%',
                    icon: Icons.signal_cellular_4_bar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Action buttons grid
class _ActionGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _ActionData(
        icon: Icons.upload_file,
        label: 'Encode',
        description: 'Add watermark',
        color: const Color(0xFF6200EE),
        onTap: () {
          ref.read(currentScreenProvider.notifier).state = CurrentScreen.encode;
        },
      ),
      _ActionData(
        icon: Icons.download,
        label: 'Decode',
        description: 'Extract watermark',
        color: const Color(0xFF03DAC6),
        onTap: () {
          ref.read(currentScreenProvider.notifier).state = CurrentScreen.decode;
        },
      ),
      _ActionData(
        icon: Icons.verified_user,
        label: 'Verify',
        description: 'Check authenticity',
        color: const Color(0xFF4CAF50),
        onTap: () {
          ref.read(currentScreenProvider.notifier).state = CurrentScreen.verify;
        },
      ),
      _ActionData(
        icon: Icons.insights,
        label: 'Analyze',
        description: 'Audio analysis',
        color: const Color(0xFFFFC107),
        onTap: () {
          ref.read(currentScreenProvider.notifier).state = CurrentScreen.analyze;
        },
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: actions.map((action) {
        return _ActionButton(action: action);
      }).toList(),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  _ActionData({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });
}

class _ActionButton extends StatelessWidget {
  final _ActionData action;

  const _ActionButton({
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                action.icon,
                size: 40,
                color: action.color,
              ),
              const SizedBox(height: 12),
              Text(
                action.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                action.description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recent operations list
class _RecentOperations extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    if (history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No operations yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.take(5).length,
      itemBuilder: (context, index) {
        final entry = history[index];
        return ListTile(
          leading: Icon(
            _getOperationIcon(entry.operationType),
            color: entry.success ? Colors.green : Colors.red,
          ),
          title: Text(
            '${entry.operationType[0].toUpperCase()}${entry.operationType.substring(1)}',
          ),
          subtitle: Text(
            '${entry.mode} • ${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
          ),
          trailing: Text(
            '${(entry.confidence ?? 0 * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  IconData _getOperationIcon(String type) {
    return switch (type) {
      'encode' => Icons.upload_file,
      'decode' => Icons.download,
      'verify' => Icons.verified_user,
      'analyze' => Icons.insights,
      _ => Icons.help,
    };
  }
}
