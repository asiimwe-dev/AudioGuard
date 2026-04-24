import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigation tabs for bottom navigation
enum NavigationTab {
  home('Home'),
  settings('Settings'),
  apiConfig('API Config'),
  about('About');

  final String label;

  const NavigationTab(this.label);
}

/// Provider for tracking current navigation tab
final currentTabProvider = StateProvider<NavigationTab>((ref) {
  return NavigationTab.home;
});

/// Provider for managing screen history/stack for back button handling
class NavigationStack {
  final List<NavigationTab> history;

  NavigationStack({List<NavigationTab>? initialHistory})
      : history = initialHistory ?? [NavigationTab.home];

  NavigationStack push(NavigationTab tab) {
    final newHistory = List<NavigationTab>.from(history);
    if (newHistory.isNotEmpty && newHistory.last != tab) {
      newHistory.add(tab);
    }
    return NavigationStack(initialHistory: newHistory);
  }

  NavigationStack pop() {
    final newHistory = List<NavigationTab>.from(history);
    if (newHistory.length > 1) {
      newHistory.removeLast();
    }
    return NavigationStack(initialHistory: newHistory);
  }

  NavigationTab get current => history.isNotEmpty ? history.last : NavigationTab.home;
  bool get canPop => history.length > 1;
}

/// Provider for screen history to handle back button
final navigationStackProvider = StateProvider<NavigationStack>((ref) {
  return NavigationStack();
});

/// Provider to check if we can pop the current screen
final canPopProvider = Provider<bool>((ref) {
  return ref.watch(navigationStackProvider).canPop;
});

/// Provider for the current screen within a tab (for sub-navigation)
enum SettingsSubScreen {
  main,
  appearance,
  apiConfig,
  about,
}

final currentSettingsScreenProvider = StateProvider<SettingsSubScreen>((ref) {
  return SettingsSubScreen.main;
});

/// Provider for home sub-screens (Encode, Decode, Verify, Analyze, or Dashboard)
enum HomeSubScreen {
  dashboard,
  encode,
  decode,
  verify,
  analyze,
}

final currentHomeScreenProvider = StateProvider<HomeSubScreen>((ref) {
  return HomeSubScreen.dashboard;
});
