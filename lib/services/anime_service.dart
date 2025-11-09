// services/anime_service.dart - FIXED ALL PARSING ISSUES
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';

class AnimeService {
  final String baseUrl = 'https://anime-backend-xi.vercel.app/anime/';
  late Dio _dio;

  AnimeService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 90),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Sukinime/2.0',
      },
      validateStatus: (status) => status != null && status < 500,
    ));

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: true,
          error: true,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }

  Future<Response?> _safeApiCall(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (kDebugMode) print('🔄 Attempt ${attempt + 1}: $endpoint');
        
        if (attempt > 0) {
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
        
        final response = await _dio.get(
          endpoint,
          queryParameters: queryParameters,
        );
        
        if (response.statusCode == 200) {
          if (kDebugMode) print('✅ Success: $endpoint');
          return response;
        }
        
        if (kDebugMode) print('⚠️ Status ${response.statusCode}: $endpoint');
        
      } on DioException catch (e) {
        if (kDebugMode) {
          print('❌ DioException: ${e.type}');
          print('   Message: ${e.message}');
        }
        
        if (attempt == maxRetries - 1) break;
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    
    return null;
  }

  // ✅ FIXED: Parsing yang lebih fleksibel
  List<Anime> _parseAnimeList(dynamic data) {
    if (kDebugMode) {
      print('\n🔍 PARSING ANIME LIST');
      print('   Data type: ${data.runtimeType}');
    }
    
    if (data == null) {
      if (kDebugMode) print('❌ Data is null');
      return [];
    }
    
    List<dynamic> animeListRaw = [];
    
    // ✅ NEW: Cek berbagai struktur data yang mungkin
    if (data is Map) {
      // Struktur 1: {data: {anime: [...]}}
      if (data['data'] is Map && data['data']['anime'] is List) {
        animeListRaw = data['data']['anime'] as List;
        if (kDebugMode) print('   📦 Found: data.anime structure');
      }
      // Struktur 2: {data: {animeList: [...]}}
      else if (data['data'] is Map && data['data']['animeList'] is List) {
        animeListRaw = data['data']['animeList'] as List;
        if (kDebugMode) print('   📦 Found: data.animeList structure');
      }
      // Struktur 3: {data: [..]} (direct array)
      else if (data['data'] is List) {
        animeListRaw = data['data'] as List;
        if (kDebugMode) print('   📦 Found: data array structure');
      }
      // Struktur 4: {anime: [...]}
      else if (data['anime'] is List) {
        animeListRaw = data['anime'] as List;
        if (kDebugMode) print('   📦 Found: anime array structure');
      }
      // Struktur 5: {animeList: [...]}
      else if (data['animeList'] is List) {
        animeListRaw = data['animeList'] as List;
        if (kDebugMode) print('   📦 Found: animeList array structure');
      }
    } 
    // Struktur 6: Direct array
    else if (data is List) {
      animeListRaw = data;
      if (kDebugMode) print('   📦 Found: direct array structure');
    }
    
    if (animeListRaw.isEmpty) {
      if (kDebugMode) {
        print('❌ Could not parse anime list');
        print('   Available keys: ${data is Map ? data.keys.toList() : "N/A"}');
      }
      return [];
    }
    
    if (kDebugMode) print('✅ Found ${animeListRaw.length} anime items');
    
    final result = <Anime>[];
    
    for (int index = 0; index < animeListRaw.length; index++) {
      try {
        final item = animeListRaw[index];
        
        if (item is Map<String, dynamic>) {
          final anime = Anime.fromJson(item);
          result.add(anime);
        } else if (item is Map) {
          final anime = Anime.fromJson(Map<String, dynamic>.from(item));
          result.add(anime);
        } else {
          if (kDebugMode) print('⚠️ Skip anime $index: invalid type ${item.runtimeType}');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('⚠️ Skip anime $index: $e');
          final lines = stackTrace.toString().split('\n');
          if (lines.isNotEmpty) print('   ${lines[0]}');
        }
      }
    }
    
    if (kDebugMode) print('✅ Parsed ${result.length} anime successfully');
    return result;
  }

  // HOME
  Future<Map<String, List<Anime>>> getHome() async {
    try {
      if (kDebugMode) print('\n🏠 Fetching home...');
      
      final response = await _safeApiCall('home');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final data = responseData['data'];
          final result = <String, List<Anime>>{};
          
          if (data is Map) {
            if (data['ongoing_anime'] is List) {
              result['ongoing'] = (data['ongoing_anime'] as List)
                  .map((e) => Anime.fromJson(e))
                  .toList();
            }
            if (data['complete_anime'] is List) {
              result['complete'] = (data['complete_anime'] as List)
                  .map((e) => Anime.fromJson(e))
                  .toList();
            }
          }
          
          if (kDebugMode) {
            print('✅ Home loaded:');
            print('   Ongoing: ${result['ongoing']?.length ?? 0}');
            print('   Complete: ${result['complete']?.length ?? 0}');
          }
          return result;
        }
      }
      
      return {};
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return {};
    }
  }

  // RECENT ANIME
  Future<List<Anime>> getRecentAnime({int page = 1}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching recent (page: $page)');
      
      final response = await _safeApiCall('home');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final data = responseData['data'];
          
          if (data is Map && data['ongoing_anime'] is List) {
            final animeList = (data['ongoing_anime'] as List)
                .map((e) => Anime.fromJson(e))
                .toList();
            if (kDebugMode) print('✅ Recent loaded: ${animeList.length} anime');
            return animeList;
          }
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // ✅ FIXED: Search with fallback
  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    try {
      final trimmedQuery = query.trim();
      if (trimmedQuery.isEmpty) return [];
      
      if (kDebugMode) print('\n🔍 Searching: $trimmedQuery');
      
      final response = await _safeApiCall('search/$trimmedQuery', maxRetries: 2);
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final animeList = _parseAnimeList(responseData);
          if (animeList.isNotEmpty) {
            if (kDebugMode) print('✅ Search found ${animeList.length} results');
            return animeList;
          }
        }
      }
      
      // ✅ FALLBACK: Search in home data
      if (kDebugMode) print('⚠️ API search unavailable, using fallback search...');
      
      final homeData = await getHome();
      final List<Anime> allAnime = [
        ...?homeData['ongoing'],
        ...?homeData['complete'],
      ];
      
      if (kDebugMode) print('📊 Fallback: searching in ${allAnime.length} anime');
      
      final queryLower = trimmedQuery.toLowerCase();
      final List<Anime> filtered = allAnime.where((anime) {
        return anime.title.toLowerCase().contains(queryLower);
      }).toList();
      
      if (kDebugMode) print('✅ Fallback search found ${filtered.length} results');
      return filtered;
      
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // ONGOING
  Future<List<Anime>> getOngoingAnime({int page = 1, String order = 'popular'}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching ongoing (page: $page)');
      
      final response = await _safeApiCall('ongoing-anime', queryParameters: {'page': page});
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final animeList = _parseAnimeList(responseData);
          if (kDebugMode) print('✅ Ongoing loaded: ${animeList.length} anime');
          return animeList;
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // COMPLETED
  Future<List<Anime>> getCompletedAnime({int page = 1, String order = 'latest'}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching completed (page: $page)');
      
      final response = await _safeApiCall('complete-anime/$page');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final animeList = _parseAnimeList(responseData);
          if (kDebugMode) print('✅ Completed loaded: ${animeList.length} anime');
          return animeList;
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // POPULAR
  Future<List<Anime>> getPopularAnime({int page = 1}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching popular (page: $page)');
      return await getOngoingAnime(page: page);
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // MOVIES
  Future<List<Anime>> getMovies({int page = 1, String order = 'update'}) async {
    try {
      if (kDebugMode) print('\n📡 Movies not available');
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // ✅ FIXED: All Anime List with fallback
  Future<List<Anime>> getAllAnimeList() async {
    try {
      if (kDebugMode) print('\n📚 Fetching anime list...');
      
      // Try ongoing first
      final response = await _safeApiCall('ongoing-anime', queryParameters: {'page': 1});
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final animeList = _parseAnimeList(responseData);
          if (animeList.isNotEmpty) {
            if (kDebugMode) print('✅ List loaded: ${animeList.length} anime');
            return animeList;
          }
        }
      }
      
      // ✅ FALLBACK: Use home data
      if (kDebugMode) print('⚠️ Using home data as fallback...');
      final homeData = await getHome();
      final List<Anime> allAnime = [
        ...?homeData['ongoing'],
        ...?homeData['complete'],
      ];
      
      if (kDebugMode) print('✅ Fallback loaded: ${allAnime.length} anime');
      return allAnime;
      
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // ✅ FIXED: Schedule with better error handling
  Future<Map<String, dynamic>> getSchedule() async {
    try {
      if (kDebugMode) print('\n📅 Fetching schedule...');
      
      final response = await _safeApiCall('schedule', maxRetries: 1);
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final data = responseData['data'];
          
          if (data is List) {
            final scheduleMap = <String, dynamic>{};
            for (var dayData in data) {
              if (dayData is Map && dayData['day'] != null) {
                scheduleMap[dayData['day']] = dayData['anime_list'] ?? [];
              }
            }
            
            if (kDebugMode) print('✅ Schedule loaded: ${scheduleMap.keys.length} days');
            if (scheduleMap.isNotEmpty) return scheduleMap;
          }
        }
      }
      
      // ✅ Return empty if unavailable
      if (kDebugMode) print('⚠️ Schedule endpoint unavailable');
      return {};
      
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return {};
    }
  }

  // GENRES
  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      if (kDebugMode) print('\n📂 Fetching genres...');
      
      final response = await _safeApiCall('genre');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final data = responseData['data'];
          
          List genreData = [];
          if (data is List) {
            genreData = data;
          }
          
          final genres = genreData.map((e) {
            return {
              'id': e['slug'] ?? e['id'] ?? '',
              'name': e['name'] ?? '',
              'slug': e['slug'] ?? '',
              'url': e['otakudesu_url'] ?? '',
            };
          }).toList();
          
          if (kDebugMode) print('✅ Found ${genres.length} genres');
          return genres;
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // ✅ FIXED: Anime by Genre with pagination
  Future<Map<String, dynamic>> getAnimeByGenreWithPagination(String genreId, {int page = 1}) async {
    try {
      if (kDebugMode) print('\n📂 Fetching genre "$genreId" (page: $page)');
      
      final response = await _safeApiCall(
        'genre/$genreId',
        queryParameters: {'page': page},
      );
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final animeList = _parseAnimeList(responseData);
          
          Map<String, dynamic> paginationInfo = {
            'currentPage': page,
            'hasNextPage': false,
            'totalPages': 1,
          };
          
          if (responseData['data'] is Map && responseData['data']['pagination'] is Map) {
            final pagination = responseData['data']['pagination'];
            paginationInfo = {
              'currentPage': pagination['current_page'] ?? page,
              'hasNextPage': pagination['has_next_page'] ?? false,
              'totalPages': pagination['last_visible_page'] ?? 1,
              'nextPage': pagination['next_page'],
              'prevPage': pagination['previous_page'],
            };
            
            if (kDebugMode) {
              print('✅ Found ${animeList.length} anime');
              print('   Page: ${paginationInfo['currentPage']}/${paginationInfo['totalPages']}');
              print('   Has more: ${paginationInfo['hasNextPage']}');
            }
          } else {
            if (kDebugMode) print('✅ Found ${animeList.length} anime (no pagination info)');
          }
          
          return {
            'animes': animeList,
            'pagination': paginationInfo,
          };
        }
      }
      
      return {
        'animes': <Anime>[],
        'pagination': {
          'currentPage': page,
          'hasNextPage': false,
          'totalPages': 1,
        },
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return {
        'animes': <Anime>[],
        'pagination': {
          'currentPage': page,
          'hasNextPage': false,
          'totalPages': 1,
        },
      };
    }
  }
  
  Future<List<Anime>> getAnimeByGenre(String genreId, {int page = 1}) async {
    final result = await getAnimeByGenreWithPagination(genreId, page: page);
    return result['animes'] as List<Anime>;
  }

  // BATCH LIST
  Future<List<Map<String, dynamic>>> getBatchList({int page = 1}) async {
    try {
      if (kDebugMode) print('\n📦 Batch list not available');
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // ✅ FIXED: Anime Detail with better episode parsing
  Future<AnimeDetail?> getAnimeDetail(String animeId) async {
    try {
      if (kDebugMode) print('\n📺 Fetching detail: $animeId');
      
      final response = await _safeApiCall('anime/$animeId');
      
      if (response == null) {
        if (kDebugMode) print('❌ Response is null');
        return null;
      }
      
      if (response.statusCode != 200) {
        if (kDebugMode) print('❌ Status code: ${response.statusCode}');
        return null;
      }
      
      final responseData = response.data;
      
      if (responseData == null) {
        if (kDebugMode) print('❌ Response data is null');
        return null;
      }
      
      if (responseData is! Map) {
        if (kDebugMode) print('❌ Response data is not a Map: ${responseData.runtimeType}');
        return null;
      }
      
      final animeData = responseData['data'];
      
      if (animeData == null) {
        if (kDebugMode) print('❌ Anime data is null');
        return null;
      }
      
      if (animeData is! Map) {
        if (kDebugMode) print('❌ Anime data is not a Map: ${animeData.runtimeType}');
        return null;
      }
      
      try {
        // ✅ Debug: Print raw data structure
        if (kDebugMode) {
          print('📊 Raw anime data structure:');
          print('   Keys: ${animeData.keys.toList()}');
          if (animeData['episodeList'] != null) {
            print('   episodeList type: ${animeData['episodeList'].runtimeType}');
            if (animeData['episodeList'] is List) {
              print('   episodeList length: ${(animeData['episodeList'] as List).length}');
            }
          }
        }
        
        final detail = AnimeDetail.fromJson(
          Map<String, dynamic>.from(animeData)
        );
        
        if (kDebugMode) {
          print('✅ AnimeDetail parsed successfully:');
          print('   Final title: "${detail.title}"');
          print('   Episodes: ${detail.episodes.length}');
          if (detail.episodes.isEmpty && animeData['episodeList'] != null) {
            print('   ⚠️ WARNING: Episodes were in API but failed to parse!');
          }
        }
        
        return detail;
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('❌ Failed to parse AnimeDetail: $e');
          print('   Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
        }
        return null;
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ Exception in getAnimeDetail: $e');
      return null;
    }
  }

  // EPISODE DETAIL
  Future<Map<String, dynamic>?> getEpisodeDetail(String episodeId) async {
    try {
      String cleanEpisodeId = episodeId.trim().replaceAll(RegExp(r'^/+|/+$'), '');
      
      if (kDebugMode) print('🎬 SERVICE: Fetching episode detail for: $cleanEpisodeId');
      
      final response = await _safeApiCall('episode/$cleanEpisodeId', maxRetries: 3);
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final data = responseData['data'];
          
          if (data != null && data is Map) {
            if (kDebugMode) {
              print('✅ SERVICE: Episode data received');
              print('   Available keys: ${data.keys.toList()}');
            }
            
            return Map<String, dynamic>.from(data);
          }
        }
      }
      
      if (kDebugMode) print('⚠️ SERVICE: Failed to get episode detail');
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ SERVICE Error in getEpisodeDetail: $e');
        print('   Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      }
      return null;
    }
  }

  // STREAMING LINKS
  Future<List<StreamLink>> getStreamingLinks(String episodeUrl) async {
    try {
      if (kDebugMode) print('\n🔥 FETCHING STREAMING LINKS: $episodeUrl');
      
      String cleanEpisodeId = episodeUrl;
      
      final response = await _safeApiCall('episode/$cleanEpisodeId', maxRetries: 3);
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final data = responseData['data'];
          final List<StreamLink> allLinks = [];
          
          if (data['stream_url'] != null && data['stream_url'].toString().isNotEmpty) {
            final streamUrl = data['stream_url'].toString();
            allLinks.add(StreamLink.fromJson({
              'provider': 'Desustream Default',
              'url': streamUrl,
              'type': streamUrl.contains('.m3u8') ? 'hls' : 'mp4',
              'quality': 'auto',
              'source': 'default',
              'priority': 0,
            }));
            if (kDebugMode) print('✅ Added stream_url: Desustream');
          }
          
          if (data['download_urls'] != null && data['download_urls'] is Map) {
            final downloadUrls = data['download_urls'] as Map;
            
            if (downloadUrls['mp4'] is List) {
              for (var resolutionData in downloadUrls['mp4']) {
                final resolution = resolutionData['resolution'] ?? 'auto';
                final urls = resolutionData['urls'] as List? ?? [];
                
                for (var urlData in urls) {
                  final provider = urlData['provider'] ?? 'Unknown';
                  final url = urlData['url'] ?? '';
                  
                  if (url.isNotEmpty) {
                    allLinks.add(StreamLink.fromJson({
                      'provider': '$provider $resolution',
                      'url': url,
                      'type': 'mp4',
                      'quality': resolution,
                      'source': 'download',
                      'priority': 50,
                    }));
                  }
                }
              }
            }
          }
          
          allLinks.sort((a, b) {
            final priorityA = (a.toJson()['priority'] ?? 99) as int;
            final priorityB = (b.toJson()['priority'] ?? 99) as int;
            return priorityA.compareTo(priorityB);
          });
          
          if (kDebugMode) {
            print('✅ Total links: ${allLinks.length}');
            if (allLinks.isNotEmpty) {
              print('   🎯 Primary: ${allLinks.first.provider}');
            }
          }
          
          return allLinks;
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // BATCH DETAIL
  Future<Map<String, dynamic>?> getBatchDetail(String batchId) async {
    try {
      if (kDebugMode) print('\n📦 Fetching batch detail: $batchId');
      
      final response = await _safeApiCall('batch/$batchId');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map) {
          return responseData['data'];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return null;
    }
  }

  // SERVER URL
  Future<String?> getServerUrl(String serverId) async {
    try {
      if (kDebugMode) print('\n🎬 Server URL not available');
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return null;
    }
  }
}