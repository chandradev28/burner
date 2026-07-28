import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../models/meta.dart';
import '../providers/addon_provider.dart';
import '../providers/skin_provider.dart';
import '../services/addon_client.dart';
import '../widgets/poster_card.dart';

/// Debounced search across every installed addon catalog that supports the
/// `search` extra.
///
/// Each catalog is paged through with `skip` until the addon stops returning
/// new items, so you get the full result set instead of only the first page.
/// Results stream in as pages arrive and are de-duplicated by type+id.
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
  bool _loadingMore = false;
  List<MetaItem> _results = const [];
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
      _loadingMore = query.isNotEmpty;
      if (query.isEmpty) _results = const [];
    });
    if (query.isEmpty) return;

    final addons = context.read<AddonProvider>().addons;

    final seen = <String>{};
    final merged = <MetaItem>[];

    void absorb(List<MetaItem> items) {
      if (!mounted || id != _requestId) return;
      var changed = false;
      for (final item in items) {
        if (seen.add('${item.type}:${item.id}')) {
          merged.add(item);
          changed = true;
        }
      }
      if (!changed) return;
      setState(() {
        _results = List.of(merged);
        _loading = false;
      });
    }

    final futures = <Future<void>>[];
    for (final addon in addons) {
      for (final catalog
          in addon.manifest.catalogs.where((c) => c.supportsSearch)) {
        futures.add(
          AddonClient.searchCatalogAll(
            addon,
            catalog,
            query,
            onPage: absorb,
          ).then<void>((_) {}).catchError((_) {}),
        );
      }
    }

    await Future.wait(futures);
    if (!mounted || id != _requestId) return;

    setState(() {
      _loading = false;
      _loadingMore = false;
      _results = List.of(merged);
    });
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
    if (_results.isEmpty) {
      return _SearchHint(
        icon: Icons.search_off_rounded,
        title: 'No results for \u201c$_query\u201d',
        subtitle: 'Try a different title or install more addons.',
      );
    }

    final r = Responsive.of(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.gutter, 10, r.gutter, 2),
          child: Row(
            children: [
              Text(
                '${_results.length} result${_results.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: skin.textSecondary,
                ),
              ),
              if (_loadingMore) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.6, color: skin.accent),
                ),
                const SizedBox(width: 8),
                Text(
                  'loading more',
                  style: TextStyle(fontSize: 11.5, color: skin.textSecondary),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
                r.gutter, 8, r.gutter, r.bottomSafePadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: r.gridColumns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 2 / 3.35,
            ),
            itemCount: _results.length,
            itemBuilder: (context, index) => PosterCard(
              item: _results[index],
              width: double.infinity,
              showTitle: true,
            ),
          ),
        ),
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
</file>
