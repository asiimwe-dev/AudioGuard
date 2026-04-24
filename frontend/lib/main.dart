import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/app_shell.dart';
import 'theme/app_theme.dart';
import 'providers/watermark_provider.dart';
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
    // Load settings once at startup
    ref.read(settingsProvider.notifier).loadSettings(ref.read(storageServiceProvider));

    return MaterialApp(
      title: 'AudioGuard',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
