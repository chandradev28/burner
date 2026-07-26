import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../providers/addon_provider.dart';
import '../providers/skin_provider.dart';
import '../providers/sources_provider.dart';
import '../providers/telegram_account_provider.dart';
import 'addons_screen.dart';
import 'cloudstream_screen.dart';
import 'telegram_screen.dart';

/// Single hub for every place the app can pull content from:
/// Stremio addons, in-app providers / CloudStream repos, and Telegram.
class ContentDiscoveryScreen extends StatelessWidget {
  const ContentDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final r = Responsive.of(context);
    final addons = context.watch<AddonProvider>();
    final sources = context.watch<SourcesProvider>();
    final account = context.watch<TelegramAccountProvider>();
    final telegramOn = account.isActiveSource;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: skin.bg,
        title: const Text('Content discovery',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, r.bottomSafePadding),
        children: [
          const _Intro(),
          const SizedBox(height: 18),
          _SourceCard(
            icon: Icons.extension_rounded,
            title: 'Stremio addons',
            subtitle:
                '${addons.addons.length} installed \u2022 catalogs, metadata and streams',
            enabled: sources.addonsEnabled,
            onToggle: (v) =>
                context.read<SourcesProvider>().setAddonsEnabled(v),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddonsScreen()),
            ),
          ),
          _SourceCard(
            icon: Icons.cloud_sync_rounded,
            title: 'In-app providers & CloudStream repos',
            subtitle: sources.repos.isEmpty
                ? 'Built-in scrapers \u2022 add any CloudStream repo for reference'
                : '${sources.repos.length} repo${sources.repos.length == 1 ? '' : 's'} \u2022 ${sources.pluginCount} providers indexed',
            enabled: sources.cloudStreamEnabled,
            onToggle: (v) =>
                context.read<SourcesProvider>().setCloudStreamEnabled(v),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CloudStreamScreen()),
            ),
          ),
          _SourceCard(
            icon: Icons.send_rounded,
            title: 'Telegram',
            subtitle: account.isLoggedIn
                ? '${account.statusLabel} \u2022 ${account.selectedChats.length} pinned chat${account.selectedChats.length == 1 ? '' : 's'}'
                : 'Log in with your phone number and stream from your own Telegram',
            enabled: telegramOn,
            onToggle: (v) {
              final provider = context.read<TelegramAccountProvider>();
              if (!provider.isLoggedIn) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TelegramScreen()),
                );
                return;
              }
              provider.setEnabled(v);
            },
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TelegramScreen()),
            ),
          ),
          const SizedBox(height: 20),
          const _CombineNote(),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            skin.accent.withOpacity(0.22),
            skin.accentAlt.withOpacity(0.12),
          ],
        ),
        borderRadius: skin.cardBorderRadius,
        border: Border.all(color: skin.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose where to watch',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Turn sources on or off here. When you open a title, every enabled '
            'source is queried at once and the results are merged into one '
            'stream list, grouped by where each link came from.',
            style: TextStyle(
                fontSize: 12.5, height: 1.45, color: skin.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CombineNote extends StatelessWidget {
  const _CombineNote();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: skin.cardBorderRadius,
        border: Border.all(color: skin.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: skin.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'CloudStream providers ship as Android .cs3 plugins, so their own '
              'scraper code cannot run here. Repos you add are indexed for '
              'reference, while the built-in providers, addons and your '
              'Telegram account resolve to real video URLs and play in the app.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.45, color: skin.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: skin.surface,
        borderRadius: skin.cardBorderRadius,
        border: Border.all(
          color: enabled ? skin.accent.withOpacity(0.35) : skin.stroke,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: skin.cardBorderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: enabled ? skin.brand : null,
                    color: enabled ? null : skin.card,
                    borderRadius: BorderRadius.circular(skin.posterRadius),
                  ),
                  child: Icon(icon,
                      size: 20,
                      color: enabled ? Colors.white : skin.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: skin.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeColor: skin.accent,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
