import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../providers/addon_provider.dart';
import '../providers/sources_provider.dart';
import 'addons_screen.dart';
import 'cloudstream_screen.dart';
import 'telegram_screen.dart';

/// Single hub for every place Burner can pull content from:
/// Stremio addons, CloudStream repositories and Telegram.
class ContentDiscoveryScreen extends StatelessWidget {
  const ContentDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final addons = context.watch<AddonProvider>();
    final sources = context.watch<SourcesProvider>();
    final telegramOn =
        sources.telegram.enabled && sources.telegram.isConfigured;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: BurnerColors.bg,
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
            onToggle: (v) => context.read<SourcesProvider>().setAddonsEnabled(v),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddonsScreen()),
            ),
          ),
          _SourceCard(
            icon: Icons.cloud_sync_rounded,
            title: 'CloudStream repositories',
            subtitle: sources.repos.isEmpty
                ? 'Add any CloudStream repo \u2022 official repos included'
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
            subtitle: telegramOn
                ? 'Connected as @${sources.telegram.botUsername ?? 'bot'} \u2022 ${sources.telegramIndex.length} files indexed'
                : 'Play video files from your channels via a bot',
            enabled: telegramOn,
            onToggle: (v) async {
              final provider = context.read<SourcesProvider>();
              if (!provider.telegram.isConfigured) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TelegramScreen()),
                );
                return;
              }
              await provider
                  .saveTelegram(provider.telegram.copyWith(enabled: v));
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BurnerColors.purple.withOpacity(0.22),
            BurnerColors.blue.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BurnerColors.stroke),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose where to watch',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text(
            'Turn sources on or off here. When you open a title, Burner queries '
            'every enabled source at once and merges the results into one '
            'stream list, grouped by where each link came from.',
            style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: BurnerColors.textSecondary),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BurnerColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BurnerColors.stroke),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: BurnerColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'CloudStream providers ship as Android .cs3 plugins. Burner reads '
              'every repo you add and indexes its providers, but a plugin\'s own '
              'scraper code runs only inside CloudStream \u2014 those entries open '
              'externally. Addon and Telegram links play natively in Burner.',
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: BurnerColors.textSecondary),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: BurnerColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled
              ? BurnerColors.purple.withOpacity(0.35)
              : BurnerColors.stroke,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: enabled ? BurnerColors.brand : null,
                    color: enabled ? null : BurnerColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      size: 20,
                      color: enabled
                          ? Colors.white
                          : BurnerColors.textSecondary),
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
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: BurnerColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeColor: BurnerColors.purple,
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
