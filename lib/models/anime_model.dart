// models/anime_model.dart - FIXED: Genre parsing that was causing crashes
import 'package:flutter/foundation.dart';

class StreamLink {
  final String provider;
  final String url;
  final String type;
  final String? quality;
  final String? source;
  final String? serverId;
  final String? format;
  final String? note;

  StreamLink({
    required this.provider,
    required this.url,
    required this.type,
    this.quality,
    this.source,
    this.serverId,
    this.format,
    this.note,
  });

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    return StreamLink(
      provider: json['provider'] ?? json['server'] ?? json['name'] ?? 'Unknown',
      url: json['url'] ?? json['link'] ?? '',
      type: json['type'] ?? json['format'] ?? 'iframe',
      quality: json['quality'] ?? json['resolution'],
      source: json['source'],
      serverId: json['serverId'] ?? json['id'] ?? json['post'],
      format: json['format'],
      note: json['note'],
    );
  }

  bool get isIframe => type.toLowerCase() == 'iframe' || type.toLowerCase() == 'embed';
  bool get isDirect => type == 'mp4' || type == 'hls';
  bool get isDownload => type.toLowerCase() == 'download';
  String get displayQuality => quality ?? 'Auto';
  
  String get displayType {
    switch (type.toLowerCase()) {
      case 'iframe':
      case 'embed':
        return 'Stream';
      case 'mp4':
        return 'MP4';
      case 'hls':
        return 'HLS';
      case 'download':
        return 'Download';
      default:
        return type.toUpperCase();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'url': url,
      'type': type,
      'quality': quality,
      'source': source,
      'serverId': serverId,
      'format': format,
      'note': note,
    };
  }
}

// ✅ FIXED: Safe genre parsing that handles all API response formats
List<String>? _parseGenreList(dynamic genreList) {
  if (genreList == null) return null;
  
  try {
    // Case 1: Already a List
    if (genreList is List) {
      final result = <String>[];
      
      // ✅ FIX: Use standard for loop instead of iterator to avoid index errors
      for (var i = 0; i < genreList.length; i++) {
        try {
          final item = genreList[i];
          
          if (item is Map) {
            final title = item['title']?.toString() ?? 
                         item['name']?.toString() ?? 
                         item['genreId']?.toString() ?? '';
            if (title.isNotEmpty) {
              result.add(title);
            }
          } else if (item is String && item.isNotEmpty) {
            result.add(item);
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Skipping genre at index $i: $e');
          continue;
        }
      }
      
      return result.isEmpty ? null : result;
    }
    
    // Case 2: Single Map object
    if (genreList is Map) {
      final title = genreList['title']?.toString() ?? 
                   genreList['name']?.toString() ?? 
                   genreList['genreId']?.toString() ?? '';
      if (title.isNotEmpty) {
        return [title];
      }
    }
    
    // Case 3: Single String
    if (genreList is String && genreList.isNotEmpty) {
      return [genreList];
    }
    
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Error parsing genreList: $e');
      print('   genreList type: ${genreList.runtimeType}');
    }
  }
  
  return null;
}

class Anime {
  final String id;
  final String title;
  final String poster;
  final String? synopsis;
  final String? latestEpisode;
  final String? url;
  final String? episode;
  final int? totalEpisodes;
  final String? status;
  final String? rating;
  final String? type;
  final String? score;
  final List<String>? genres;

