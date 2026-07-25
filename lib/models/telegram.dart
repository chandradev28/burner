import 'dart:convert';

/// Telegram Bot API configuration for the Telegram content source.
class TelegramConfig {
  final String botToken;
  final List<String> channels; // @usernames or numeric chat ids
  final String? botUsername;
  final bool enabled;

  const TelegramConfig({
    this.botToken = '',
    this.channels = const [],
    this.botUsername,
    this.enabled = false,
  });

  bool get isConfigured => botToken.trim().isNotEmpty;

  TelegramConfig copyWith({
    String? botToken,
    List<String>? channels,
    String? botUsername,
    bool? enabled,
  }) {
    return TelegramConfig(
      botToken: botToken ?? this.botToken,
      channels: channels ?? this.channels,
      botUsername: botUsername ?? this.botUsername,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'botToken': botToken,
        'channels': channels,
        'botUsername': botUsername,
        'enabled': enabled,
      };

  factory TelegramConfig.fromJson(Map<String, dynamic> json) => TelegramConfig(
        botToken: (json['botToken'] ?? '').toString(),
        channels: json['channels'] is List
            ? (json['channels'] as List).map((e) => e.toString()).toList()
            : const [],
        botUsername: json['botUsername']?.toString(),
        enabled: json['enabled'] == true,
      );

  String encode() => jsonEncode(toJson());

  static TelegramConfig decode(String raw) =>
      TelegramConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// A video/document message discovered in a Telegram channel.
class TelegramItem {
  final String fileId;
  final String caption;
  final String chat;
  final int? sizeBytes;
  final int? durationSec;
  final String? mimeType;

  const TelegramItem({
    required this.fileId,
    required this.caption,
    required this.chat,
    this.sizeBytes,
    this.durationSec,
    this.mimeType,
  });

  String get sizeLabel {
    final b = sizeBytes;
    if (b == null || b <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = b.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
  }

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'caption': caption,
        'chat': chat,
        'sizeBytes': sizeBytes,
        'durationSec': durationSec,
        'mimeType': mimeType,
      };

  factory TelegramItem.fromJson(Map<String, dynamic> json) => TelegramItem(
        fileId: (json['fileId'] ?? '').toString(),
        caption: (json['caption'] ?? '').toString(),
        chat: (json['chat'] ?? '').toString(),
        sizeBytes: json['sizeBytes'] is int ? json['sizeBytes'] as int : null,
        durationSec:
            json['durationSec'] is int ? json['durationSec'] as int : null,
        mimeType: json['mimeType']?.toString(),
      );
}
