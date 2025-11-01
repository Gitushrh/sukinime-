// services/anime_service.dart - FIXED: Safe anime list parsing
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';

class AnimeService {
  final String baseUrl = 'https://anime-backend-tau.vercel.app/';
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

  // ✅ FIXED: Safe anime list parser with proper error handling
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
    
    if (data is Map && data['data'] != null) {
      final dataContent = data['data'];
      
      if (dataContent is Map && dataContent['animeList'] is List) {
        animeListRaw = dataContent['animeList'] as List;
      } else if (dataContent is List) {
        animeListRaw = dataContent;
      }
    } else if (data is Map && data['animeList'] is List) {
      animeListRaw = data['animeList'] as List;
    } else if (data is List) {
      animeListRaw = data;
    }
    
    if (animeListRaw.isEmpty) {
      if (kDebugMode) print('❌ Could not parse anime list');
      return [];
    }
    
    if (kDebugMode) print('✅ Found ${animeListRaw.length} anime');
    
    // ✅ FIXED: Use indexed for loop to avoid type issues
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
          // Only print first 2 lines of stack trace to avoid clutter
          final lines = stackTrace.toString().split('\n');
          if (lines.isNotEmpty) print('   ${lines[0]}');
        }
      }
    }
    
    if (kDebugMode) print('✅ Parsed ${result.length} anime successfully');
    return result;
  }

  Future<Map<String, List<Anime>>> getHome() async {
    try {
      if (kDebugMode) print('\n🏠 Fetching home...');
      
      final response = await _safeApiCall('/home');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'success') {
          final data = responseData['data'];
          final result = <String, List<Anime>>{};
          
          if (data is Map) {
            if (data['ongoing'] is List) {
              result['ongoing'] = (data['ongoing'] as List)
                  .map((e) => Anime.fromJson(e))
                  .toList();
            }
            if (data['complete'] is List) {
              result['complete'] = (data['complete'] as List)
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

  Future<List<Anime>> getRecentAnime({int page = 1}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching recent (page: $page)');
      
      final response = await _safeApiCall('/recent', queryParameters: {'page': page});
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'success') {
          final animeList = _parseAnimeList(responseData);
          if (kDebugMode) print('✅ Recent loaded: ${animeList.length} anime');
          return animeList;
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    try {
      final trimmedQuery = query.trim();
      if (trimmedQuery.isEmpty) return [];
      
      if (kDebugMode) print('\n🔍 Searching: $trimmedQuery');
      
      final response = await _safeApiCall(
        '/search',
        queryParameters: {'q': trimmedQuery, 'page': page},
      );
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'success') {
          final animeList = _parseAnimeList(responseData);
          if (kDebugMode) print('✅ Search found ${animeList.length} results');
          return animeList;
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  Future<List<Anime>> getOngoingAnime({int page = 1, String order = 'popular'}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching ongoing (page: $page, order: $order)');
      
      final response = await _safeApiCall(
        '/ongoing',
        queryParameters: {'page': page, 'order': order},
      );
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'Ok') {
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

  Future<List<Anime>> getCompletedAnime({int page = 1, String order = 'latest'}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching completed (page: $page, order: $order)');
      
      final response = await _safeApiCall(
        '/completed',
        queryParameters: {'page': page, 'order': order},
      );
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'Ok') {
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

  Future<List<Anime>> getPopularAnime({int page = 1}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching popular (page: $page)');
      
      final response = await _safeApiCall('/popular', queryParameters: {'page': page});
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'Ok') {
          final animeList = _parseAnimeList(responseData);
          if (kDebugMode) print('✅ Popular loaded: ${animeList.length} anime');
          return animeList;
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  Future<List<Anime>> getMovies({int page = 1, String order = 'update'}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching movies (page: $page, order: $order)');
      
      final response = await _safeApiCall(
        '/movies',
        queryParameters: {'page': page, 'order': order},
      );
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'Ok') {
          final animeList = _parseAnimeList(responseData);
          if (kDebugMode) print('✅ Movies loaded: ${animeList.length} anime');
          return animeList;
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  Future<List<Anime>> getAllAnimeList() async {
    try {
      if (kDebugMode) print('\n📚 Fetching anime list...');
      
      final response = await _safeApiCall('/list');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'success') {
          final data = responseData['data'];
          
          if (data is Map && data['list'] is List) {
            final listGroups = data['list'] as List;
            final allAnime = <Anime>[];
            
            for (var group in listGroups) {
              if (group is Map && group['animeList'] is List) {
                final animeList = group['animeList'] as List;
                for (var anime in animeList) {
                  try {
                    allAnime.add(Anime.fromJson(anime));
                  } catch (e) {
                    if (kDebugMode) print('⚠️ Failed to parse anime: $e');
                  }
                }
              }
            }
            
            if (kDebugMode) print('✅ List loaded: ${allAnime.length} anime');
            return allAnime;
          }
        }
      }
      
      if (kDebugMode) print('⚠️ List failed, trying fallback...');
      final ongoing = await getOngoingAnime(page: 1);
      final complete = await getCompletedAnime(page: 1);
      
      return [...ongoing, ...complete];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSchedule() async {
    try {
      if (kDebugMode) print('\n📅 Fetching schedule...');
      
      final response = await _safeApiCall('/schedule');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'success') {
          final data = responseData['data'];
          
          if (data is Map && data['days'] is List) {
            final daysList = data['days'] as List;
            final scheduleMap = <String, dynamic>{};
            
            for (var dayData in daysList) {
              if (dayData is Map) {
                final day = dayData['day'] ?? '';
                final animeList = dayData['animeList'] ?? [];
                if (day.isNotEmpty) {
                  scheduleMap[day] = animeList;
                }
              }
            }
            
            if (kDebugMode) print('✅ Schedule loaded: ${scheduleMap.keys.length} days');
            return scheduleMap;
          }
          
          if (data is Map) {
            if (kDebugMode) print('✅ Schedule loaded: ${data.keys.length} days');
            return Map<String, dynamic>.from(data);
          }
        }
      }
      
      return {};
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      if (kDebugMode) print('\n📂 Fetching genres...');
      
      final response = await _safeApiCall('/genres');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'success') {
          final data = responseData['data'];
          
          List genreData = [];
          if (data is Map && data['genreList'] is List) {
            genreData = data['genreList'] as List;
          } else if (data is List) {
            genreData = data;
          }
          
          final genres = genreData.map((e) {
            return {
              'id': e['genreId'] ?? e['slug'] ?? e['id'] ?? '',
              'name': e['title'] ?? e['name'] ?? '',
              'slug': e['genreId'] ?? e['slug'] ?? '',
              'url': e['samehadakuUrl'] ?? e['url'] ?? '',
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

  // ✅ NEW: Return anime list WITH pagination info
  Future<Map<String, dynamic>> getAnimeByGenreWithPagination(String genreId, {int page = 1}) async {
    try {
      if (kDebugMode) print('\n📂 Fetching genre "$genreId" (page: $page)');
      
      final response = await _safeApiCall(
        '/genres/$genreId',
        queryParameters: {'page': page},
      );
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && 
            (responseData['status'] == 'success' || responseData['status'] == 'Ok')) {
          final animeList = _parseAnimeList(responseData);
          
          // ✅ Extract pagination info
          Map<String, dynamic> paginationInfo = {
            'currentPage': page,
            'hasNextPage': false,
            'totalPages': 1,
          };
          
          if (responseData['pagination'] is Map) {
            final pagination = responseData['pagination'];
            paginationInfo = {
              'currentPage': pagination['currentPage'] ?? page,
              'hasNextPage': pagination['hasNextPage'] ?? false,
              'totalPages': pagination['totalPages'] ?? 1,
              'nextPage': pagination['nextPage'],
              'prevPage': pagination['prevPage'],
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
  
  // Keep old method for backward compatibility
  Future<List<Anime>> getAnimeByGenre(String genreId, {int page = 1}) async {
    final result = await getAnimeByGenreWithPagination(genreId, page: page);
    return result['animes'] as List<Anime>;
  }

  Future<List<Map<String, dynamic>>> getBatchList({int page = 1}) async {
    try {
      if (kDebugMode) print('\n📦 Fetching batch list (page: $page)');
      
      final response = await _safeApiCall('/batch', queryParameters: {'page': page});
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'Ok') {
          final batchData = responseData['data'];
          
          if (batchData is List) {
            final batches = batchData.map((e) => Map<String, dynamic>.from(e)).toList();
            if (kDebugMode) print('✅ Found ${batches.length} batches');
            return batches;
          }
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  Future<AnimeDetail?> getAnimeDetail(String animeId) async {
    try {
      if (kDebugMode) print('\n📺 Fetching detail: $animeId');
      
      final response = await _safeApiCall('/anime/$animeId');
      
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
      
      final status = responseData['status'];
      if (status != 'success' && status != 'Ok') {
        if (kDebugMode) print('❌ Status is not success/Ok: $status');
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
      
      final title = animeData['title'];
      final english = animeData['english'];
      final japanese = animeData['japanese'];
      final synonyms = animeData['synonyms'];
      
      if (kDebugMode) {
        print('📊 Title validation:');
        print('   title: "$title"');
        print('   english: "$english"');
        print('   japanese: "$japanese"');
        print('   synonyms: "$synonyms"');
      }
      
      final hasValidTitle = (title != null && title.toString().trim().isNotEmpty) ||
                           (english != null && english.toString().trim().isNotEmpty) ||
                           (japanese != null && japanese.toString().trim().isNotEmpty) ||
                           (synonyms != null && synonyms.toString().trim().isNotEmpty);
      
      if (!hasValidTitle) {
        if (kDebugMode) print('❌ No valid title found in any field');
        return null;
      }
      
      try {
        final detail = AnimeDetail.fromJson(
          Map<String, dynamic>.from(animeData)
        );
        
        if (kDebugMode) {
          print('✅ AnimeDetail parsed successfully:');
          print('   Final title: "${detail.title}"');
          print('   Episodes: ${detail.episodes.length}');
        }
        
        return detail;
      } catch (e) {
        if (kDebugMode) print('❌ Failed to parse AnimeDetail: $e');
        return null;
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ Exception in getAnimeDetail: $e');
      return null;
    }
  }

  Future<List<StreamLink>> getStreamingLinks(String episodeUrl) async {
    try {
      if (kDebugMode) print('\n🔥 FETCHING STREAMING LINKS: $episodeUrl');
      
      String cleanEpisodeId = episodeUrl;
      
      if (episodeUrl.startsWith('samehadaku/episode/')) {
        cleanEpisodeId = episodeUrl.replaceFirst('samehadaku/episode/', '');
        if (kDebugMode) print('🔧 Cleaned URL: $cleanEpisodeId');
      }
      
      final response = await _safeApiCall('/episode/$cleanEpisodeId', maxRetries: 3);
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'Ok') {
          final data = responseData['data'];
          final List<StreamLink> allLinks = [];
          
          // ✅ PRIORITY 1: Add defaultStreamingUrl FIRST (Blogger - fastest)
          if (data['defaultStreamingUrl'] != null && 
              data['defaultStreamingUrl'].toString().isNotEmpty) {
            final defaultUrl = data['defaultStreamingUrl'].toString();
            allLinks.add(StreamLink.fromJson({
              'provider': 'Blogger Default',
              'url': defaultUrl,
              'type': defaultUrl.contains('.m3u8') ? 'hls' : 'mp4',
              'quality': 'auto',
              'source': 'default',
              'priority': 0, // Highest priority
            }));
            if (kDebugMode) print('✅ Added defaultStreamingUrl: Blogger');
          }
          
          // ✅ PRIORITY 2: Add resolved_links (Pixeldrain, Krakenfiles, etc)
          if (data['resolved_links'] != null && data['resolved_links'] is List) {
            for (var linkData in data['resolved_links']) {
              final provider = linkData['provider']?.toString().toLowerCase() ?? '';
              
              // Skip download-only providers
              if (provider.contains('gofile') || 
                  provider.contains('mediafire') ||
                  provider.contains('acefile') ||
                  provider.contains('mega')) {
                continue;
              }
              
              final url = linkData['url'] ?? '';
              
              // Skip duplicates
              if (allLinks.any((l) => l.url == url)) {
                continue;
              }
              
              allLinks.add(StreamLink.fromJson({
                'provider': linkData['provider'] ?? 'Unknown',
                'url': url,
                'type': linkData['type'] ?? 'mp4',
                'quality': linkData['quality'] ?? 'auto',
                'source': linkData['source'] ?? 'resolved',
                'note': linkData['format'] != null ? '${linkData['format']}' : null,
                'priority': linkData['priority'] ?? 99,
              }));
            }
            
            if (kDebugMode) {
              print('✅ Resolved links: ${allLinks.length - 1}'); // -1 for default url
              final pixeldrain = allLinks.where((l) => l.source == 'pixeldrain').length;
              final kraken = allLinks.where((l) => l.source == 'krakenfiles').length;
              print('   💧 Pixeldrain: $pixeldrain');
              print('   🐙 Krakenfiles: $kraken');
            }
          }
          
          // ✅ PRIORITY 3: Add stream_list if available
          if (data['stream_list'] != null && data['stream_list'] is Map) {
            final streamList = data['stream_list'] as Map;
            streamList.forEach((quality, url) {
              if (url != null && url.toString().startsWith('http')) {
                final urlStr = url.toString();
                if (!allLinks.any((l) => l.url == urlStr)) {
                  allLinks.add(StreamLink.fromJson({
                    'provider': 'Stream $quality',
                    'url': urlStr,
                    'type': urlStr.contains('.m3u8') ? 'hls' : 'mp4',
                    'quality': quality.toString(),
                    'source': 'api-quality',
                    'priority': 50,
                  }));
                }
              }
            });
          }
          
          // ✅ PRIORITY 4: Add main stream_url as fallback
          if (data['stream_url'] != null) {
            final streamUrl = data['stream_url'].toString();
            if (streamUrl.isNotEmpty && !allLinks.any((l) => l.url == streamUrl)) {
              allLinks.add(StreamLink.fromJson({
                'provider': 'Main Stream',
                'url': streamUrl,
                'type': streamUrl.contains('.m3u8') ? 'hls' : 'mp4',
                'quality': 'auto',
                'source': 'api-main',
                'priority': 90,
              }));
            }
          }
          
          // ✅ Sort by priority (0 = highest)
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

  Future<Map<String, dynamic>?> getBatchDetail(String batchId) async {
    try {
      if (kDebugMode) print('\n📦 Fetching batch detail: $batchId');
      
      final response = await _safeApiCall('/batch/$batchId');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map && responseData['status'] == 'Ok') {
          return responseData['data'];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return null;
    }
  }

  Future<String?> getServerUrl(String serverId) async {
    try {
      if (kDebugMode) print('\n🎬 Fetching server URL: $serverId');
      
      final response = await _safeApiCall('/server/$serverId');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map && responseData['status'] == 'Ok') {
          return responseData['data']?['url'];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return null;
    }
  }
  Future<Map<String, dynamic>?> getEpisodeDetail(String episodeId) async {
    try {
      String cleanEpisodeId = episodeId.trim().replaceAll(RegExp(r'^/+|/+$'), '');
      
      // Handle samehadaku prefix
      if (cleanEpisodeId.startsWith('samehadaku/episode/')) {
        cleanEpisodeId = cleanEpisodeId.replaceFirst('samehadaku/episode/', '');
      }
      
      if (kDebugMode) print('🎬 SERVICE: Fetching episode detail for: $cleanEpisodeId');
      
      final response = await _safeApiCall('/episode/$cleanEpisodeId', maxRetries: 3);
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['status'] == 'Ok') {
          final data = responseData['data'];
          
          if (data != null && data is Map) {
            if (kDebugMode) {
              print('✅ SERVICE: Episode data received');
              if (data['recommendedEpisodeList'] != null) {
                final recList = data['recommendedEpisodeList'] as List;
                print('   Recommended episodes: ${recList.length}');
              }
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
}