import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/addon.dart';
import '../models/meta.dart';
import '../providers/skin_provider.dart';
import '../services/addon_client.dart';
import '../widgets/poster_card.dart';

/// Full result list for one catalog + query.
///
/// Opened from the arrow next to a search section. Keeps loading the next page
/// (`skip`) as you scroll, until the addon has nothing left to give.
class SearchResultsScreen extends StatefulWidget {
  final Addon addon;
  final AddonCatalog catalog;
  final String query;

  /// Items already fetched on the search screen, reused so the first page is
  /// instant instead of being requested twice.
  final List<MetaItem> initialItems;

  const SearchResultsScreen({
    super.key,
    required this.addon,
    required this.catalog,
    required this.query,
    this.initialItems = const [],
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<MetaItem> _items = [];
  final Set<String> _seen = <String>{};

  bool _loading = false;
  bool _exhausted = false;
  bool _failed = false;
  int _skip = 0;
  int? _pageSize;

  @override
  void initState() {
    super.initState();
    _absorb(widget.initialItems);
    _skip = _items.length;
    _pageSize = widget.initialItems.isEmpty ? null : widget.initialItems.length;

    _scrollController.addListener(_onScroll);
    if (_items.isEmpty) _loadMore();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Start the next page a screen before the bottom for a seamless feel.
    if (position.pixels >= position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  int _absorb(List<MetaItem> items) {
    var added = 0;
    for (final item in items) {
      if (_seen.add('${item.type}:${item.id}')) {
        _items.add(item);
        added++;
      }
    }
    return added;
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });

    List<MetaItem> page;
    try {
      page = await AddonClient.searchCatalogPage(
        widget.addon,
        widget.catalog,
        widget.query,
        skip: _skip,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;

    final added = _absorb(page);
    _pageSize ??= page.isEmpty ? null : page.length;

    setState(() {
      _loading = false;
      // Empty page, nothing new (addon ignoring skip), or a short page all
      // mean we have reached the end.
      if (page.isEmpty ||
          added == 0 ||
          (_pageSize != null && page.length < _pageSize!) ||
          _items.length >= AddonClient.maxSearchResults) {
        _exhausted = true;
      } else {
        _skip += page.length;
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _seen.clear();
      _skip = 0;
      _pageSize = null;
      _exhausted = false;
      _failed = false;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final r = Responsive.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: skin.bg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${widget.catalog.name} \u2022 ${widget.addon.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: skin.textSecondary),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: skin.accent,
        backgroundColor: skin.surface,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(r.gutter, 12, r.gutter, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  _exhausted
                      ? '${_items.length} result${_items.length == 1 ? '' : 's'}'
                      : '${_items.length} loaded so far',
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: skin.textSecondary,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: r.gridColumns,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2 / 3.35,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => PosterCard(
                    item: _items[index],
                    width: double.infinity,
                    showTitle: true,
                  ),
                  childCount: _items.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    r.gutter, 8, r.gutter, r.bottomSafePadding),
                child: _footer(skin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(dynamic skin) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: SizedBox(
            width: 22,
            height: 22,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: skin.accent),
          ),
        ),
      );
    }
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: TextButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Could not load more \u2014 retry'),
          ),
        ),
      );
    }
    if (_exhausted && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text('No results.',
              style: TextStyle(color: skin.textSecondary, fontSize: 13)),
        ),
      );
    }
    if (_exhausted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'That\u2019s everything for \u201c${widget.query}\u201d',
            style: TextStyle(color: skin.textSecondary, fontSize: 12),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: TextButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          label: const Text('Load more'),
        ),
      ),
    );
  }
}
