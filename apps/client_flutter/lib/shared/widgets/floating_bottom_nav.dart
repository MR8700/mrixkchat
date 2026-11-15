import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class FloatingBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final int unreadCount;

  const FloatingBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.unreadCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 430;
    final veryCompact = screenWidth < 360;

    final navigationBar = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: veryCompact ? 3 : 6,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surface.withOpacity(0.92)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? theme.colorScheme.outline.withOpacity(0.3)
                : const Color(0xFFDFE4ED).withOpacity(0.9),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.35)
                  : const Color(0xFF111C2C).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(children: [
          Expanded(
              child: _buildNavItem(
            context: context,
            index: 0,
            icon: Icons.chat_bubble,
            label: 'Discussions',
            compactLabel: 'Chats',
            badgeCount: unreadCount,
            compact: compact,
            veryCompact: veryCompact,
          )),
          Expanded(
              child: _buildNavItem(
            context: context,
            index: 1,
            icon: Icons.slow_motion_video,
            label: 'Moments',
            compactLabel: 'Moments',
            compact: compact,
            veryCompact: veryCompact,
          )),
          Expanded(
              child: _buildNavItem(
            context: context,
            index: 2,
            icon: Icons.contacts,
            label: 'Contacts',
            compactLabel: 'Contacts',
            compact: compact,
            veryCompact: veryCompact,
          )),
          Expanded(
              child: _buildNavItem(
            context: context,
            index: 3,
            icon: Icons.auto_awesome,
            label: 'Assistant',
            compactLabel: 'IA',
            hasDot: true,
            compact: compact,
            veryCompact: veryCompact,
          )),
          Expanded(
              child: _buildNavItem(
            context: context,
            index: 4,
            icon: Icons.account_circle,
            label: 'Profil',
            compactLabel: 'Profil',
            compact: compact,
            veryCompact: veryCompact,
          )),
        ]),
      ),
    );

    // Avoid an expensive backdrop blur on narrow phones; it can make scrolling
    // and tab changes stutter on older mobile GPUs.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: veryCompact ? 0 : 4),
      child: compact
          ? navigationBar
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: navigationBar,
            ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required String compactLabel,
    required bool compact,
    required bool veryCompact,
    int? badgeCount,
    bool hasDot = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = selectedIndex == index;
    final activeColor = isDark ? theme.colorScheme.primary : AppTheme.primary;
    final inactiveColor =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.onSurfaceVariant;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: veryCompact ? 1 : (compact ? 3 : 8),
            vertical: 3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: veryCompact ? 38 : 42,
                    height: 27,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : AppTheme.primarySoft)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: activeColor.withOpacity(0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (hasDot)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryGlow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? theme.colorScheme.surface
                                : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                compact ? compactLabel : label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: veryCompact ? 9 : (compact ? 9.5 : 10.5),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
