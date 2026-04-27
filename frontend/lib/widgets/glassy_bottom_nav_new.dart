import 'package:flutter/material.dart';
import 'dart:ui';
import '../providers/navigation_provider.dart';

/// Glassy bottom navigation bar with glassmorphism effect and rounded corners
class GlassyBottomNav extends StatelessWidget {
  final NavigationTab currentTab;
  final Function(NavigationTab) onTabChanged;

  const GlassyBottomNav({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          if (isDarkMode)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        theme.colorScheme.surface.withValues(alpha: 0.4),
                        theme.colorScheme.surface.withValues(alpha: 0.2),
                        theme.colorScheme.surface.withValues(alpha: 0.4),
                      ]
                    : [
                        theme.colorScheme.surface.withValues(alpha: 0.8),
                        theme.colorScheme.surface.withValues(alpha: 0.5),
                        theme.colorScheme.surface.withValues(alpha: 0.7),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.12)
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  context,
                  NavigationTab.home,
                  Icons.home_rounded,
                ),
                _buildNavItem(
                  context,
                  NavigationTab.settings,
                  Icons.settings_rounded,
                ),
                _buildNavItem(
                  context,
                  NavigationTab.apiConfig,
                  Icons.cloud_rounded,
                ),
                _buildNavItem(
                  context,
                  NavigationTab.about,
                  Icons.info_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    NavigationTab tab,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isSelected = currentTab == tab;
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onTabChanged(tab),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuint,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: isDarkMode ? 0.85 : 1.0)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(
                        alpha: isDarkMode ? 0.3 : 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.2,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
