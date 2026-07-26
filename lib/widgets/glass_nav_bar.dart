import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/skins.dart';
import '../providers/skin_provider.dart';

/// A single destination in the global footer.
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

/// Global footer navigation. Renders one of three completely different bars
/// depending on the active skin:
///
/// * HBO Max  - floating liquid-glass pill with a gradient selection chip
/// * Netflix  - edge-to-edge flat black bar with a hairline top border
/// * Apple TV - edge-to-edge frosted blur tab bar with a blue active tint
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
    final skin = context.skin;
    final r = Responsive.of(context);

    switch (skin.navStyle) {
      case NavStyle.glassPill:
        return _buildGlassPill(context, skin, r);
      case NavStyle.flatBar:
        return _buildFlatBar(context, skin, r);
      case NavStyle.frostedTab:
        return _buildFrostedTab(context, skin, r);
    }
  }

  // ------------------------------------------------------------- HBO Max
  Widget _buildGlassPill(BuildContext context, SkinData skin, Responsive r) {
    final horizontal = r.isTablet ? r.width * 0.18 : r.gutter;
    final radius = r.navBarHeight / 2 + 4;

    return Padding(
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
                  skin.bg.withOpacity(0.55),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: skin.accent.withOpacity(0.18),
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
                _row(context, skin, r, highlightChip: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Netflix
  Widget _buildFlatBar(BuildContext context, SkinData skin, Responsive r) {
    return Container(
      decoration: BoxDecoration(
        color: skin.bg.withOpacity(0.97),
        border: Border(top: BorderSide(color: skin.stroke, width: 0.6)),
      ),
      padding: EdgeInsets.only(bottom: r.bottomInset),
      child: SizedBox(
        height: r.navBarHeight,
        child: _row(context, skin, r, highlightChip: false),
      ),
    );
  }

  // ------------------------------------------------------------ Apple TV
  Widget _buildFrostedTab(BuildContext context, SkinData skin, Responsive r) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: skin.bg.withOpacity(0.62),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.10), width: 0.5),
            ),
          ),
          padding: EdgeInsets.only(bottom: r.bottomInset),
          child: SizedBox(
            height: r.navBarHeight,
            child: _row(context, skin, r, highlightChip: false),
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    SkinData skin,
    Responsive r, {
    required bool highlightChip,
  }) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: _NavButton(
              item: items[i],
              skin: skin,
              selected: i == currentIndex,
              compact: r.isSmall,
              highlightChip: highlightChip,
              onTap: () => onTap(i),
            ),
          ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final GlassNavItem item;
  final SkinData skin;
  final bool selected;
  final bool compact;
  final bool highlightChip;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.skin,
    required this.selected,
    required this.compact,
    required this.highlightChip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 19.0 : 21.0;
    // Apple TV tints the active tab blue; HBO and Netflix go bright white.
    final activeColor = skin.isAppleTv ? skin.accent : Colors.white;
    final color = selected ? activeColor : skin.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: skin.accent.withOpacity(0.18),
      highlightColor: Colors.white.withOpacity(0.04),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(horizontal: compact ? 3 : 6, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: highlightChip && selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    skin.accent.withOpacity(0.42),
                    skin.accentAlt.withOpacity(0.30),
                  ],
                )
              : null,
          border: highlightChip && selected
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
                  scale: selected && !skin.isNetflix ? 1.08 : 1.0,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: iconSize,
                    color: color,
                  ),
                ),
                SizedBox(height: skin.isAppleTv ? 3 : 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  style: TextStyle(
                    fontSize: compact ? 9.5 : 10.5,
                    fontWeight: selected
                        ? (skin.isAppleTv ? FontWeight.w600 : FontWeight.w700)
                        : FontWeight.w500,
                    letterSpacing: skin.isAppleTv ? -0.1 : 0,
                    color: color,
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
