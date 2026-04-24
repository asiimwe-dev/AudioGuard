import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/watermark_model.dart';
import '../theme/app_theme.dart';
import '../providers/navigation_provider.dart';

/// Appearance settings screen - configure UI preferences (full screen)
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
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return WillPopScope(
      onWillPop: () async {
        ref.read(currentSettingsScreenProvider.notifier).state = SettingsSubScreen.main;
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appearance Settings'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              ref.read(currentSettingsScreenProvider.notifier).state = SettingsSubScreen.main;
            },
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Responsive Layout: Stacked on small screens, side-by-side on large
                isSmallScreen
                    ? _buildVerticalLayout(context)
                    : _buildHorizontalLayout(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Font Family Section
        _buildSectionTitle('Font Family'),
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
        const SizedBox(height: 32),

        // Font Size Section
        _buildSectionTitle('Font Size'),
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
        const SizedBox(height: 32),

        // Theme Section
        _buildSectionTitle('Theme'),
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
        const SizedBox(height: 32),

        // Contrast Section
        _buildSectionTitle('Contrast'),
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
        const SizedBox(height: 32),

        // Preview Section
        _buildPreview(context),
        const SizedBox(height: 32),

        // Action Buttons
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildHorizontalLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Font Family'),
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
                  const SizedBox(height: 32),
                  _buildSectionTitle('Font Size'),
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
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Theme'),
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
                  const SizedBox(height: 32),
                  _buildSectionTitle('Contrast'),
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
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildPreview(context),
        const SizedBox(height: 32),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'This is how your heading will look',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This is how your body text will look - it should be easy to read',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'This is smaller detail text',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
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
      const SnackBar(
        content: Text(
          'Appearance settings saved! Changes will apply on app restart.',
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    // Go back to main settings instead of popping
    ref.read(currentSettingsScreenProvider.notifier).state = SettingsSubScreen.main;
  }
}
