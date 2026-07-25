import '../models/cloudstream.dart';
import '../models/meta.dart';
import '../models/stream_item.dart';
import '../models/telegram.dart';
import 'telegram_client.dart';

/// Builds the extra (non-Stremio) half of the combined stream list.
///
/// Stremio addon streams are fetched by [AddonClient]; this class adds
/// CloudStream provider entries and Telegram files, and merges everything
/// into a single, de-duplicated, source-labelled list.
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
        title: '${hit.caption}\n${parts.join(' \u2022 ')}',
        url: url,
        sourceKind: 'telegram',
        sourceName: hit.chat.isEmpty ? 'Telegram' : '@${hit.chat}',
      ));
    }
    return streams;
  }

  /// Surfaces enabled CloudStream providers for a title.
  ///
  /// CloudStream providers ship as Android `.cs3` plugins, so their scrapers
  /// cannot be executed inside Flutter. Burner indexes every repo you add and
  /// exposes each enabled provider as an external "open in provider" source,
  /// which keeps the picker unified while staying honest about playback.
  static List<StreamItem> cloudStreamStreams({
    required List<CsRepo> repos,
    required MetaItem meta,
  }) {
    final isSeries = meta.type.toLowerCase() != 'movie';
    final streams = <StreamItem>[];

    for (final repo in repos) {
      for (final plugin in repo.activePlugins) {
        final supports =
            isSeries ? plugin.supportsSeries : plugin.supportsMovies;
        if (!supports) continue;
        final lang = plugin.language?.toUpperCase();
        streams.add(StreamItem(
          name: plugin.displayName,
          title: [
            repo.name,
            if (lang != null && lang.isNotEmpty) lang,
            if (plugin.status == 2) 'slow',
            if (plugin.status == 3) 'beta',
          ].join(' \u2022 '),
          externalUrl: plugin.url,
          sourceKind: 'cloudstream',
          sourceName: plugin.displayName,
        ));
      }
    }
    streams.sort((a, b) =>
        (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
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
