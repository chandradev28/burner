import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/meta.dart';
import '../screens/detail_screen.dart';
import 'common.dart';

/// Auto-advancing featured carousel with backdrop art, gradient fade,
/// title/logo and Play / More info actions — HBO Max hero style.
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

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final height = MediaQuery.of(context).size.height * 0.56;

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
              final art = item.background ?? item.poster;
              return GestureDetector(
                onTap: () => _openDetail(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (art != null)
                      CachedNetworkImage(
                        imageUrl: art,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: BurnerColors.card),
                        errorWidget: (_, __, ___) =>
                            Container(color: BurnerColors.card),
                      )
                    else
                      Container(color: BurnerColors.card),
                    const DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: BurnerColors.heroOverlay),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.logo != null)
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxHeight: 72, maxWidth: 240),
                              child: CachedNetworkImage(
                                imageUrl: item.logo!,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomLeft,
                                errorWidget: (_, __, ___) =>
                                    _titleText(item),
                              ),
                            )
                          else
                            _titleText(item),
                          const SizedBox(height: 8),
                          Text(
                            [
                              if (item.year.isNotEmpty) item.year,
                              if (item.imdbRating != null)
                                '\u2605 ${item.imdbRating}',
                              ...item.genres.take(2),
                            ].join('  \u2022  '),
                            style: const TextStyle(
                              color: BurnerColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              GradientButton(
                                label: 'Play',
                                icon: Icons.play_arrow_rounded,
                                onPressed: () =>
                                    _openDetail(item, autoPlay: true),
                              ),
                              const SizedBox(width: 10),
                              GhostButton(
                                label: 'More info',
                                icon: Icons.info_outline_rounded,
                                onPressed: () => _openDetail(item),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Page indicator dots.
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.items.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? BurnerColors.purple
                        : BurnerColors.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleText(MetaItem item) {
    return Text(
      item.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.05,
        shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
      ),
    );
  }
}
