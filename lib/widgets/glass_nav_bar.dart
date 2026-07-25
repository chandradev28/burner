import 'dart:ui';

import 'package:flutter/material.dart';

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
/// Real frosted glass: the content behind it is blurred with a [BackdropFilter],
/// then layered with a translucent gradient, a specular top highlight and a
/// hairline border so it reads as a floating pane of glass rather than a
/// flat translucent box. The active tab gets an animated gradient pill.
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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset > 0 ? 10 : 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          // The actual glass: blur + slight desaturation of whatever scrolls behind.
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              // Translucent tint, lighter at the top like a lit glass edge.
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
                // Faint brand glow under the glass.
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
                // Specular highlight running along the top edge.
                Positioned(
                  top: 0,
                  left: 24,
                  right: 24,
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
  final VoidCallback onTap;

  const _GlassNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: BurnerColors.purple.withOpacity(0.18),
      highlightColor: Colors.white.withOpacity(0.04),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // Active tab sits on a soft gradient pill, like light pooling in glass.
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              scale: selected ? 1.08 : 1.0,
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 22,
                color: selected
                    ? Colors.white
                    : BurnerColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : BurnerColors.textSecondary,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
