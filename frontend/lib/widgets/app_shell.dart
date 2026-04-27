import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home_screen.dart';
import '../screens/encode_screen.dart';
import '../screens/decode_screen.dart';
import '../screens/verify_screen.dart';
import '../screens/analyze_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/api_config_screen.dart';
import '../screens/about_screen.dart';
import '../screens/appearance_settings_screen.dart';
import '../widgets/glassy_bottom_nav_new.dart';
import '../providers/navigation_provider.dart';

/// Main app shell with bottom navigation
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final navigationStack = ref.watch(navigationStackProvider);
    final settingsScreen = ref.watch(currentSettingsScreenProvider);
    final homeScreen = ref.watch(currentHomeScreenProvider);

    // Build the main screen content based on current tab
    Widget buildMainContent() {
      // If we're in settings tab, check if we're in a sub-screen
      if (currentTab == NavigationTab.settings) {
        return _buildSettingsContent(settingsScreen);
      }

      // If we're in home tab, check if we're viewing a sub-screen
      if (currentTab == NavigationTab.home) {
        return _buildHomeContent(homeScreen);
      }

      return switch (currentTab) {
        NavigationTab.home => const HomeScreen(),
        NavigationTab.settings => const SettingsScreen(),
        NavigationTab.apiConfig => const ApiConfigScreen(),
        NavigationTab.about => const AboutScreen(),
      };
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If we're in a home sub-screen (not dashboard), pop back to dashboard
        if (currentTab == NavigationTab.home &&
            homeScreen != HomeSubScreen.dashboard) {
          ref.read(currentHomeScreenProvider.notifier).state =
              HomeSubScreen.dashboard;
          return;
        }

        // If we're in a settings sub-screen, pop back to main settings
        if (currentTab == NavigationTab.settings &&
            settingsScreen != SettingsSubScreen.main) {
          ref.read(currentSettingsScreenProvider.notifier).state =
              SettingsSubScreen.main;
          return;
        }

        // If we're not on home tab, go back to home
        if (currentTab != NavigationTab.home) {
          ref.read(currentTabProvider.notifier).state = NavigationTab.home;
          ref.read(navigationStackProvider.notifier).state =
              NavigationStack(initialHistory: [NavigationTab.home]);
          ref.read(currentSettingsScreenProvider.notifier).state =
              SettingsSubScreen.main;
          ref.read(currentHomeScreenProvider.notifier).state =
              HomeSubScreen.dashboard;
          return;
        }

        // On home tab with dashboard, show exit confirmation
        final shouldExit = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.3),
          builder: (context) => AlertDialog(
            title: const Text('Exit AudioGuard?'),
            content: const Text('Are you sure you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          // Exit the app immediately
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: buildMainContent(),
        bottomNavigationBar: GlassyBottomNav(
          currentTab: currentTab,
          onTabChanged: (tab) {
            ref.read(currentTabProvider.notifier).state = tab;
            ref.read(navigationStackProvider.notifier).state =
                navigationStack.push(tab);
            // Reset sub-screens when switching tabs
            ref.read(currentSettingsScreenProvider.notifier).state =
                SettingsSubScreen.main;
            ref.read(currentHomeScreenProvider.notifier).state =
                HomeSubScreen.dashboard;
          },
        ),
      ),
    );
  }

  Widget _buildHomeContent(HomeSubScreen screen) {
    return switch (screen) {
      HomeSubScreen.dashboard => const HomeScreen(),
      HomeSubScreen.encode => const EncodeScreen(),
      HomeSubScreen.decode => const DecodeScreen(),
      HomeSubScreen.verify => const VerifyScreen(),
      HomeSubScreen.analyze => const AnalyzeScreen(),
    };
  }

  Widget _buildSettingsContent(SettingsSubScreen screen) {
    return switch (screen) {
      SettingsSubScreen.main => const SettingsScreen(),
      SettingsSubScreen.appearance => const AppearanceSettingsScreen(),
      SettingsSubScreen.apiConfig => const ApiConfigScreen(),
      SettingsSubScreen.about => const AboutScreen(),
    };
  }
}
