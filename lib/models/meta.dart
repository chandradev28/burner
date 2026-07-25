/// A movie / series item returned by addon catalogs and meta endpoints.
class MetaItem {
  final String id;
  final String type; // movie | series | channel | tv ...
  final String name;
  final String? poster;
  final String? background;
  final String? logo;
  final String? description;
  final String? releaseInfo; // e.g. "2019" or "2016-2022"
  final String? imdbRating;
  final String? runtime;
  final List<String> genres;
  final List<String> cast;
  final List<String> director;
  final List<Video> videos; // episodes, only present on full meta

  const MetaItem({
    required this.id,
    required this.type,
    required this.name,
    this.poster,
    this.background,
    this.logo,
    this.description,
    this.releaseInfo,
    this.imdbRating,
    this.runtime,
    this.genres = const [],
    this.cast = const [],
    this.director = const [],
    this.videos = const [],
  });

  bool get isSeries => type == 'series';

  String get year {
    final info = releaseInfo ?? '';
    return info.split(RegExp(r'[-\u2013]')).first.trim();
  }

  factory MetaItem.fromJson(Map<String, dynamic> json) {
    final videos = <Video>[];
    if (json['videos'] is List) {
      for (final v in (json['videos'] as List)) {
        if (v is Map<String, dynamic>) videos.add(Video.fromJson(v));
      }
    }
    return MetaItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'movie').toString(),
      name: (json['name'] ?? '').toString(),
      poster: json['poster']?.toString(),
      background: json['background']?.toString(),
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      releaseInfo: (json['releaseInfo'] ?? json['year'])?.toString(),
      imdbRating: json['imdbRating']?.toString(),
      runtime: json['runtime']?.toString(),
      genres: _stringList(json['genres'] ?? json['genre']),
      cast: _stringList(json['cast']),
      director: _stringList(json['director']),
      videos: videos,
    );
  }

  /// Compact JSON used to persist watchlist / continue-watching entries.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'poster': poster,
        'background': background,
        'logo': logo,
        'description': description,
        'releaseInfo': releaseInfo,
        'imdbRating': imdbRating,
        'runtime': runtime,
        'genres': genres,
      };

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }
}

/// A video entry inside a series meta (an episode) — or a standalone video.
class Video {
  final String id; // usually "tt1234567:1:2"
  final String name;
  final int? season;
  final int? episode;
  final String? thumbnail;
  final String? overview;
  final String? released; // ISO date string

  const Video({
    required this.id,
    required this.name,
    this.season,
    this.episode,
    this.thumbnail,
    this.overview,
    this.released,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '');
    return Video(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? 'Episode').toString(),
      season: asInt(json['season'] ?? json['imdbSeason']),
      episode: asInt(json['episode'] ?? json['number'] ?? json['imdbEpisode']),
      thumbnail: json['thumbnail']?.toString(),
      overview: (json['overview'] ?? json['description'])?.toString(),
      released: json['released']?.toString(),
    );
  }

  bool get isReleased {
    if (released == null) return true;
    final date = DateTime.tryParse(released!);
    if (date == null) return true;
    return date.isBefore(DateTime.now());
  }

  String get code =>
      (season != null && episode != null) ? 'S$season E$episode' : '';
}
