import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/addon_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/common.dart';
import '../widgets/content_row.dart';
import '../widgets/hero_carousel.dart';
import 'addons_screen.dart';

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
              actions: [
                IconButton(
                  tooltip: 'Manage addons',
                  icon: const Icon(Icons.extension_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddonsScreen()),
                  ),
                ),
              ],
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
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
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
    final height = MediaQuery.of(context).size.height * 0.56;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PulseBox(width: double.infinity, height: height,
            borderRadius: BorderRadius.zero),
        for (var row = 0; row < 2; row++) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: PulseBox(width: 150, height: 18),
          ),
          SizedBox(
            height: 178,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) =>
                  const PulseBox(width: 118, height: 177),
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
