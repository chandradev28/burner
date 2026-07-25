import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/meta.dart';

/// Episode row: thumbnail + title + overview, HBO Max style.
class EpisodeTile extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final double progress; // 0..1 watched fraction, 0 hides the bar

  const EpisodeTile({
    super.key,
    required this.video,
    required this.onTap,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    final released = video.isReleased;
    return InkWell(
      onTap: released ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: released ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            video.thumbnail != null
                                ? CachedNetworkImage(
                                    imageUrl: video.thumbnail!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) =>
                                        Container(color: BurnerColors.card),
                                    errorWidget: (_, __, ___) =>
                                        Container(color: BurnerColors.card),
                                  )
                                : Container(color: BurnerColors.card),
                            const Center(
                              child: Icon(Icons.play_circle_outline_rounded,
                                  size: 34, color: Colors.white70),
                            ),
                            if (progress > 0)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(
                                      BurnerColors.purple),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.code.isNotEmpty
                          ? '${video.code} \u2022 ${video.name}'
                          : video.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (!released)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Coming soon',
                            style: TextStyle(
                                color: BurnerColors.textSecondary,
                                fontSize: 12)),
                      ),
                    if (video.overview != null &&
                        video.overview!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          video.overview!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BurnerColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