  Anime({
    required this.id,
    required this.title,
    required this.poster,
    this.synopsis,
    this.latestEpisode,
    this.url,
    this.episode,
    this.totalEpisodes,
    this.status,
    this.rating,
    this.type,
    this.score,
    this.genres,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    try {
      if (kDebugMode) print('🔍 Parsing Anime: ${json['title']}');
      
      // ✅ STEP 1: Extract animeId
      String animeId = '';
      
      if (json['slug'] != null && json['slug'].toString().isNotEmpty) {
        animeId = json['slug'].toString();
      } else if (json['animeId'] != null && json['animeId'].toString().isNotEmpty) {
        animeId = json['animeId'].toString();
      } else if (json['id'] != null && json['id'].toString().isNotEmpty) {
        animeId = json['id'].toString();
      } else if (json['href'] != null) {
        animeId = json['href'].toString().replaceAll('/anime/', '').split('/').last;
      } else if (json['endpoint'] != null) {
        animeId = json['endpoint'].toString().split('/').last;
      } else if (json['samehadakuUrl'] != null) {
        final url = json['samehadakuUrl'].toString();
        animeId = url.split('/anime/').last.replaceAll('/', '');
      }
      
      animeId = animeId.replaceAll('/', '').replaceAll('https:', '').replaceAll('samehadaku', '').trim();
      
      if (kDebugMode) print('   ✅ animeId: $animeId');
      
      // ✅ STEP 2: Extract title
      String animeTitle = json['title']?.toString() ?? json['anime_name']?.toString() ?? '';
      
      // ✅ STEP 3: Extract poster
      String posterImage = json['poster']?.toString() ?? '';
      
      if (posterImage.isEmpty) {
        final shortTitle = animeTitle.length > 20 
            ? animeTitle.substring(0, 20) + "..." 
            : animeTitle;
        posterImage = 'https://placehold.co/300x400/1a1f3a/white?text=${Uri.encodeComponent(shortTitle)}';
      }
      
      if (kDebugMode) print('   ✅ Title & poster OK');
      
      // ✅ STEP 4: Extract episodes
      int? totalEps;
      if (json['episode_count'] != null) {
        totalEps = int.tryParse(json['episode_count'].toString());
      } else if (json['total_episode'] != null) {
        totalEps = int.tryParse(json['total_episode'].toString());
      } else if (json['episodes'] != null) {
        totalEps = int.tryParse(json['episodes'].toString());
      } else if (json['current_episode'] != null) {
        final episodeStr = json['current_episode'].toString();
        final match = RegExp(r'Total\s+(\d+)\s+Eps').firstMatch(episodeStr);
        if (match != null) {
          totalEps = int.tryParse(match.group(1)!);
        }
      }
      
      if (kDebugMode) print('   ✅ Episodes OK');
      
      // ✅ STEP 5: Extract latest episode
      String? latestEp;
      try {
        latestEp = json['current_episode']?.toString() ?? 
                   json['newest_release_date']?.toString() ??
                   json['last_release_date']?.toString() ??
                   json['releasedOn']?.toString();
      } catch (e) {
        latestEp = null;
      }

      if (kDebugMode) print('   🎬 Parsing genres...');
      
      // ✅ STEP 6: Parse genres safely
      List<String>? genreList;
      try {
        genreList = _parseGenreList(json['genreList']);
      } catch (e) {
        if (kDebugMode) print('   ⚠️ Genre parse error: $e');
        genreList = null;
      }

      if (kDebugMode) {
        if (genreList != null && genreList.isNotEmpty) {
          print('   ✅ Genres: ${genreList.join(", ")}');
        } else {
          print('   ℹ️ No genres found');
        }
      }

      // ✅ STEP 7: Extract all other fields safely
      String? synopsisText;
      try {
        synopsisText = json['synopsis']?.toString();
      } catch (e) {
        synopsisText = null;
      }
      
      String? animeUrl;
      try {
        animeUrl = json['samehadakuUrl']?.toString() ?? json['otakudesuUrl']?.toString();
      } catch (e) {
        animeUrl = null;
      }
      
      String? episodeText;
      try {
        episodeText = json['episode']?.toString();
      } catch (e) {
        episodeText = null;
      }
      
      String? statusText;
      try {
        statusText = json['status']?.toString();
      } catch (e) {
        statusText = null;
      }
      
      String? typeText;
      try {
        typeText = json['type']?.toString();
      } catch (e) {
        typeText = null;
      }
      
      // ✅ STEP 8: Extract rating/score safely
      String? ratingText;
      String? scoreText;
      
      try {
        if (json['score'] != null) {
          final scoreValue = json['score'];
          
          if (scoreValue is Map) {
            // If score is an object with 'value' key
            final value = scoreValue['value'];
            if (value != null) {
              ratingText = value.toString();
              scoreText = value.toString();
            }
          } else {
            // If score is a direct value
            ratingText = scoreValue.toString();
            scoreText = scoreValue.toString();
          }
        }
        
        // Fallback to rating field
        if (ratingText == null && json['rating'] != null) {
          ratingText = json['rating'].toString();
          scoreText = json['rating'].toString();
        }
      } catch (e) {
        if (kDebugMode) print('   ⚠️ Rating/Score parse error: $e');
        ratingText = null;
        scoreText = null;
      }

      if (kDebugMode) print('   ✅ Creating Anime object...');

      // ✅ STEP 9: Create Anime object
      return Anime(
        id: animeId,
        title: animeTitle,
        poster: posterImage,
        synopsis: synopsisText,
        latestEpisode: latestEp,
        url: animeUrl,
        episode: episodeText,
        totalEpisodes: totalEps,
        status: statusText,
        rating: ratingText,
        type: typeText,
        score: scoreText,
        genres: genreList,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ ERROR in Anime.fromJson:');
        print('   Error: $e');
        final lines = stackTrace.toString().split('\n');
        if (lines.isNotEmpty) {
          print('   Stack: ${lines[0]}');
          if (lines.length > 1) print('          ${lines[1]}');
        }
      }
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster': poster,
      'synopsis': synopsis,
      'latestEpisode': latestEpisode,
      'url': url,
      'episode': episode,
      'totalEpisodes': totalEpisodes,
      'status': status,
      'rating': rating,
      'type': type,
      'score': score,
      'genres': genres,
    };
  }
}

class AnimeDetail {
  final String id;
  final String title;
  final String poster;
  final String synopsis;
  final List<Episode> episodes;
  final Map<String, String> info;
  final String? status;
  final String? rating;
  final List<String>? genres;
  final Map<String, dynamic>? batch;
  final String? type;
  final String? score;

