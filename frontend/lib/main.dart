import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/encode_screen.dart';
import 'screens/decode_screen.dart';
import 'screens/verify_screen.dart';
import 'screens/analyze_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import 'providers/ui_provider.dart';
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
      home: const _AppHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AppHome extends ConsumerWidget {
  const _AppHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentScreen = ref.watch(currentScreenProvider);

    return switch (currentScreen) {
      CurrentScreen.home => const HomeScreen(),
      CurrentScreen.encode => const EncodeScreen(),
      CurrentScreen.decode => const DecodeScreen(),
      CurrentScreen.verify => const VerifyScreen(),
      CurrentScreen.analyze => const AnalyzeScreen(),
      CurrentScreen.settings => const SettingsScreen(),
    };
  }
}
