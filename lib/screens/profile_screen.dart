import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../providers/addon_provider.dart';
import '../providers/library_provider.dart';
import '../providers/sources_provider.dart';
import '../widgets/common.dart';
import 'content_discovery_screen.dart';

/// Profile & settings: content discovery, data controls, about.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final addonCount = context.watch<AddonProvider>().addons.length;
    final library = context.watch<LibraryProvider>();
    final sources = context.watch<SourcesProvider>();
    final r = Responsive.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: BurnerColors.bg,
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, r.bottomSafePadding),
        children: [
          // Profile header
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: BurnerColors.brand,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('B',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Burner',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    '$addonCount addon${addonCount == 1 ? '' : 's'} \u2022 ${library.watchlist.length} in My List',
                    style: const TextStyle(
                        color: BurnerColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),

          _SectionLabel('Content discovery'),
          _SettingsTile(
            icon: Icons.travel_explore_rounded,
            title: 'Content discovery',
            subtitle:
                'Addons \u2022 CloudStream repos \u2022 Telegram \u2022 combined results',
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

          _SectionLabel('Data'),
          _SettingsTile(
            icon: Icons.playlist_remove_rounded,
            title: 'Clear My List',
            subtitle: 'Remove all saved titles',
            onTap: () => _confirm(
              context,
              title: 'Clear My List?',
              action: () =>
                  context.read<LibraryProvider>().clearWatchlist(),
            ),
          ),
          _SettingsTile(
            icon: Icons.history_toggle_off_rounded,
            title: 'Clear watch history',
            subtitle: 'Remove Continue Watching progress',
            onTap: () => _confirm(
              context,
              title: 'Clear watch history?',
              action: () =>
                  context.read<LibraryProvider>().clearProgress(),
            ),
          ),
          const SizedBox(height: 18),

          _SectionLabel('About'),
          _SettingsTile(
            icon: Icons.local_fire_department_rounded,
            title: 'About Burner',
            subtitle: 'Version 1.0.0',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Burner',
              applicationVersion: '1.0.0',
              applicationIcon: const GradientText(
                BurnerConstants.appName,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2),
              ),
              children: const [
                Text(
                  'A movies & TV app powered by Stremio addons, CloudStream repositories and Telegram. Burner hosts no content \u2014 catalogs, metadata and streams come from the sources you add. Only use sources that serve content you have the right to access.',
                  style: TextStyle(fontSize: 13, height: 1.45),
                ),
              ],
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: BurnerColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: BurnerColors.danger),
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
    final chips = <String>[
      '$addons addon${addons == 1 ? '' : 's'}',
      '$repos CS repo${repos == 1 ? '' : 's'}',
      if (plugins > 0) '$plugins providers',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BurnerColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BurnerColors.stroke),
              ),
              child: Text(
                chip,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: BurnerColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: BurnerColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: BurnerColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: BurnerColors.purple, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: BurnerColors.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: BurnerColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
