import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/meta.dart';
import '../providers/skin_provider.dart';
import 'poster_card.dart';

/// A titled horizontal rail of posters. Title typography and spacing follow
/// the active skin (Apple TV uses large tight titles, Netflix compact bold).
class ContentRow extends StatelessWidget {
  final String title;
  final List<MetaItem> items;

  const ContentRow({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final r = Responsive.of(context);
    final skin = context.skin;
    final scale = r.isSmall ? 0.92 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            r.gutter,
            skin.isAppleTv ? 24 : 20,
            r.gutter,
            skin.isAppleTv ? 12 : 10,
          ),
          child: Text(
            skin.uppercaseRowTitles ? title.toUpperCase() : title,
            style: TextStyle(
              fontSize: skin.rowTitleSize * scale,
              fontWeight: skin.rowTitleWeight,
              letterSpacing: skin.rowTitleSpacing,
              color: skin.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: r.railHeight,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: r.gutter),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(
              width: skin.isAppleTv ? 12 : (r.isSmall ? 8 : 10),
            ),
            itemBuilder: (context, index) => PosterCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}
