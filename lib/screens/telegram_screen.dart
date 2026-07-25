import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/telegram.dart';
import '../providers/sources_provider.dart';
import '../widgets/common.dart';

/// Connect a Telegram bot so channel video files show up as playable
/// sources next to addon and CloudStream results.
class TelegramScreen extends StatefulWidget {
  const TelegramScreen({super.key});

  @override
  State<TelegramScreen> createState() => _TelegramScreenState();
}

class _TelegramScreenState extends State<TelegramScreen> {
  late final TextEditingController _token;
  late final TextEditingController _channels;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final config = context.read<SourcesProvider>().telegram;
    _token = TextEditingController(text: config.botToken);
    _channels = TextEditingController(text: config.channels.join(', '));
    _enabled = config.enabled;
  }

  @override
  void dispose() {
    _token.dispose();
    _channels.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final config = TelegramConfig(
      botToken: _token.text.trim(),
      channels: _channels.text
          .split(RegExp(r'[,\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      enabled: _enabled,
    );
    final ok = await context.read<SourcesProvider>().saveTelegram(config);
    if (!mounted) return;
    final provider = context.read<SourcesProvider>();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Telegram connected as @${provider.telegram.botUsername ?? 'bot'}'
          : provider.error ?? 'Could not connect'),
    ));
    provider.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final sources = context.watch<SourcesProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: BurnerColors.bg,
        title: const Text('Telegram',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(r.gutter, 12, r.gutter, r.bottomSafePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BurnerColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BurnerColors.stroke),
            ),
            child: const Text(
              'Create a bot with @BotFather, add it as an administrator of the '
              'channels you want to watch, then paste its token below. Burner '
              'indexes video files the bot can see and plays them inline.\n\n'
              'Telegram\'s Bot API caps file downloads at 20 MB, so larger '
              'files are listed but open in Telegram instead.',
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: BurnerColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _token,
            obscureText: true,
            style: const TextStyle(fontSize: 13.5),
            decoration: const InputDecoration(
              labelText: 'Bot token',
              hintText: '123456789:AA...',
              prefixIcon: Icon(Icons.key_rounded, size: 19),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _channels,
            style: const TextStyle(fontSize: 13.5),
            decoration: const InputDecoration(
              labelText: 'Channels (optional)',
              hintText: '@movies_channel, @series_hub',
              prefixIcon: Icon(Icons.tag_rounded, size: 19),
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            activeColor: BurnerColors.purple,
            title: const Text('Use Telegram as a source',
                style: TextStyle(fontSize: 13.5)),
            subtitle: const Text('Include Telegram files in combined results',
                style: TextStyle(
                    fontSize: 11.5, color: BurnerColors.textSecondary)),
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 8),
          GradientButton(
            label: sources.loading ? 'Connecting\u2026' : 'Save & connect',
            icon: Icons.check_rounded,
            expanded: true,
            onPressed: sources.loading ? null : _save,
          ),
          const SizedBox(height: 12),
          if (sources.telegram.isConfigured) ...[
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Refresh index (${sources.telegramIndex.length})',
                    icon: Icons.sync_rounded,
                    onPressed: () => context
                        .read<SourcesProvider>()
                        .refreshTelegramIndex(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: 'Disconnect',
                    icon: Icons.link_off_rounded,
                    onPressed: () async {
                      await context.read<SourcesProvider>().clearTelegram();
                      if (!mounted) return;
                      _token.clear();
                      _channels.clear();
                      setState(() => _enabled = false);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sources.telegramIndex.isNotEmpty) ...[
              const Text('Indexed files',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final item in sources.telegramIndex.take(30))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.movie_outlined,
                      size: 19, color: BurnerColors.textSecondary),
                  title: Text(item.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5)),
                  subtitle: Text(
                    [
                      if (item.chat.isNotEmpty) '@${item.chat}',
                      if (item.sizeLabel.isNotEmpty) item.sizeLabel,
                    ].join(' \u2022 '),
                    style: const TextStyle(
                        fontSize: 11, color: BurnerColors.textSecondary),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
