import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/skins.dart';
import '../models/meta.dart';
import '../providers/addon_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/library_provider.dart';
import '../providers/skin_provider.dart';
import '../widgets/common.dart';
import '../widgets/content_row.dart';
import '../widgets/hero_carousel.dart';

/// Home: hero carousel + Continue Watching + catalog rails.
///
/// The header changes per skin: HBO is header-less so the hero runs under the
/// status bar, Netflix gets working All / Movies / Series filters, Apple TV
/// gets a large "Watch Now" title.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// null = everything, otherwise 'movie' or 'series'.
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final addons = context.read<AddonProvider>();
    await addons.init();
    if (!mounted) return;
    await context.read<CatalogProvider>().loadHome(addons.addons, force: force);
  }

  List<MetaItem> _filtered(List<MetaItem> items) {
    if (_typeFilter == null) return items;
    return items.where((item) => item.type == _typeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = context.watch<CatalogProvider>();
    final library = context.watch<LibraryProvider>();
    final skin = context.skin;
    final r = Responsive.of(context);

    final continueWatching = _filtered(
      library.continueWatching.map((p) => p.meta).toList(),
    );

    final rails = <Widget>[];
    for (final row in catalogs.rows) {
      final items = _filtered(row.items);
      if (items.isEmpty) continue;
      rails.add(ContentRow(title: row.title, items: items));
    }

    final hasContent = catalogs.rows.isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        color: skin.accent,
        backgroundColor: skin.surface,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            ..._header(skin, r),
            if (catalogs.loading && !hasContent)
              const SliverToBoxAdapter(child: _HomeLoading())
            else if (catalogs.error != null && !hasContent)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _HomeError(
                  message: catalogs.error!,
                  onRetry: () => _load(force: true),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: HeroCarousel(items: _filtered(catalogs.heroItems)),
              ),
              if (continueWatching.isNotEmpty)
                SliverToBoxAdapter(
                  child: ContentRow(
                    title: 'Continue Watching',
                    items: continueWatching.take(15).toList(),
                  ),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => rails[index],
                  childCount: rails.length,
                ),
              ),
              if (rails.isEmpty && hasContent)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.gutter,
                      vertical: 40,
                    ),
                    child: Text(
                      'Nothing here for this filter yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: skin.textSecondary),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: r.bottomSafePadding)),
            ],
          ],
        ),
      ),
    );
  }

  /// Skin specific home header.
  List<Widget> _header(SkinData skin, Responsive r) {
    switch (skin.headerStyle) {
      // HBO Max: no app bar at all, the hero bleeds under the status bar.
      case HomeHeaderStyle.minimal:
        return const [];

      // Netflix: real content filters, not decoration.
      case HomeHeaderStyle.netflixChips:
        return [
          SliverAppBar(
            floating: true,
            pinned: false,
            toolbarHeight: 54,
            titleSpacing: 0,
            backgroundColor: skin.bg.withOpacity(0.92),
            title: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _typeFilter == null,
                    onTap: () => setState(() => _typeFilter = null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Movies',
                    selected: _typeFilter == 'movie',
                    onTap: () => setState(() => _typeFilter = 'movie'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Series',
                    selected: _typeFilter == 'series',
                    onTap: () => setState(() => _typeFilter = 'series'),
                  ),
                ],
              ),
            ),
          ),
        ];

      // Apple TV: large left aligned title.
      case HomeHeaderStyle.appleLargeTitle:
        return [
          SliverAppBar(
            floating: true,
            pinned: false,
            centerTitle: false,
            toolbarHeight: 58,
            titleSpacing: r.gutter,
            backgroundColor: skin.bg.withOpacity(0.85),
            title: Text(
              skin.navLabels.first,
              style: TextStyle(
                fontSize: r.isSmall ? 24 : 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: skin.textPrimary,
              ),
            ),
          ),
        ];
    }
  }
}

/// Netflix style pill filter.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.white : skin.textSecondary.withOpacity(0.7),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : skin.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PulseBox(
          width: double.infinity,
          height: r.heroHeight,
          borderRadius: BorderRadius.zero,
        ),
        for (var row = 0; row < 2; row++) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(r.gutter, 20, r.gutter, 10),
            child: const PulseBox(width: 150, height: 18),
          ),
          SizedBox(
            height: r.railHeight,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, __) => SizedBox(width: r.isSmall ? 8 : 10),
              itemBuilder: (_, __) => PulseBox(
                width: r.railPosterWidth,
                height: r.railPosterWidth * 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HomeError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 46, color: skin.textSecondary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: skin.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
