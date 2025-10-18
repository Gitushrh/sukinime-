class Anime {
  final String id;
  final String title;
  final String poster;
  final String? synopsis;
  final String? latestEpisode;
  final String? url;

  Anime({
    required this.id,
    required this.title,
    required this.poster,
    this.synopsis,
    this.latestEpisode,
    this.url,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? '',
      poster: json['poster'] ?? json['img'] ?? '',
      synopsis: json['synopsis'],
      latestEpisode: json['latestEpisode'],
      url: json['url'],
    );
  }
}

class AnimeDetail {
  final String title;
  final String poster;
  final String synopsis;
  final List<Episode> episodes;
  final Map<String, String> info;

  AnimeDetail({
    required this.title,
    required this.poster,
    required this.synopsis,
    required this.episodes,
    required this.info,
  });

  factory AnimeDetail.fromJson(Map<String, dynamic> json) {
    final episodes = (json['episodes'] as List?)
        ?.map((e) => Episode.fromJson(e))
        .toList() ?? [];

    return AnimeDetail(
      title: json['title'] ?? '',
      poster: json['poster'] ?? '',
      synopsis: json['synopsis'] ?? '',
      episodes: episodes,
      info: Map<String, String>.from(json['info'] ?? {}),
    );
  }
}

class Episode {
  final String number;
  final String date;
  final String url;

  Episode({
    required this.number,
    required this.date,
    required this.url,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      number: json['number'] ?? '',
      date: json['date'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class StreamLink {
  final String provider;
  final String url;
  final String type;
  final String? quality; // ← ADDED: untuk quality info (360p, 480p, 720p, dll)

  StreamLink({
    required this.provider,
    required this.url,
    required this.type,
    this.quality, // ← ADDED
  });

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    return StreamLink(
      provider: json['provider'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? '',
      quality: json['quality'], // ← ADDED: parse quality dari API
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'url': url,
      'type': type,
      'quality': quality,
    };
  }
}