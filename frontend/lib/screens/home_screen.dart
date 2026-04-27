import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watermark_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/ui_provider.dart';
import '../utils/constants.dart';
import '../utils/spacing.dart';

/// Home screen - main dashboard
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(watermarkModeProvider);
    final stats = ref.watch(statsProvider);
    final userName = ref.watch(userIdentityProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AudioGuard'),
            Text(
              'Audio Protection & Verification',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.1,
                  ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              ref.read(currentTabProvider.notifier).state = NavigationTab.settings;
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Text(
              'Welcome back,',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              userName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // Mode Selector Card
            _ModeCard(currentMode: mode),
            const SizedBox(height: AppSpacing.l),

            // Quick Stats
            _QuickStatsCard(stats: stats),
            const SizedBox(height: AppSpacing.l),

            // Action Grid
            Text(
              'Watermark Operations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            _ActionGrid(),
            const SizedBox(height: AppSpacing.l),

            // Recent Operations
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Operations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (ref.watch(historyProvider).isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(historyProvider.notifier).clearHistory();
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getModeDescription(currentMode),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Insights & Metrics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.analytics_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Primary Metrics Row
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Total',
                    value: '${stats.totalOperations}',
                    icon: Icons.functions_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    label: 'Accuracy',
                    value: '${(stats.averageConfidence * 100).toStringAsFixed(0)}%',
                    icon: Icons.gps_fixed_rounded,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    label: 'Success',
                    value: '${(stats.successRate * 100).toStringAsFixed(0)}%',
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),
            
            // Secondary Metrics (Breakdown)
            Text(
              'Operation Breakdown',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _MiniStat(
                  icon: Icons.upload_file_rounded,
                  label: 'Encodes',
                  value: '${stats.typeBreakdown['encode'] ?? 0}',
                ),
                _MiniStat(
                  icon: Icons.download_rounded,
                  label: 'Decodes',
                  value: '${stats.typeBreakdown['decode'] ?? 0}',
                ),
                _MiniStat(
                  icon: Icons.verified_user_rounded,
                  label: 'Verifies',
                  value: '${stats.typeBreakdown['verify'] ?? 0}',
                ),
                _MiniStat(
                  icon: Icons.insights_rounded,
                  label: 'Analyses',
                  value: '${stats.typeBreakdown['analyze'] ?? 0}',
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Success/Fail Bar
            if (stats.totalOperations > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Success Ratio',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${stats.successfulOperations} Pass / ${stats.failedOperations} Fail',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stats.successRate,
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      color: Colors.green,
                      minHeight: 6,
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

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$value $label',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
        onTap: (ref) {
          ref.read(currentHomeScreenProvider.notifier).state = HomeSubScreen.encode;
        },
      ),
      _ActionData(
        icon: Icons.download,
        label: 'Decode',
        description: 'Extract watermark',
        color: const Color(0xFF03DAC6),
        onTap: (ref) {
          ref.read(currentHomeScreenProvider.notifier).state = HomeSubScreen.decode;
        },
      ),
      _ActionData(
        icon: Icons.verified_user,
        label: 'Verify',
        description: 'Check authenticity',
        color: const Color(0xFF4CAF50),
        onTap: (ref) {
          ref.read(currentHomeScreenProvider.notifier).state = HomeSubScreen.verify;
        },
      ),
      _ActionData(
        icon: Icons.insights,
        label: 'Analyze',
        description: 'Audio analysis',
        color: const Color(0xFFFFC107),
        onTap: (ref) {
          ref.read(currentHomeScreenProvider.notifier).state = HomeSubScreen.analyze;
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
  final Function(WidgetRef) onTap;

  _ActionData({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });
}

class _ActionButton extends ConsumerWidget {
  final _ActionData action;

  const _ActionButton({
    required this.action,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: action.color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => action.onTap(ref),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                action.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(127),
              ),
              const SizedBox(height: 12),
              Text(
                'No operations yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (entry.success ? Colors.green : Colors.red).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getOperationIcon(entry.operationType),
              color: entry.success ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
              size: 20,
            ),
          ),
          title: Text(
            '${entry.operationType[0].toUpperCase()}${entry.operationType.substring(1)}: ${entry.filename}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${entry.mode} • ${_formatDateTime(entry.timestamp)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: entry.confidence != null 
            ? Text(
                '${(entry.confidence! * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
          onTap: () {
            // TODO: Navigate to detail or re-load file
          },
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

  String _formatDateTime(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
