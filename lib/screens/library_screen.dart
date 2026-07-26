import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../providers/library_provider.dart';
import '../providers/skin_provider.dart';
import '../widgets/poster_card.dart';
import 'detail_screen.dart';
import 'player_screen.dart';

/// Continue Watching + saved list. The screen title and the second tab name
/// follow the active skin ("My Stuff", "My List" or "Library").
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: skin.bg,
          title: Text(
            skin.navLabels[2],
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: skin.isAppleTv ? -0.4 : 0,
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Continue Watching'),
              Tab(text: 'Saved'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ContinueWatchingTab(),
            _WatchlistTab(),
          ],
        ),
      ),
    );
  }
}

class _ContinueWatchingTab extends StatelessWidget {
  const _ContinueWatchingTab();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final library = context.watch<LibraryProvider>();
    final entries = library.continueWatching;
    final r = Responsive.of(context);

    if (entries.isEmpty) {
      return const _EmptyState(
        icon: Icons.play_circle_outline_rounded,
        title: 'Nothing in progress',
        subtitle: 'Titles you start watching will show up here.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(r.gutter, 14, r.gutter, r.bottomSafePadding),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Dismissible(
          key: ValueKey(entry.key),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => library.removeProgress(entry),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: skin.danger,
              borderRadius: skin.cardBorderRadius,
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Colors.white),
          ),
          child: _ContinueTile(entry: entry),
        );
      },
    );
  }
}

class _ContinueTile extends StatelessWidget {
  final WatchProgress entry;

  const _ContinueTile({required this.entry});

  void _resume(BuildContext context) {
    if (entry.streamUrl != null && entry.streamUrl!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            streamUrl: entry.streamUrl!,
            title: entry.videoLabel != null
                ? '${entry.meta.name} \u2022 ${entry.videoLabel}'
                : entry.meta.name,
            meta: entry.meta,
            videoId: entry.videoId,
            videoLabel: entry.videoLabel,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(item: entry.meta)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final art = entry.meta.background ?? entry.meta.poster;
    return Material(
      color: skin.card,
      borderRadius: skin.cardBorderRadius,
      child: InkWell(
        borderRadius: skin.cardBorderRadius,
        onTap: () => _resume(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(skin.posterRadius),
                child: SizedBox(
                  width: 128,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      art != null
                          ? CachedNetworkImage(
                              imageUrl: art,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  Container(color: skin.stroke),
                            )
                          : Container(color: skin.stroke),
                      const Center(
                        child: Icon(Icons.play_circle_fill_rounded,
                            color: Colors.white, size: 30),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(
                          value: entry.fraction,
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(skin.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.meta.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14.5)),
                    if (entry.videoLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(entry.videoLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: skin.textSecondary, fontSize: 12.5)),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${(entry.fraction * 100).round()}% watched',
                      style:
                          TextStyle(color: skin.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: skin.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchlistTab extends StatelessWidget {
  const _WatchlistTab();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final items = library.watchlist;

    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.bookmark_add_outlined,
        title: 'Your list is empty',
        subtitle: 'Tap the + button on any movie or show to save it here.',
      );
    }

    final r = Responsive.of(context);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(r.gutter, 14, r.gutter, r.bottomSafePadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: r.gridColumns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 10,
        childAspectRatio: 2 / 3.35,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => PosterCard(
        item: items[index],
        width: double.infinity,
        showTitle: true,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: skin.textSecondary),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: skin.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
