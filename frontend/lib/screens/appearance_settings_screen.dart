import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_provider.dart';

/// Screen for managing application appearance settings
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
      body: ListView(
        children: [
          // Theme Mode Section
          _SectionHeader(title: 'Theme'),
          RadioListTile<AppThemeMode>(
            title: const Text('System Default'),
            value: AppThemeMode.system,
            groupValue: appearance.themeMode,
            onChanged: (value) => ref.read(appearanceProvider.notifier).setThemeMode(value!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Light Mode'),
            value: AppThemeMode.light,
            groupValue: appearance.themeMode,
            onChanged: (value) => ref.read(appearanceProvider.notifier).setThemeMode(value!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Dark Mode'),
            value: AppThemeMode.dark,
            groupValue: appearance.themeMode,
            onChanged: (value) => ref.read(appearanceProvider.notifier).setThemeMode(value!),
          ),

          const Divider(),

          // Font Scaling Section
          _SectionHeader(title: 'Text Size'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Small'),
                    Text('${(appearance.fontSizeScale * 100).toInt()}%'),
                    const Text('Large'),
                  ],
                ),
                Slider(
                  value: appearance.fontSizeScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  onChanged: (value) => ref.read(appearanceProvider.notifier).setFontSizeScale(value),
                ),
                Text(
                  'Adjust the slider to scale application text size. This changes will apply immediately across all screens.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Preview Section
          _SectionHeader(title: 'Preview'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Headline Preview',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is how your body text will look with the current scaling and theme settings.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
