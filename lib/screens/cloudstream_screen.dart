import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../models/cloudstream.dart';
import '../providers/skin_provider.dart';
import '../providers/sources_provider.dart';

/// Add, refresh and curate CloudStream repositories and their providers.
/// Colors, radii and switch tints all come from the active skin.
class CloudStreamScreen extends StatefulWidget {
  const CloudStreamScreen({super.key});

  @override
  State<CloudStreamScreen> createState() => _CloudStreamScreenState();
}

class _CloudStreamScreenState extends State<CloudStreamScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add(String url) async {
    if (url.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    await context.read<SourcesProvider>().addRepo(url.trim());
    if (!mounted) return;
    final error = context.read<SourcesProvider>().error;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      context.read<SourcesProvider>().clearError();
    } else {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final r = Responsive.of(context);
    final sources = context.watch<SourcesProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: skin.bg,
        title: const Text('CloudStream repos',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh all',
            onPressed: sources.loading
                ? null
                : () => context.read<SourcesProvider>().refreshAllRepos(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, r.bottomSafePadding),
        children: [
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            onSubmitted: _add,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'repo.json URL or cloudstreamrepo:// link',
              prefixIcon: const Icon(Icons.link_rounded, size: 19),
              suffixIcon: sources.loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _add(_controller.text),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Quick add',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in BurnerConstants.knownCloudStreamRepos.entries)
                ActionChip(
                  label:
                      Text(entry.key, style: const TextStyle(fontSize: 11.5)),
                  backgroundColor: skin.card,
                  side: BorderSide(color: skin.stroke),
                  onPressed: sources.loading ? null : () => _add(entry.value),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (sources.repos.isEmpty)
            const _EmptyRepos()
          else
            for (final repo in sources.repos) _RepoCard(repo: repo),
        ],
      ),
    );
  }
}

class _EmptyRepos extends StatelessWidget {
  const _EmptyRepos();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: skin.surface,
        borderRadius: skin.cardBorderRadius,
        border: Border.all(color: skin.stroke),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 34, color: skin.textSecondary),
          const SizedBox(height: 10),
          const Text('No repositories yet',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Paste any CloudStream repo URL above, or tap a quick-add chip. '
            'Every plugin list in the repo is fetched and all of its providers '
            'are indexed for reference.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, height: 1.45, color: skin.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  final CsRepo repo;

  const _RepoCard({required this.repo});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final active = repo.activePlugins.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: skin.surface,
        borderRadius: skin.cardBorderRadius,
        border: Border.all(color: skin.stroke),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          iconColor: skin.textSecondary,
          collapsedIconColor: skin.textSecondary,
          title: Text(repo.name,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '$active of ${repo.plugins.length} providers on',
              style:
                  TextStyle(fontSize: 11.5, color: skin.textSecondary),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => context
                        .read<SourcesProvider>()
                        .setAllPlugins(repo, true),
                    child: const Text('Enable all',
                        style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => context
                        .read<SourcesProvider>()
                        .setAllPlugins(repo, false),
                    child: const Text('Disable all',
                        style: TextStyle(fontSize: 12)),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Remove repository',
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 19, color: skin.danger),
                    onPressed: () =>
                        context.read<SourcesProvider>().removeRepo(repo),
                  ),
                ],
              ),
            ),
            for (final plugin in repo.plugins)
              SwitchListTile(
                dense: true,
                value: repo.isEnabled(plugin) && !plugin.isDown,
                activeColor: skin.accent,
                onChanged: plugin.isDown
                    ? null
                    : (v) => context
                        .read<SourcesProvider>()
                        .togglePlugin(repo, plugin, v),
                title: Text(plugin.displayName,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  [
                    if (plugin.language != null)
                      plugin.language!.toUpperCase(),
                    if (plugin.tvTypes.isNotEmpty)
                      plugin.tvTypes.take(3).join(', '),
                    if (plugin.isDown) 'down',
                  ].join(' \u2022 '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11, color: skin.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
