import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/meta.dart';
import '../services/storage_service.dart';

/// A continue-watching entry with saved playback position.
class WatchProgress {
  final MetaItem meta;
  final String? videoId; // "tt123:1:2" for episodes, null for movies
  final String? videoLabel; // e.g. "S1 E2 • Pilot"
  final String? streamUrl; // last played stream, used for quick resume
  final int positionMs;
  final int durationMs;
  final int updatedAt; // epoch ms

  const WatchProgress({
    required this.meta,
    this.videoId,
    this.videoLabel,
    this.streamUrl,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  double get fraction =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);

  bool get isFinished => durationMs > 0 && fraction >= 0.95;

  String get key => progressKey(meta.type, meta.id);

  static String progressKey(String type, String id) => '$type:$id';

  Map<String, dynamic> toJson() => {
        'meta': meta.toJson(),
        'videoId': videoId,
        'videoLabel': videoLabel,
        'streamUrl': streamUrl,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt,
      };

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
        meta: MetaItem.fromJson((json['meta'] as Map).cast<String, dynamic>()),
        videoId: json['videoId'] as String?,
        videoLabel: json['videoLabel'] as String?,
        streamUrl: json['streamUrl'] as String?,
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Watchlist ("My List") + continue watching, persisted locally.
class LibraryProvider extends ChangeNotifier {
  final List<MetaItem> _watchlist = [];
  final Map<String, WatchProgress> _progress = {};
  bool _initialized = false;

  bool get initialized => _initialized;
  List<MetaItem> get watchlist => List.unmodifiable(_watchlist);

  List<WatchProgress> get continueWatching {
    final entries = _progress.values
        .where((p) => p.positionMs > 30 * 1000 && !p.isFinished)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<void> init() async {
    if (_initialized) return;
    final watchlistRaw =
        await StorageService.getStringList(StorageService.watchlistKey);
    _watchlist.clear();
    for (final encoded in watchlistRaw) {
      try {
        _watchlist.add(MetaItem.fromJson(
            (jsonDecode(encoded) as Map).cast<String, dynamic>()));
      } catch (_) {}
    }

    final progressRaw =
        await StorageService.getString(StorageService.progressKey);
    _progress.clear();
    if (progressRaw != null) {
      try {
        final map = (jsonDecode(progressRaw) as Map).cast<String, dynamic>();
        for (final entry in map.entries) {
          _progress[entry.key] = WatchProgress.fromJson(
              (entry.value as Map).cast<String, dynamic>());
        }
      } catch (_) {}
    }

    _initialized = true;
    notifyListeners();
  }

  // ---- Watchlist -----------------------------------------------------------

  bool isInWatchlist(MetaItem item) =>
      _watchlist.any((m) => m.id == item.id && m.type == item.type);

  Future<void> toggleWatchlist(MetaItem item) async {
    if (isInWatchlist(item)) {
      _watchlist.removeWhere((m) => m.id == item.id && m.type == item.type);
    } else {
      _watchlist.insert(0, item);
    }
    await _persistWatchlist();
    notifyListeners();
  }

  Future<void> clearWatchlist() async {
    _watchlist.clear();
    await _persistWatchlist();
    notifyListeners();
  }

  Future<void> _persistWatchlist() async {
    await StorageService.setStringList(
      StorageService.watchlistKey,
      _watchlist.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  // ---- Continue watching ---------------------------------------------------

  WatchProgress? progressFor(String type, String id) =>
      _progress[WatchProgress.progressKey(type, id)];

  Future<void> saveProgress({
    required MetaItem meta,
    String? videoId,
    String? videoLabel,
    String? streamUrl,
    required Duration position,
    required Duration duration,
  }) async {
    final entry = WatchProgress(
      meta: meta,
      videoId: videoId,
      videoLabel: videoLabel,
      streamUrl: streamUrl,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _progress[entry.key] = entry;
    await _persistProgress();
    notifyListeners();
  }

  Future<void> removeProgress(WatchProgress entry) async {
    _progress.remove(entry.key);
    await _persistProgress();
    notifyListeners();
  }

  Future<void> clearProgress() async {
    _progress.clear();
    await _persistProgress();
    notifyListeners();
  }

  Future<void> _persistProgress() async {
    await StorageService.setString(
      StorageService.progressKey,
      jsonEncode(_progress.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
