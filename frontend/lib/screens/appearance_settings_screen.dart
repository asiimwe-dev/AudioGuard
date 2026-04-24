import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/watermark_model.dart';
import '../theme/app_theme.dart';

/// Appearance settings modal - configure UI preferences
class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState
    extends ConsumerState<AppearanceSettingsScreen> {
  late String _selectedFontFamily;
  late String _selectedFontSize;
  late String _selectedTheme;
  late String _selectedContrast;

  @override
  void initState() {
    super.initState();
    _selectedFontFamily = 'Roboto';
    _selectedFontSize = 'medium';
    _selectedTheme = 'auto';
    _selectedContrast = 'normal';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              color: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.palette, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Appearance Settings',
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Font Family Section
                  Text(
                    'Font Family',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildRadioGroup(
                    items: {
                      'Roboto': 'Roboto (Default)',
                      'Lato': 'Lato (Modern)',
                      'Playfair': 'Playfair Display (Elegant)',
                    },
                    selected: _selectedFontFamily,
                    onChanged: (value) {
                      setState(() => _selectedFontFamily = value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Font Size Section
                  Text(
                    'Font Size',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildRadioGroup(
                    items: {
                      'small': 'Small (12dp base)',
                      'medium': 'Medium (16dp base) - Default',
                      'large': 'Large (18dp base)',
                      'xlarge': 'Extra Large (20dp base)',
                    },
                    selected: _selectedFontSize,
                    onChanged: (value) {
                      setState(() => _selectedFontSize = value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Theme Section
                  Text(
                    'Theme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildRadioGroup(
                    items: {
                      'light': 'Light Mode',
                      'dark': 'Dark Mode',
                      'auto': 'Auto (Follow System)',
                    },
                    selected: _selectedTheme,
                    onChanged: (value) {
                      setState(() => _selectedTheme = value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Contrast Section
                  Text(
                    'Contrast',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildRadioGroup(
                    items: {
                      'normal': 'Normal Contrast',
                      'high': 'High Contrast (Better Accessibility)',
                    },
                    selected: _selectedContrast,
                    onChanged: (value) {
                      setState(() => _selectedContrast = value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Preview Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceContainer,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This is how your text will look',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Smaller text for details',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveSettings,
                          child: const Text('Apply & Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioGroup({
    required Map<String, String> items,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      children: items.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: RadioListTile<String>(
              title: Text(
                entry.value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: entry.key,
              groupValue: selected,
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _saveSettings() {
    // TODO: Implement saving to secure storage and applying theme
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Appearance settings saved! Changes will apply on app restart.',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }
}
