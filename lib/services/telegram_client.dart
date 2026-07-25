import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/telegram.dart';

/// Telegram Bot API client used as a content source.
///
/// The bot must be an administrator of any channel you want to index, and
/// the Bot API only exposes messages the bot has received, so the index is
/// built from `getUpdates` and cached locally.
class TelegramClient {
  TelegramClient._();

  static const Duration _timeout = Duration(seconds: 20);

  static String _base(String token) =>
      '${BurnerConstants.telegramApi}/bot$token';

  /// Validates a bot token, returning the bot username.
  static Future<String> validateToken(String token) async {
    final res =
        await http.get(Uri.parse('${_base(token)}/getMe')).timeout(_timeout);
    final json = jsonDecode(res.body);
    if (json is! Map || json['ok'] != true) {
      throw Exception('Invalid bot token');
    }
    final result = (json['result'] as Map).cast<String, dynamic>();
    return (result['username'] ?? 'bot').toString();
  }

  /// Builds/refreshes the media index from everything the bot can see.
  static Future<List<TelegramItem>> indexUpdates(TelegramConfig config) async {
    if (!config.isConfigured) return const [];
    final res = await http
        .get(Uri.parse('${_base(config.botToken)}/getUpdates?limit=100'))
        .timeout(_timeout);
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (json is! Map || json['ok'] != true) return const [];

    final updates = (json['result'] as List?) ?? const [];
    final items = <TelegramItem>[];

    for (final raw in updates) {
      if (raw is! Map) continue;
      final update = raw.cast<String, dynamic>();
      final message = (update['channel_post'] ??
              update['message'] ??
              update['edited_channel_post']) as Map?;
      if (message == null) continue;
      final msg = message.cast<String, dynamic>();

      final chat = (msg['chat'] as Map?)?.cast<String, dynamic>();
      final chatName =
          (chat?['username'] ?? chat?['title'] ?? chat?['id'] ?? '').toString();

      // Only channels the user configured (empty = accept everything).
      if (config.channels.isNotEmpty) {
        final match = config.channels.any((c) =>
            chatName.toLowerCase() ==
            c.replaceAll('@', '').trim().toLowerCase());
        if (!match) continue;
      }

      final video = (msg['video'] as Map?)?.cast<String, dynamic>();
      final document = (msg['document'] as Map?)?.cast<String, dynamic>();
      final media = video ?? document;
      if (media == null) continue;

      final mime = media['mime_type']?.toString() ?? '';
      if (document != null && !mime.startsWith('video/')) continue;

      items.add(TelegramItem(
        fileId: (media['file_id'] ?? '').toString(),
        caption: (msg['caption'] ??
                media['file_name'] ??
                msg['text'] ??
                'Telegram video')
            .toString(),
        chat: chatName,
        sizeBytes:
            media['file_size'] is int ? media['file_size'] as int : null,
        durationSec:
            media['duration'] is int ? media['duration'] as int : null,
        mimeType: mime.isEmpty ? null : mime,
      ));
    }
    return items;
  }

  /// Resolves a file_id into a direct, playable HTTPS URL.
  ///
  /// Note: the Bot API caps downloads at 20 MB per file. Larger files return
  /// an error and are surfaced to the user as not playable.
  static Future<String?> resolveFileUrl(String token, String fileId) async {
    try {
      final res = await http
          .get(Uri.parse('${_base(token)}/getFile?file_id=$fileId'))
          .timeout(_timeout);
      final json = jsonDecode(res.body);
      if (json is! Map || json['ok'] != true) return null;
      final path =
          ((json['result'] as Map).cast<String, dynamic>()['file_path'] ?? '')
              .toString();
      if (path.isEmpty) return null;
      return '${BurnerConstants.telegramApi}/file/bot$token/$path';
    } catch (_) {
      return null;
    }
  }

  /// Fuzzy title match against the cached index.
  static List<TelegramItem> search(List<TelegramItem> index, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
    return index.where((item) {
      final caption = item.caption.toLowerCase();
      if (caption.contains(q)) return true;
      if (tokens.isEmpty) return false;
      final hits = tokens.where(caption.contains).length;
      return hits >= (tokens.length / 2).ceil();
    }).toList();
  }
}
