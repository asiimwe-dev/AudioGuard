import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/app_shell.dart';
import 'theme/app_theme.dart';
import 'providers/ui_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage
  final storageService = StorageService();
  await storageService.initialize();
  
  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const AudioGuardApp(),
    ),
  );
}

class AudioGuardApp extends ConsumerWidget {
  const AudioGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);

    return MaterialApp(
      title: 'AudioGuard',
      theme: AppTheme.lightTheme(appearance.fontSizeScale),
      darkTheme: AppTheme.darkTheme(appearance.fontSizeScale),
      themeMode: _getThemeMode(appearance.themeMode),
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeMode _getThemeMode(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
  }
}
