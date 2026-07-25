import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';

/// A single destination in the [GlassNavBar].
class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Global "liquid glass" footer navigation bar.
///
/// Sizing is fully responsive and safe-area aware: the bar floats above the
/// system gesture bar / navigation buttons instead of being clipped by them.
class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final horizontal = r.isTablet ? r.width * 0.18 : r.gutter;
    final radius = r.navBarHeight / 2 + 4;

    return Padding(
      // Reserve the real system inset so the bar is never cut off.
      padding: EdgeInsets.fromLTRB(
        horizontal,
        0,
        horizontal,
        r.bottomInset + r.navBarBottomMargin,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: r.navBarHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.05),
                  BurnerColors.bg.withOpacity(0.55),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: BurnerColors.purple.withOpacity(0.18),
                  blurRadius: 34,
                  spreadRadius: -12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: radius,
                  right: radius,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0),
                          Colors.white.withOpacity(0.55),
                          Colors.white.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _GlassNavButton(
                          item: items[i],
                          selected: i == currentIndex,
                          compact: r.isSmall,
                          onTap: () => onTap(i),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavButton extends StatelessWidget {
  final GlassNavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _GlassNavButton({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 19.0 : 21.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: BurnerColors.purple.withOpacity(0.18),
      highlightColor: Colors.white.withOpacity(0.04),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(horizontal: compact ? 3 : 6, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    BurnerColors.purple.withOpacity(0.42),
                    BurnerColors.blue.withOpacity(0.30),
                  ],
                )
              : null,
          border: selected
              ? Border.all(color: Colors.white.withOpacity(0.18))
              : null,
        ),
        // FittedBox guarantees the icon+label never overflow the bar height,
        // regardless of the user's system font scale.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  scale: selected ? 1.08 : 1.0,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: iconSize,
                    color:
                        selected ? Colors.white : BurnerColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  style: TextStyle(
                    fontSize: compact ? 9.5 : 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? Colors.white : BurnerColors.textSecondary,
                  ),
                  child: Text(item.label, maxLines: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
