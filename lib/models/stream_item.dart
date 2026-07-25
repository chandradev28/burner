/// A playable (or resolvable) stream returned by an addon.
class StreamItem {
  final String? name; // usually addon/quality short label
  final String? title; // longer description (file name, size, seeds...)
  final String? description;
  final String? url; // direct http(s) video URL -> playable in-app
  final String? externalUrl; // open in browser / external app
  final String? ytId; // YouTube id
  final String? infoHash; // torrent hash (needs debrid/resolver addon)
  final int? fileIdx;
  final Map<String, dynamic> behaviorHints;

  /// Filled in after fetching, so the UI can group streams by addon.
  final String addonName;

  /// Which content source produced this stream: 'stremio', 'cloudstream'
  /// or 'telegram'. Used to group and label combined results.
  final String sourceKind;

  /// Human readable source name (addon name, CS provider, channel...).
  final String sourceName;

  const StreamItem({
    this.name,
    this.title,
    this.description,
    this.url,
    this.externalUrl,
    this.ytId,
    this.infoHash,
    this.fileIdx,
    this.behaviorHints = const {},
    this.addonName = '',
    this.sourceKind = 'stremio',
    this.sourceName = '',
  });

  factory StreamItem.fromJson(Map<String, dynamic> json,
      {String addonName = '',
      String sourceKind = 'stremio',
      String sourceName = ''}) {
    return StreamItem(
      name: json['name']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      url: json['url']?.toString(),
      externalUrl: json['externalUrl']?.toString(),
      ytId: json['ytId']?.toString(),
      infoHash: json['infoHash']?.toString(),
      fileIdx: json['fileIdx'] is int
          ? json['fileIdx'] as int
          : int.tryParse(json['fileIdx']?.toString() ?? ''),
      behaviorHints: json['behaviorHints'] is Map
          ? (json['behaviorHints'] as Map).cast<String, dynamic>()
          : const {},
      addonName: addonName,
      sourceKind: sourceKind,
      sourceName: sourceName.isNotEmpty ? sourceName : addonName,
    );
  }

  /// Directly playable inside the app's video player.
  bool get isPlayable => url != null && url!.isNotEmpty;

  bool get isExternal =>
      !isPlayable && externalUrl != null && externalUrl!.isNotEmpty;

  bool get isTorrent =>
      !isPlayable && !isExternal && infoHash != null && infoHash!.isNotEmpty;

  bool get isYouTube => !isPlayable && ytId != null && ytId!.isNotEmpty;

  String get primaryLabel {
    final t = title ?? description;
    if (t != null && t.trim().isNotEmpty) return t.trim();
    return name?.trim() ?? 'Stream';
  }

  String get badge => (name ?? sourceName).trim();

  /// Short label for the source group header in the stream picker.
  String get sourceLabel {
    switch (sourceKind) {
      case 'cloudstream':
        return 'CloudStream';
      case 'telegram':
        return 'Telegram';
      default:
        return 'Addons';
    }
  }
}
