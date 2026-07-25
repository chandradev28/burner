import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/meta.dart';
import '../screens/detail_screen.dart';

/// Poster tile (2:3) used in rails, grids and search results.
class PosterCard extends StatelessWidget {
  final MetaItem item;
  final double width;
  final bool showTitle;

  const PosterCard({
    super.key,
    required this.item,
    this.width = 118,
    this.showTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
        );
      },
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.poster != null
                    ? CachedNetworkImage(
                        imageUrl: item.poster!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: BurnerColors.card),
                        errorWidget: (_, __, ___) => _fallback(),
                      )
                    : _fallback(),
              ),
            ),
            if (showTitle) ...[
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: BurnerColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: BurnerColors.card,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        item.name,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: BurnerColors.textSecondary,
        ),
      ),
    );
  }
}
