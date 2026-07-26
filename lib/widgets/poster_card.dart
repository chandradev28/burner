import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/meta.dart';
import '../providers/skin_provider.dart';
import '../screens/detail_screen.dart';

/// Poster tile (2:3) used in rails, grids and search results.
/// Corner radius follows the active skin: Netflix is nearly square,
/// Apple TV is heavily rounded, HBO sits in between.
class PosterCard extends StatelessWidget {
  final MetaItem item;

  /// When null the width is derived from the screen size.
  final double? width;
  final bool showTitle;

  const PosterCard({
    super.key,
    required this.item,
    this.width,
    this.showTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
        );
      },
      child: SizedBox(
        width: width ?? Responsive.of(context).railPosterWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: skin.posterBorderRadius,
                child: item.poster != null
                    ? CachedNetworkImage(
                        imageUrl: item.poster!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: skin.card),
                        errorWidget: (_, __, ___) => _fallback(context),
                      )
                    : _fallback(context),
              ),
            ),
            if (showTitle) ...[
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: skin.isAppleTv ? -0.2 : 0,
                  color: skin.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final skin = context.skin;
    return Container(
      color: skin.card,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        item.name,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: skin.textSecondary,
        ),
      ),
    );
  }
}
