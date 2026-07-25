import 'package:flutter/material.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(
          height: 178,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => PosterCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}