  AnimeDetail({
    required this.id,
    required this.title,
    required this.poster,
    required this.synopsis,
    required this.episodes,
    required this.info,
    this.status,
    this.rating,
    this.genres,
    this.batch,
    this.type,
    this.score,
  });

  factory AnimeDetail.fromJson(Map<String, dynamic> json) {
    // Better title handling with priority
    String animeTitle = json['title']?.toString().trim() ?? '';
    
    if (animeTitle.isEmpty) {
      if (json['english'] != null && json['english'].toString().trim().isNotEmpty) {
        animeTitle = json['english'].toString().trim();
      } else if (json['japanese'] != null && json['japanese'].toString().trim().isNotEmpty) {
        animeTitle = json['japanese'].toString().trim();
      } else if (json['synonyms'] != null && json['synonyms'].toString().trim().isNotEmpty) {
        animeTitle = json['synonyms'].toString().trim();
      } else {
        animeTitle = 'Unknown Title';
      }
    }

    // Extract anime ID
    String animeId = json['slug'] ?? json['animeId'] ?? json['id'] ?? '';
    animeId = animeId.replaceAll('/', '').trim();

    // ✅ FIX: Parse episodes dengan multiple field names
    final episodes = <Episode>[];
    
    // Try berbagai field names yang mungkin digunakan API
    final episodesList = json['episode_lists'] ?? 
                        json['episodeList'] ?? 
                        json['episodes'] ?? 
                        [];
    
    if (kDebugMode) {
      print('🎬 Parsing episodes from: ${episodesList.runtimeType}');
      if (episodesList is List) {
        print('   Found ${episodesList.length} episodes');
        // ✅ CRITICAL: Print first episode structure
        if (episodesList.isNotEmpty) {
          print('   📋 First episode structure:');
          print('      ${episodesList[0]}');
        }
      }
    }
    
    if (episodesList is List && episodesList.isNotEmpty) {
      for (var i = 0; i < episodesList.length; i++) {
        try {
          final ep = episodesList[i];
          if (kDebugMode) print('   Parsing episode $i: ${ep.runtimeType}');
          episodes.add(Episode.fromJson(ep));
        } catch (e) {
          if (kDebugMode) print('   ⚠️ Failed to parse episode $i: $e');
        }
      }
    }
    
    if (kDebugMode) {
      print('✅ Successfully parsed ${episodes.length} episodes');
      if (episodes.isNotEmpty) {
        print('   🎯 Sample URLs:');
        final sampleCount = episodes.length < 3 ? episodes.length : 3;
        for (var i = 0; i < sampleCount; i++) {
          print('      Ep ${episodes[i].episodeNumber}: "${episodes[i].url}"');
        }
      }
    }

    // Build info map
    final info = <String, String>{};
    
    if (json['score'] != null) {
      if (json['score'] is Map && json['score']['value'] != null) {
        info['Score'] = json['score']['value'].toString();
      } else {
        info['Score'] = json['score'].toString();
      }
    }
    
    if (json['rating'] != null) info['Rating'] = json['rating'].toString();
    if (json['type'] != null) info['Type'] = json['type'];
    if (json['status'] != null) info['Status'] = json['status'];
    if (json['episodes'] != null) info['Episodes'] = json['episodes'].toString();
    if (json['duration'] != null) info['Duration'] = json['duration'];
    if (json['aired'] != null) info['Aired'] = json['aired'];
    if (json['studios'] != null) info['Studio'] = json['studios'];
    if (json['producers'] != null) info['Producers'] = json['producers'];
    if (json['season'] != null) info['Season'] = json['season'];
    if (json['source'] != null) info['Source'] = json['source'];

    // Synopsis
    String synopsisText = 'Sinopsis tidak tersedia.';
    if (json['synopsis'] != null) {
      final synopsisData = json['synopsis'];
      if (synopsisData is Map && synopsisData['paragraphs'] is List) {
        final paragraphs = synopsisData['paragraphs'] as List;
        if (paragraphs.isNotEmpty) {
          synopsisText = paragraphs.join('\n\n');
        }
      } else if (synopsisData is String && synopsisData.isNotEmpty) {
        synopsisText = synopsisData;
      }
    }

    // ✅ FIXED: Use safe genre parsing
    final genreList = _parseGenreList(json['genreList']);

    // Batch info
    Map<String, dynamic>? batchInfo;
    if (json['batch'] is Map) {
      batchInfo = Map<String, dynamic>.from(json['batch']);
    }

    // Poster
    String posterImage = json['poster'] ?? '';
    if (posterImage.isEmpty) {
      final shortTitle = animeTitle.length > 20 
          ? animeTitle.substring(0, 20) + "..." 
          : animeTitle;
      posterImage = 'https://placehold.co/300x400/1a1f3a/white?text=${Uri.encodeComponent(shortTitle)}';
    }

    return AnimeDetail(
      id: animeId,
      title: animeTitle,
      poster: posterImage,
      synopsis: synopsisText,
      episodes: episodes,
      info: info,
      status: json['status'],
      rating: json['score']?['value']?.toString() ?? json['rating']?.toString(),
      genres: genreList,
      batch: batchInfo,
      type: json['type'],
      score: json['score']?['value']?.toString() ?? json['rating']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster': poster,
      'synopsis': synopsis,
      'episodes': episodes.map((e) => e.toJson()).toList(),
      'info': info,
      'status': status,
      'rating': rating,
      'genres': genres,
      'batch': batch,
      'type': type,
      'score': score,
    };
  }
}



class Episode {
  final String number;
  final String date;
  final String url;
  final String? title;
  final int? episodeNumber;

