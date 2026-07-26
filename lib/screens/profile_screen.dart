import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../providers/addon_provider.dart';
import '../providers/library_provider.dart';
import '../providers/skin_provider.dart';
import '../providers/sources_provider.dart';
import 'appearance_screen.dart';
import 'content_discovery_screen.dart';

/// Profile & settings: appearance, content discovery, data controls, about.
/// Fully skin-aware - colors, radii and the header title follow the active UI.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final addonCount = context.watch<AddonProvider>().addons.length;
    final library = context.watch<LibraryProvider>();
    final sources = context.watch<SourcesProvider>();
    final skin = context.skin;
    final r = Responsive.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(skin.navLabels[3])),
      body: ListView(
        padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, r.bottomSafePadding),
        children: [
          // Header (no wordmark - just the avatar and a content summary).
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: skin.brand,
                  borderRadius: BorderRadius.circular(
                    skin.isNetflix ? 6 : (skin.isAppleTv ? 20 : 32),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: skin.isAppleTv ? -0.4 : 0,
                        color: skin.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$addonCount addon${addonCount == 1 ? '' : 's'} \u2022 ${library.watchlist.length} saved \u2022 ${skin.name} UI',
                      style: TextStyle(
                        color: skin.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          const _SectionLabel('Appearance'),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'App style',
            subtitle: 'Currently ${skin.name} \u2022 tap to switch UI',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppearanceScreen()),
            ),
          ),
          const SizedBox(height: 18),

          const _SectionLabel('Content discovery'),
          _SettingsTile(
            icon: Icons.travel_explore_rounded,
            title: 'Content discovery',
            subtitle:
                'Addons \u2022 in-app providers \u2022 Telegram \u2022 combined results',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContentDiscoveryScreen()),
            ),
          ),
          _DiscoverySummary(
            addons: addonCount,
            repos: sources.repos.length,
            plugins: sources.pluginCount,
            telegram: sources.telegram.enabled && sources.telegram.isConfigured,
          ),
          const SizedBox(height: 18),

          const _SectionLabel('Data'),
          _SettingsTile(
            icon: Icons.playlist_remove_rounded,
            title: 'Clear saved list',
            subtitle: 'Remove all saved titles',
            onTap: () => _confirm(
              context,
              title: 'Clear saved list?',
              action: () => context.read<LibraryProvider>().clearWatchlist(),
            ),
          ),
          _SettingsTile(
            icon: Icons.history_toggle_off_rounded,
            title: 'Clear watch history',
            subtitle: 'Remove Continue Watching progress',
            onTap: () => _confirm(
              context,
              title: 'Clear watch history?',
              action: () => context.read<LibraryProvider>().clearProgress(),
            ),
          ),
          const SizedBox(height: 18),

          const _SectionLabel('About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About this app',
            subtitle: 'Version 1.0.0',
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('About this app'),
                content: Text(
                  'Version 1.0.0\n\nA movies & TV app powered by Stremio addons and '
                  'in-app source providers. No content is hosted here \u2014 catalogs, '
                  'metadata and streams come from the sources you enable. Only use '
                  'sources that serve content you have the right to access.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: skin.textSecondary,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required Future<void> Function() action,
  }) async {
    final skin = context.skinOnce;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          'This cannot be undone.',
          style: TextStyle(color: skin.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: skin.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await action();
  }
}

class _DiscoverySummary extends StatelessWidget {
  final int addons;
  final int repos;
  final int plugins;
  final bool telegram;

  const _DiscoverySummary({
    required this.addons,
    required this.repos,
    required this.plugins,
    required this.telegram,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final chips = <String>[
      '$addons addon${addons == 1 ? '' : 's'}',
      '$repos repo${repos == 1 ? '' : 's'}',
      if (plugins > 0) '$plugins indexed',
      if (telegram) 'Telegram on',
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final chip in chips)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: skin.card,
                borderRadius: BorderRadius.circular(skin.isNetflix ? 4 : 20),
                border: Border.all(color: skin.stroke),
              ),
              child: Text(
                chip,
                style: TextStyle(
                  fontSize: 11.5,
                  color: skin.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        skin.isAppleTv ? text : text.toUpperCase(),
        style: TextStyle(
          fontSize: skin.isAppleTv ? 13 : 11,
          letterSpacing: skin.isAppleTv ? -0.2 : 1.2,
          fontWeight: FontWeight.w700,
          color: skin.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final radius = skin.cardBorderRadius;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: skin.card,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: skin.accent, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          letterSpacing: skin.isAppleTv ? -0.2 : 0,
                          color: skin.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: skin.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: skin.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
