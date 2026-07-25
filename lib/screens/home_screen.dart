import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../providers/addon_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/common.dart';
import '../widgets/content_row.dart';
import '../widgets/hero_carousel.dart';

/// Home: hero carousel + Continue Watching + catalog rails.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  @override
  Widget build(BuildContext context) {
    final catalogs = context.watch<CatalogProvider>();
    final library = context.watch<LibraryProvider>();
    final continueWatching = library.continueWatching;

    return Scaffold(
      body: RefreshIndicator(
        color: BurnerColors.purple,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: true,
              backgroundColor: BurnerColors.bg.withOpacity(0.85),
              title: const GradientText(
                BurnerConstants.appName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
            if (catalogs.loading && catalogs.rows.isEmpty)
              const SliverToBoxAdapter(child: _HomeLoading())
            else if (catalogs.error != null && catalogs.rows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _HomeError(
                  message: catalogs.error!,
                  onRetry: () => _load(force: true),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: HeroCarousel(items: catalogs.heroItems),
              ),
              if (continueWatching.isNotEmpty)
                SliverToBoxAdapter(
                  child: ContentRow(
                    title: 'Continue Watching',
                    items:
                        continueWatching.map((p) => p.meta).take(15).toList(),
                  ),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final row = catalogs.rows[index];
                    return ContentRow(title: row.title, items: row.items);
                  },
                  childCount: catalogs.rows.length,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: Responsive.of(context).bottomSafePadding),
              ),
            ],
          ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 46, color: BurnerColors.textSecondary),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: BurnerColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            GradientButton(
                label: 'Retry', icon: Icons.refresh_rounded,
                onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