  Episode({
    required this.number,
    required this.date,
    required this.url,
    this.title,
    this.episodeNumber,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('🔍 Episode.fromJson: $json');
    }
    
    String episodeTitle = '';
    int? episodeNum;
    
    // ✅ PRIORITY 1: episode_number field (most reliable)
    if (json['episode_number'] != null) {
      if (json['episode_number'] is int) {
        episodeNum = json['episode_number'];
      } else {
        episodeNum = int.tryParse(json['episode_number'].toString());
      }
      episodeTitle = 'Episode $episodeNum';
      if (kDebugMode) print('   📍 episode_number: $episodeNum');
    }
    // Fallback: title field
    else if (json['title'] != null) {
      final titleValue = json['title'];
      episodeNum = int.tryParse(titleValue.toString());
      episodeTitle = 'Episode $titleValue';
      if (kDebugMode) print('   📍 from title: $episodeNum');
    }
    
    String episodeUrl = '';
    
    // ✅ PRIORITY 1: slug field (most reliable)
    if (json['slug'] != null && json['slug'].toString().isNotEmpty) {
      episodeUrl = json['slug'].toString();
      if (kDebugMode) print('   ✅ URL from slug: $episodeUrl');
    }
    // Fallback: episodeId
    else if (json['episodeId'] != null && json['episodeId'].toString().isNotEmpty) {
      episodeUrl = json['episodeId'].toString();
      if (kDebugMode) print('   ✅ URL from episodeId: $episodeUrl');
    }
    // Fallback: extract from href
    else if (json['href'] != null && json['href'].toString().isNotEmpty) {
      final href = json['href'].toString();
      final match = RegExp(r'/episode/([^/]+)').firstMatch(href);
      if (match != null) {
        episodeUrl = match.group(1)!;
        if (kDebugMode) print('   ✅ URL from href: $episodeUrl');
      }
    }
    
    // Clean URL
    episodeUrl = episodeUrl.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    
    String episodeDate = json['otakudesu_url'] ?? json['samehadakuUrl'] ?? '';
    
    if (kDebugMode) {
      print('   🎯 FINAL: Ep $episodeNum -> "$episodeUrl"');
    }
    
    return Episode(
      number: episodeTitle.isNotEmpty ? episodeTitle : 'Episode $episodeNum',
      date: episodeDate,
      url: episodeUrl,
      title: episodeTitle,
      episodeNumber: episodeNum,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'date': date,
      'url': url,
      'title': title,
      'episodeNumber': episodeNumber,
    };
  }
}
