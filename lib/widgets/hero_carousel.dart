import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/skins.dart';
import '../models/meta.dart';
import '../providers/skin_provider.dart';
import '../screens/detail_screen.dart';
import 'common.dart';

/// Auto-advancing featured carousel. The layout itself changes with the skin:
///
/// * HBO Max  - full-bleed landscape backdrop, left aligned title, gradient fade
/// * Netflix  - tall portrait key art, centered logo and genre dot list
/// * Apple TV - inset rounded card with a FEATURED eyebrow label
class HeroCarousel extends StatefulWidget {
  final List<MetaItem> items;

  const HeroCarousel({super.key, required this.items});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _openDetail(MetaItem item, {bool autoPlay = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(item: item, autoPlay: autoPlay),
      ),
    );
  }

  double _heightFor(SkinData skin, Responsive r) {
    switch (skin.heroStyle) {
      case HeroStyle.netflixPortrait:
        final tall = r.heroHeight * 1.14;
        final cap = r.height * 0.68;
        return (tall < cap ? tall : cap).clamp(320.0, 620.0).toDouble();
      case HeroStyle.appleWideCard:
        return (r.heroHeight * 0.94).clamp(280.0, 520.0).toDouble();
      case HeroStyle.cinematicGradient:
        return r.heroHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final skin = context.skin;
    final r = Responsive.of(context);
    final height = _heightFor(skin, r);

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              switch (skin.heroStyle) {
                case HeroStyle.cinematicGradient:
                  return _cinematicSlide(item, skin, r);
                case HeroStyle.netflixPortrait:
                  return _netflixSlide(item, skin, r);
                case HeroStyle.appleWideCard:
                  return _appleSlide(item, skin, r);
              }
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: skin.isAppleTv ? 6 : 22,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.items.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? (skin.isNetflix ? 8 : 18) : 6,
                  height: skin.isNetflix ? 8 : 6,
                  decoration: BoxDecoration(
                    color: active
                        ? (skin.isNetflix ? Colors.white : skin.accent)
                        : skin.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(skin.isNetflix ? 8 : 3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- HBO Max
  Widget _cinematicSlide(MetaItem item, SkinData skin, Responsive r) {
    return GestureDetector(
      onTap: () => _openDetail(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _art(item.background ?? item.poster, skin),
          DecoratedBox(decoration: BoxDecoration(gradient: skin.heroOverlay)),
          Positioned(
            left: r.gutter,
            right: r.gutter,
            bottom: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _logoOrTitle(item, skin, r, centered: false),
                const SizedBox(height: 8),
                Text(
                  _metaLine(item),
                  style: TextStyle(
                    color: skin.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                _actions(item, centered: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Netflix
  Widget _netflixSlide(MetaItem item, SkinData skin, Responsive r) {
    return GestureDetector(
      onTap: () => _openDetail(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Netflix leads with portrait key art rather than a wide backdrop.
          _art(item.poster ?? item.background, skin),
          DecoratedBox(decoration: BoxDecoration(gradient: skin.heroOverlay)),
          Positioned(
            left: r.gutter,
            right: r.gutter,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _logoOrTitle(item, skin, r, centered: true),
                const SizedBox(height: 10),
                Text(
                  _genreLine(item),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _actions(item, centered: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Apple TV
  Widget _appleSlide(MetaItem item, SkinData skin, Responsive r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.gutter, 4, r.gutter, 20),
      child: GestureDetector(
        onTap: () => _openDetail(item),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(skin.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _art(item.background ?? item.poster, skin),
              DecoratedBox(decoration: BoxDecoration(gradient: skin.heroOverlay)),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FEATURED',
                      style: TextStyle(
                        color: skin.accentAlt,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _logoOrTitle(item, skin, r, centered: false),
                    const SizedBox(height: 6),
                    Text(
                      _metaLine(item),
                      style: TextStyle(
                        color: skin.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _actions(item, centered: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- helpers
  Widget _art(String? url, SkinData skin) {
    if (url == null) return Container(color: skin.card);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: skin.card),
      errorWidget: (_, __, ___) => Container(color: skin.card),
    );
  }

  String _metaLine(MetaItem item) {
    return [
      if (item.year.isNotEmpty) item.year,
      if (item.imdbRating != null) '\u2605 ${item.imdbRating}',
      ...item.genres.take(2),
    ].join('  \u2022  ');
  }

  String _genreLine(MetaItem item) {
    final parts = item.genres.take(3).toList();
    if (parts.isEmpty) {
      return [
        if (item.year.isNotEmpty) item.year,
        item.isSeries ? 'Series' : 'Movie',
      ].join('  \u2022  ');
    }
    return parts.join('  \u2022  ');
  }

  Widget _logoOrTitle(
    MetaItem item,
    SkinData skin,
    Responsive r, {
    required bool centered,
  }) {
    if (item.logo != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: skin.isNetflix ? 96 : 72,
          maxWidth: centered ? r.width * 0.72 : 240,
        ),
        child: CachedNetworkImage(
          imageUrl: item.logo!,
          fit: BoxFit.contain,
          alignment: centered ? Alignment.bottomCenter : Alignment.bottomLeft,
          errorWidget: (_, __, ___) => _titleText(item, skin, r, centered),
        ),
      );
    }
    return _titleText(item, skin, r, centered);
  }

  Widget _titleText(
    MetaItem item,
    SkinData skin,
    Responsive r,
    bool centered,
  ) {
    final size = (r.isSmall ? 25.0 : 30.0) * (skin.isAppleTv ? 0.92 : 1.0);
    return Text(
      item.name,
      maxLines: 2,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: skin.isAppleTv ? -0.6 : 0,
        color: Colors.white,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
      ),
    );
  }

  Widget _actions(MetaItem item, {required bool centered}) {
    return Row(
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        GradientButton(
          label: 'Play',
          icon: Icons.play_arrow_rounded,
          onPressed: () => _openDetail(item, autoPlay: true),
        ),
        const SizedBox(width: 10),
        GhostButton(
          label: 'More info',
          icon: Icons.info_outline_rounded,
          onPressed: () => _openDetail(item),
        ),
      ],
    );
  }
}
