import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../models/addon.dart';
import '../models/meta.dart';
import '../providers/addon_provider.dart';
import '../providers/skin_provider.dart';
import '../services/addon_client.dart';
import '../widgets/poster_card.dart';
import 'search_results_screen.dart';

/// One search section: the first page of results from a single addon catalog.
class _ResultSection {
  final Addon addon;
  final AddonCatalog catalog;
  final List<MetaItem> items;

  const _ResultSection({
    required this.addon,
    required this.catalog,
    required this.items,
  });
}

/// Debounced search across every installed addon catalog that supports the
/// `search` extra.
///
/// Each catalog contributes its first page here (usually ~24 items). Tap the
/// arrow on a section to open the full list, which keeps paging with `skip`
/// as you scroll.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  List<_ResultSection> _sections = const [];
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    setState(() {
      _query = query;
      _loading = query.isNotEmpty;
      if (query.isEmpty) _sections = const [];
    });
    if (query.isEmpty) return;

    final addons = context.read<AddonProvider>().addons;
    final sections = <_ResultSection>[];

    final futures = <Future<void>>[];
    for (final addon in addons) {
      for (final catalog
          in addon.manifest.catalogs.where((c) => c.supportsSearch)) {
        futures.add(
          AddonClient.searchCatalog(addon, catalog, query).then((items) {
            if (items.isEmpty) return;
            sections.add(_ResultSection(
              addon: addon,
              catalog: catalog,
              items: items,
            ));
            if (!mounted || id != _requestId) return;
            setState(() {
              _loading = false;
              _sections = List.of(sections);
            });
          }).catchError((_) {}),
        );
      }
    }

    await Future.wait(futures);
    if (!mounted || id != _requestId) return;

    setState(() {
      _loading = false;
      _sections = List.of(sections);
    });
  }

  void _openAll(_ResultSection section) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          addon: section.addon,
          catalog: section.catalog,
          query: _query,
          initialItems: section.items,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: skin.bg,
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => _search(v.trim()),
          autofocus: false,
          decoration: InputDecoration(
            hintText: 'Movies, shows, people...',
            prefixIcon: Icon(Icons.search_rounded, color: skin.textSecondary),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: skin.textSecondary),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final skin = context.skin;
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: skin.accent));
    }
    if (_query.isEmpty) {
      return const _SearchHint(
        icon: Icons.local_movies_outlined,
        title: 'Find something to watch',
        subtitle:
            'Search across every installed addon \u2014 movies, series and more.',
      );
    }
    if (_sections.isEmpty) {
      return _SearchHint(
        icon: Icons.search_off_rounded,
        title: 'No results for \u201c$_query\u201d',
        subtitle: 'Try a different title or install more addons.',
      );
    }

    final r = Responsive.of(context);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, 6, 0, r.bottomSafePadding),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        final section = _sections[index];
        return _SectionBlock(
          section: section,
          onSeeAll: () => _openAll(section),
        );
      },
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final _ResultSection section;
  final VoidCallback onSeeAll;

  const _SectionBlock({required this.section, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final r = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.gutter, 14, r.gutter - 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.catalog.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${section.addon.name} \u2022 ${section.items.length} shown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: skin.textSecondary),
                    ),
                  ],
                ),
              ),
              // Arrow into the full, endlessly paged list for this catalog.
              IconButton(
                tooltip: 'See all results',
                onPressed: onSeeAll,
                icon: Icon(Icons.arrow_forward_rounded,
                    size: 20, color: skin.accent),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.gutter),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: r.gridColumns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 2 / 3.35,
            ),
            itemCount: section.items.length,
            itemBuilder: (context, index) => PosterCard(
              item: section.items[index],
              width: double.infinity,
              showTitle: true,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(r.gutter, 12, r.gutter, 4),
          child: SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onSeeAll,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text('See all results from ${section.catalog.name}'),
            ),
          ),
        ),
        Divider(color: skin.stroke, height: 24),
      ],
    );
  }
}

class _SearchHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SearchHint(
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
                textAlign: TextAlign.center,
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
