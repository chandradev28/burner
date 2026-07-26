import 'package:flutter/material.dart';

import '../providers/skin_provider.dart';

/// Text filled with the active skin's brand gradient.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;

  /// Defaults to the current skin's brand gradient.
  final Gradient? gradient;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? context.skin.brand;
    return ShaderMask(
      shaderCallback: (bounds) => g.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// Primary action button. Renders per skin:
/// HBO = purple/blue gradient, Netflix = square white, Apple TV = white pill.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expanded;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final radius = skin.buttonBorderRadius;
    final fg = skin.gradientPrimaryButton
        ? Colors.white
        : skin.primaryButtonTextColor;

    final child = DecoratedBox(
      decoration: BoxDecoration(
        gradient: skin.gradientPrimaryButton ? skin.brand : null,
        color: skin.gradientPrimaryButton ? null : skin.primaryButtonColor,
        borderRadius: radius,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: skin.isAppleTv ? 24 : 20,
          vertical: skin.isAppleTv ? 13 : 12,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: skin.isAppleTv ? -0.2 : 0,
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onPressed, child: child),
    );
  }
}

/// Secondary button. HBO = outlined, Netflix = translucent grey fill,
/// Apple TV = frosted pill.
class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final radius = skin.buttonBorderRadius;

    if (skin.isHbo) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: skin.textPrimary,
          side: BorderSide(color: skin.stroke),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      );
    }

    final fill = skin.isNetflix
        ? Colors.white.withOpacity(0.16)
        : Colors.white.withOpacity(0.12);

    return Material(
      color: fill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: skin.isAppleTv ? 22 : 18,
            vertical: skin.isAppleTv ? 13 : 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: skin.textPrimary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: skin.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: skin.isAppleTv ? -0.2 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple pulsing placeholder used while content loads (no extra deps).
class PulseBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const PulseBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<PulseBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.35,
    upperBound: 0.9,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: skin.card,
          borderRadius: widget.borderRadius ?? skin.posterBorderRadius,
        ),
      ),
    );
  }
}
