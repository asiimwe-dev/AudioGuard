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
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    NavigationTab tab,
    IconData icon,
  ) {
    final isSelected = currentTab == tab;

    return GestureDetector(
      onTap: () => onTabChanged(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.black
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.black
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
