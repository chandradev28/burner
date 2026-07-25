import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/meta.dart';
import '../providers/addon_provider.dart';
import '../providers/library_provider.dart';
import '../services/addon_client.dart';
import '../widgets/common.dart';
import '../widgets/episode_tile.dart';
import '../widgets/stream_sheet.dart';

/// Immersive detail page: backdrop art, logo/title, Play + My List,
/// synopsis, cast, and (for series) a season picker with episode list.
class DetailScreen extends StatefulWidget {
  final MetaItem item;
  final bool autoPlay;

  const DetailScreen({super.key, required this.item, this.autoPlay = false});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  MetaItem? _meta; // full meta (with videos) once loaded
  bool _loading = true;
  int? _selectedSeason;
  bool _autoPlayTriggered = false;

  MetaItem get meta => _meta ?? widget.item;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final addons = context.read<AddonProvider>().addons;
    MetaItem? full;
    try {
      full = await AddonClient.resolveMeta(
          addons, widget.item.type, widget.item.id);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _meta = full ?? widget.item;
      _loading = false;
      _selectedSeason = _defaultSeason();
    });
    _maybeAutoPlay();
  }

  int? _defaultSeason() {
    final seasons = _seasons();
    if (seasons.isEmpty) return null;
    // Prefer season 1 over specials (season 0).
    return seasons.firstWhere((s) => s != 0, orElse: () => seasons.first);
  }

  List<int> _seasons() {
    final seasons = meta.videos
        .map((v) => v.season)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    // Move specials (0) to the end.
    if (seasons.contains(0)) {
      seasons
        ..remove(0)
        ..add(0);
    }
    return seasons;
  }

  List<Video> _episodesForSeason(int? season) {
    final eps = meta.videos.where((v) => v.season == season).toList()
      ..sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
    return eps;
  }

  void _maybeAutoPlay() {
    if (!widget.autoPlay || _autoPlayTriggered) return;
    _autoPlayTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPlay());
  }

  void _onPlay() {
    final library = context.read<LibraryProvider>();
    if (meta.isSeries) {
      // Resume last watched episode if any, else first released episode.
      final progress = library.progressFor(meta.type, meta.id);
      if (progress?.videoId != null) {
        showStreamSheet(context,
            meta: meta,
            videoId: progress!.videoId!,
            videoLabel: progress.videoLabel);
        return;
      }
      final episodes = _episodesForSeason(_selectedSeason)
          .where((e) => e.isReleased)
          .toList();
      if (episodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No released episodes found for this season.')));
        return;
      }
      final first = episodes.first;
      showStreamSheet(context,
          meta: meta,
          videoId: first.id,
          videoLabel: '${first.code} \u2022 ${first.name}');
    } else {
      showStreamSheet(context, meta: meta, videoId: meta.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final inList = library.isInWatchlist(meta);
    final art = meta.background ?? meta.poster;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: width * 0.62,
            pinned: true,
            backgroundColor: BurnerColors.bg,
            leading: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
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
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meta.logo != null)
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxHeight: 64, maxWidth: 240),
                      child: CachedNetworkImage(
                        imageUrl: meta.logo!,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        errorWidget: (_, __, ___) => _title(),
                      ),
                    )
                  else
                    _title(),
                  const SizedBox(height: 10),
                  Text(
                    [
                      if (meta.releaseInfo != null) meta.releaseInfo!,
                      if (meta.imdbRating != null)
                        '\u2605 ${meta.imdbRating} IMDb',
                      if (meta.runtime != null) meta.runtime!,
                      if (meta.isSeries) 'Series',
                    ].join('  \u2022  '),
                    style: const TextStyle(
                        color: BurnerColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  if (meta.genres.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: meta.genres
                          .take(5)
                          .map((g) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: BurnerColors.stroke),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(g,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: BurnerColors.textSecondary)),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: meta.isSeries ? 'Play' : 'Play movie',
                          icon: Icons.play_arrow_rounded,
                          expanded: true,
                          onPressed: _loading ? null : _onPlay,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CircleIconButton(
                        icon: inList
                            ? Icons.check_rounded
                            : Icons.add_rounded,
                        filled: inList,
                        onTap: () => library.toggleWatchlist(meta),
                      ),
                    ],
                  ),
                  if (meta.description != null &&
                      meta.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      meta.description!,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: BurnerColors.textPrimary),
                    ),
                  ],
                  if (meta.cast.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _MetaLine(label: 'Cast', value: meta.cast.join(', ')),
                  ],
                  if (meta.director.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _MetaLine(
                        label: 'Director', value: meta.director.join(', ')),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                    child: CircularProgressIndicator(
                        color: BurnerColors.purple)),
              ),
            )
          else if (meta.isSeries) ...[
            SliverToBoxAdapter(child: _seasonPicker()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final episode =
                      _episodesForSeason(_selectedSeason)[index];
                  final library = context.read<LibraryProvider>();
                  final progress =
                      library.progressFor(meta.type, meta.id);
                  final watchedFraction = progress?.videoId == episode.id
                      ? progress!.fraction
                      : 0.0;
                  return EpisodeTile(
                    video: episode,
                    progress: watchedFraction,
                    onTap: () => showStreamSheet(
                      context,
                      meta: meta,
                      videoId: episode.id,
                      videoLabel:
                          '${episode.code} \u2022 ${episode.name}',
                    ),
                  );
                },
                childCount: _episodesForSeason(_selectedSeason).length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Widget _title() {
    return Text(
      meta.name,
      style: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w800, height: 1.1),
    );
  }

  Widget _seasonPicker() {
    final seasons = _seasons();
    if (seasons.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No episode information available.',
            style: TextStyle(color: BurnerColors.textSecondary)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Text('Episodes',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: BurnerColors.card,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedSeason,
                dropdownColor: BurnerColors.card,
                borderRadius: BorderRadius.circular(10),
                items: seasons
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                              s == 0 ? 'Specials' : 'Season $s',
                              style: const TextStyle(fontSize: 13.5)),
                        ))
                    .toList(),
                onChanged: (s) => setState(() => _selectedSeason = s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetaLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: BurnerColors.textSecondary),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: BurnerColors.textPrimary)),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _CircleIconButton(
      {required this.icon, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: filled ? BurnerColors.purple : Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
