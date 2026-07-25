import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/meta.dart';
import 'poster_card.dart';

/// A titled horizontal rail of posters (HBO Max style).
class ContentRow extends StatelessWidget {
  final String title;
  final List<MetaItem> items;

  const ContentRow({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final r = Responsive.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.gutter, 20, r.gutter, 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: r.isSmall ? 15.5 : 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(
          height: r.railHeight,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: r.gutter),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: r.isSmall ? 8 : 10),
            itemBuilder: (context, index) => PosterCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}
