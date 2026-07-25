import 'package:flutter/material.dart';

/// Central sizing logic so every screen scales correctly from small phones
/// (320dp) up to tablets, instead of using hard-coded pixel values.
class Responsive {
  final double width;
  final double height;
  final double bottomInset;
  final double topInset;

  const Responsive._({
    required this.width,
    required this.height,
    required this.bottomInset,
    required this.topInset,
  });

  factory Responsive.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Responsive._(
      width: mq.size.width,
      height: mq.size.height,
      // viewPadding (not padding) so we always see the real system inset,
      // even when Scaffold has already consumed it.
      bottomInset: mq.viewPadding.bottom,
      topInset: mq.viewPadding.top,
    );
  }

  bool get isSmall => width < 360;
  bool get isTablet => width >= 600;

  /// Horizontal page gutter.
  double get gutter => isTablet ? 24 : (isSmall ? 12 : 16);

  /// Poster width for horizontal rails — derived from screen width so
  /// roughly the same number of posters is visible on every device.
  double get railPosterWidth {
    final target = isTablet ? width / 6.5 : width / 3.25;
    return target.clamp(96.0, 170.0);
  }

  /// Rail height = poster (2:3) + breathing room.
  double get railHeight => railPosterWidth * 1.5 + 8;

  /// Grid columns for search / watchlist.
  int get gridColumns {
    if (width >= 1000) return 6;
    if (width >= 720) return 5;
    if (width >= 600) return 4;
    if (width < 340) return 2;
    return 3;
  }

  /// Hero must never eat the whole screen on short devices, and never
  /// become absurdly tall on tablets.
  double get heroHeight {
    final byHeight = height * 0.52;
    final byWidth = width * 1.25;
    final value = byHeight < byWidth ? byHeight : byWidth;
    return value.clamp(300.0, 560.0);
  }

  /// Height of the floating glass nav bar itself (without safe area).
  double get navBarHeight => isSmall ? 58 : 62;

  /// Outer margin below the glass bar.
  double get navBarBottomMargin => bottomInset > 0 ? 8 : 12;

  /// Total space the footer occupies — every scrollable must reserve this
  /// as bottom padding so content is never hidden behind the glass.
  double get bottomSafePadding =>
      navBarHeight + navBarBottomMargin + bottomInset + 12;
}
