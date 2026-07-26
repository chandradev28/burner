import 'td_client.dart';

/// A chat in the logged-in account.
class TgChat {
  final int id;
  final String title;
  final String type;
  final bool isSaved;

  const TgChat({
    required this.id,
    required this.title,
    this.type = '',
    this.isSaved = false,
  });

  String get typeLabel {
    if (isSaved) return 'Saved Messages';
    switch (type) {
      case 'chatTypeSupergroup':
        return 'Channel / group';
      case 'chatTypeBasicGroup':
        return 'Group';
      case 'chatTypePrivate':
        return 'Private chat';
      default:
        return 'Chat';
    }
  }
}

/// A playable video found in the account.
class TgMedia {
  final int chatId;
  final int messageId;
  final int fileId;
  final String caption;
  final String chatTitle;
  final int size;
  final int durationSec;
  final String mimeType;
  final bool supportsStreaming;

  const TgMedia({
    required this.chatId,
    required this.messageId,
    required this.fileId,
    required this.caption,
    required this.chatTitle,
    this.size = 0,
    this.durationSec = 0,
    this.mimeType = 'video/mp4',
    this.supportsStreaming = true,
  });

  String get sizeLabel {
    if (size <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = size.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
  }

  String get durationLabel {
    if (durationSec <= 0) return '';
    final h = durationSec ~/ 3600;
    final m = (durationSec % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  /// Rough quality guess from the caption / file name, used as a stream badge.
  String? get qualityLabel {
    final text = caption.toLowerCase();
    for (final q in ['2160p', '4k', '1440p', '1080p', '720p', '480p']) {
      if (text.contains(q)) return q == '4k' ? '2160p' : q;
    }
    return null;
  }
}

/// Reads chats and video messages out of the logged-in Telegram account.
class TdMedia {
  TdMedia._();

  static const Map<String, dynamic> _videoFilter = {
    '@type': 'searchMessagesFilterVideo',
  };

  /// Loads the account's main chat list.
  static Future<List<TgChat>> loadChats({int limit = 150}) async {
    final client = TdClient.instance;

    // Ask TDLib to populate the chat list, then read the ids back.
    try {
      await client.request({
        '@type': 'loadChats',
        'chat_list': {'@type': 'chatListMain'},
        'limit': limit,
      });
    } catch (_) {
      // "Chat list is fully loaded" comes back as an error -- harmless.
    }

    final response = await client.request({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': limit,
    });

    final ids = (response['chat_ids'] as List?) ?? const [];
    int? myId;
    try {
      final me = await client.request({'@type': 'getMe'});
      myId = me['id'] is int ? me['id'] as int : null;
    } catch (_) {}

    final chats = <TgChat>[];
    for (final rawId in ids) {
      if (rawId is! int) continue;
      try {
        final chat =
            await client.request({'@type': 'getChat', 'chat_id': rawId});
        final type = chat['type'];
        chats.add(TgChat(
          id: rawId,
          title: (chat['title'] ?? 'Chat').toString(),
          type: type is Map ? (type['@type'] ?? '').toString() : '',
          isSaved: myId != null && rawId == myId,
        ));
      } catch (_) {}
    }

    // Saved Messages first, then alphabetical.
    chats.sort((a, b) {
      if (a.isSaved != b.isSaved) return a.isSaved ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return chats;
  }

  /// Global video search across every chat in the account.
  static Future<List<TgMedia>> searchAllChats(String query,
      {int limit = 40}) async {
    if (query.trim().isEmpty) return const [];
    final response = await TdClient.instance.request({
      '@type': 'searchMessages',
      'chat_list': {'@type': 'chatListMain'},
      'query': query,
      'offset': '',
      'limit': limit,
      'filter': _videoFilter,
    });
    return _parseMessages(response);
  }

  /// Video search inside one chat.
  static Future<List<TgMedia>> searchChat(
    int chatId,
    String query, {
    int limit = 30,
  }) async {
    final response = await TdClient.instance.request({
      '@type': 'searchChatMessages',
      'chat_id': chatId,
      'query': query,
      'from_message_id': 0,
      'offset': 0,
      'limit': limit,
      'filter': _videoFilter,
    });
    return _parseMessages(response);
  }

  /// Most recent videos in a chat (used to build the browsable index).
  static Future<List<TgMedia>> recentVideos(int chatId, {int limit = 40}) =>
      searchChat(chatId, '', limit: limit);

  static Future<List<TgMedia>> _parseMessages(
      Map<String, dynamic> response) async {
    final messages = (response['messages'] as List?) ?? const [];
    final out = <TgMedia>[];
    final titles = <int, String>{};

    for (final raw in messages) {
      if (raw is! Map) continue;
      final message = raw.cast<String, dynamic>();
      final media = _fromContent(message);
      if (media == null) continue;

      final chatId = media.chatId;
      if (!titles.containsKey(chatId)) {
        try {
          final chat = await TdClient.instance
              .request({'@type': 'getChat', 'chat_id': chatId});
          titles[chatId] = (chat['title'] ?? '').toString();
        } catch (_) {
          titles[chatId] = '';
        }
      }

      out.add(TgMedia(
        chatId: chatId,
        messageId: media.messageId,
        fileId: media.fileId,
        caption: media.caption,
        chatTitle: titles[chatId] ?? '',
        size: media.size,
        durationSec: media.durationSec,
        mimeType: media.mimeType,
        supportsStreaming: media.supportsStreaming,
      ));
    }
    return out;
  }

  /// Extracts the video/document payload of a message, if any.
  static TgMedia? _fromContent(Map<String, dynamic> message) {
    final content = message['content'];
    if (content is! Map) return null;
    final type = (content['@type'] ?? '').toString();

    Map<String, dynamic>? media;
    if (type == 'messageVideo' && content['video'] is Map) {
      media = (content['video'] as Map).cast<String, dynamic>();
    } else if (type == 'messageDocument' && content['document'] is Map) {
      media = (content['document'] as Map).cast<String, dynamic>();
      final mime = (media['mime_type'] ?? '').toString();
      if (!mime.startsWith('video/')) return null;
    } else if (type == 'messageAnimation' && content['animation'] is Map) {
      media = (content['animation'] as Map).cast<String, dynamic>();
    }
    if (media == null) return null;

    final file = media['video'] ?? media['document'] ?? media['animation'];
    if (file is! Map) return null;
    final fileId = file['id'];
    if (fileId is! int) return null;

    final expected = file['expected_size'];
    final size = file['size'] is int && (file['size'] as int) > 0
        ? file['size'] as int
        : (expected is int ? expected : 0);

    final captionText = content['caption'] is Map
        ? ((content['caption'] as Map)['text'] ?? '').toString()
        : '';
    final fileName = (media['file_name'] ?? '').toString();
    final caption = captionText.trim().isNotEmpty
        ? captionText.trim().split('\n').first
        : (fileName.isNotEmpty ? fileName : 'Telegram video');

    return TgMedia(
      chatId: message['chat_id'] is int ? message['chat_id'] as int : 0,
      messageId: message['id'] is int ? message['id'] as int : 0,
      fileId: fileId,
      caption: caption,
      chatTitle: '',
      size: size,
      durationSec: media['duration'] is int ? media['duration'] as int : 0,
      mimeType: (media['mime_type'] ?? 'video/mp4').toString(),
      supportsStreaming: media['supports_streaming'] != false,
    );
  }

  /// Fuzzy local match, used when filtering a cached index.
  static List<TgMedia> filter(List<TgMedia> index, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return index;
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
    return index.where((item) {
      final text = '${item.caption} ${item.chatTitle}'.toLowerCase();
      if (text.contains(q)) return true;
      if (tokens.isEmpty) return false;
      final hits = tokens.where(text.contains).length;
      return hits >= (tokens.length / 2).ceil();
    }).toList();
  }
}
