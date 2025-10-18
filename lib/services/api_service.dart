import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiService {
  // Railway Backend URLs from config
  static String get BASE_URL => AppConfig.API_BASE_URL;
  static String get ANIME_BASE_URL => AppConfig.ANIME_BASE_URL;
  
  // Common headers for all requests
  static Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': AppConfig.USER_AGENT,
  };

  // Generic method to handle API responses
  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    AppConfig.printDebug('API Response: ${response.statusCode} - ${response.request?.url}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        AppConfig.printDebug('API Success: ${data['data']?.toString().substring(0, 100) ?? 'No data'}...');
        return data;
      } else {
        AppConfig.printError('API Error: ${data['message'] ?? 'Unknown error'}');
        throw ApiException('API Error: ${data['message'] ?? 'Unknown error'}');
      }
    } else {
      AppConfig.printError('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
      throw ApiException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  // Fetch homepage data
  static Future<Map<String, dynamic>> fetchHomeData() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/home'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      print('Home fetch error: $e');
      rethrow;
    }
  }

  // Fetch ongoing anime
  static Future<Map<String, dynamic>> fetchOngoingAnime({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/ongoing?page=$page'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      print('Ongoing anime fetch error: $e');
      rethrow;
    }
  }

  // Search anime
  static Future<Map<String, dynamic>> searchAnime(String query) async {
    if (query.isEmpty) {
      throw ApiException('Search query cannot be empty');
    }
    
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/search/${Uri.encodeComponent(query)}'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      print('Search error: $e');
      rethrow;
    }
  }

  // Fetch anime detail
  static Future<Map<String, dynamic>> fetchAnimeDetail(String slug) async {
    if (slug.isEmpty) {
      throw ApiException('Anime slug cannot be empty');
    }
    
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/$slug'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      print('Anime detail fetch error: $e');
      rethrow;
    }
  }

  // Fetch episode detail with video sources
  static Future<Map<String, dynamic>> fetchEpisodeDetail(String episodeSlug) async {
    if (episodeSlug.isEmpty) {
      throw ApiException('Episode slug cannot be empty');
    }
    
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/episode/$episodeSlug'),
        headers: _headers,
      );
      
      print('Episode API Response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Episode API Body: ${json.encode(data)}');
        
        if (data['status'] == 'success') {
          return data;
        } else {
          throw ApiException('Backend error: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        throw ApiException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Episode detail fetch error: $e');
      rethrow;
    }
  }

  // Fetch anime schedule
  static Future<Map<String, dynamic>> fetchSchedule() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/schedule'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      print('Schedule fetch error: $e');
      rethrow;
    }
  }

  // Fetch anime by genre
  static Future<Map<String, dynamic>> fetchAnimeByGenre(String genre, {int page = 1}) async {
    if (genre.isEmpty) {
      throw ApiException('Genre cannot be empty');
    }
    
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/genre/${Uri.encodeComponent(genre)}?page=$page'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      print('Genre fetch error: $e');
      rethrow;
    }
  }

  // Fetch anime by release year
  static Future<Map<String, dynamic>> fetchAnimeByYear(int year) async {
    if (year < 1900 || year > DateTime.now().year + 5) {
      throw ApiException('Invalid year: $year');
    }
    
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/release-year/$year'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      print('Year fetch error: $e');
      rethrow;
    }
  }

  // Fetch complete anime
  static Future<Map<String, dynamic>> fetchCompleteAnime({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/complete/$page'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      print('Complete anime fetch error: $e');
      rethrow;
    }
  }

  // Fetch season ongoing
  static Future<Map<String, dynamic>> fetchSeasonOngoing() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/season/ongoing'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      print('Season ongoing fetch error: $e');
      rethrow;
    }
  }

  // Extract video sources from episode data
  static Map<String, String> extractVideoSources(Map<String, dynamic> episodeData) {
    final Map<String, String> qualityUrls = {};
    
    try {
      // Primary: Use video_sources (enhanced format)
      if (episodeData['video_sources'] != null) {
        final videoSources = episodeData['video_sources'] as List;
        
        for (var source in videoSources) {
          String quality = source['quality'] ?? 'auto';
          String url = source['url'] ?? '';
          String type = source['type'] ?? 'mp4';
          
          if (url.isNotEmpty) {
            qualityUrls[quality] = url;
            print('Added quality: $quality -> $url (type: $type)');
          }
        }
      }
      
      // Fallback: Use download_urls (legacy format)
      if (qualityUrls.isEmpty && episodeData['download_urls'] != null) {
        final downloads = episodeData['download_urls'];
        if (downloads['mp4'] != null) {
          for (var quality in downloads['mp4']) {
            String resolution = quality['resolution'] ?? 'auto';
            if (quality['urls'] != null && quality['urls'].isNotEmpty) {
              qualityUrls[resolution] = quality['urls'][0]['url'];
              print('Added legacy quality: $resolution -> ${quality['urls'][0]['url']}');
            }
          }
        }
      }
      
      // Additional: Check stream_urls for HLS sources
      if (episodeData['stream_urls'] != null) {
        final streamUrls = episodeData['stream_urls'] as List;
        for (var stream in streamUrls) {
          String quality = stream['quality'] ?? 'HLS';
          String url = stream['url'] ?? '';
          if (url.isNotEmpty && !qualityUrls.containsKey(quality)) {
            qualityUrls[quality] = url;
            print('Added HLS quality: $quality -> $url');
          }
        }
      }
      
      print('Final extracted qualities: ${qualityUrls.keys.toList()}');
      return qualityUrls;
    } catch (e) {
      print('Error extracting video sources: $e');
      return {};
    }
  }

  // Get preferred quality from available qualities
  static String getPreferredQuality(List<String> availableQualities) {
    if (availableQualities.isEmpty) return 'auto';
    
    // Use preferred qualities from config
    for (String preferredQuality in AppConfig.PREFERRED_QUALITIES) {
      if (availableQualities.contains(preferredQuality)) {
        return preferredQuality;
      }
    }
    
    return availableQualities.first;
  }
}

// Custom exception class for API errors
class ApiException implements Exception {
  final String message;
  
  ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}