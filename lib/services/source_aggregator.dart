import '../models/stream_item.dart';
import '../models/telegram.dart';
import 'telegram_client.dart';

/// Builds the extra (non-Stremio) half of the combined stream list and merges
/// every source into one ordered, de-duplicated list.
///
/// CloudStream `.cs3` plugins are compiled Android code, so they can never be
/// executed here \u2014 in-app playback for those sources is handled natively by
/// `WebProviders` instead. Nothing in this class emits plugin file links.
class SourceAggregator {
  SourceAggregator._();

  /// Turns Telegram index hits into playable streams.
  static Future<List<StreamItem>> telegramStreams({
    required TelegramConfig config,
    required List<TelegramItem> index,
    required String query,
  }) async {
    if (!config.enabled || !config.isConfigured) return const [];
    final hits = TelegramClient.search(index, query);
    final streams = <StreamItem>[];
    for (final hit in hits.take(15)) {
      final url = await TelegramClient.resolveFileUrl(
        config.botToken,
        hit.fileId,
      );
      if (url == null) continue;
      final parts = <String>[
        if (hit.chat.isNotEmpty) '@${hit.chat}',
        if (hit.sizeLabel.isNotEmpty) hit.sizeLabel,
      ];
      streams.add(StreamItem(
        name: 'Telegram',
        title: '${hit.caption}\n${parts.join(' \\u2022 ')}',
        url: url,
        sourceKind: 'telegram',
        sourceName: hit.chat.isEmpty ? 'Telegram' : '@${hit.chat}',
      ));
    }
    return streams;
  }

  /// Merges every source into one list: playable first, then by source.
  static List<StreamItem> combine(List<List<StreamItem>> groups) {
    final all = <StreamItem>[];
    final seen = <String>{};
    for (final group in groups) {
      for (final s in group) {
        final key =
            '${s.sourceKind}|${s.url ?? s.externalUrl ?? s.infoHash ?? s.title ?? s.name}';
        if (seen.add(key)) all.add(s);
      }
    }

    int rank(StreamItem s) {
      if (s.isPlayable) return 0;
      if (s.isTorrent) return 1;
      if (s.isYouTube) return 2;
      return 3;
    }

    all.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.sourceLabel.compareTo(b.sourceLabel);
    });
    return all;
  }
}
