import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';

class AnimeService {
  final String baseUrl = 'https://anime-backend-production-8f83.up.railway.app';
  late Dio _dio;

  AnimeService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          requestHeader: true,
          responseHeader: false,
        ),
      );
    }
  }

  Future<List<Anime>> getLatestAnime() async {
    try {
      final response = await _dio.get('/api/latest');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as List;
        return data.map((e) => Anime.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) print('Error fetching latest anime: ${e.message}');
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching latest anime: $e');
      return [];
    }
  }

  Future<List<Anime>> getPopularAnime() async {
    try {
      final response = await _dio.get('/api/popular');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as List;
        return data.map((e) => Anime.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) print('Error fetching popular anime: ${e.message}');
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching popular anime: $e');
      return [];
    }
  }

  Future<List<Anime>> getOngoingAnime({int page = 1}) async {
    try {
      final response = await _dio.get('/api/ongoing', queryParameters: {'page': page});
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as List;
        return data.map((e) => Anime.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) print('Error fetching ongoing anime: ${e.message}');
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching ongoing anime: $e');
      return [];
    }
  }

  Future<AnimeDetail?> getAnimeDetail(String animeId) async {
    try {
      final response = await _dio.get('/api/anime/$animeId');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return AnimeDetail.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) print('Error fetching anime detail: ${e.message}');
      return null;
    } catch (e) {
      if (kDebugMode) print('Error fetching anime detail: $e');
      return null;
    }
  }

  Future<List<StreamLink>> getStreamingLinks(String episodeId) async {
    try {
      // Gunakan endpoint /api/episode/:episodeId
      final response = await _dio.get('/api/episode/$episodeId');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as List;
        final links = data.map((e) => StreamLink.fromJson(e)).toList();
        
        // Filter untuk mendapatkan link langsung (mp4/hls) terlebih dahulu
        final directLinks = links.where((link) => 
          link.type == 'mp4' || link.type == 'hls'
        ).toList();
        
        // Jika ada direct links, prioritaskan mereka
        if (directLinks.isNotEmpty) {
          return directLinks;
        }
        
        // Jika tidak ada, kembalikan semua link
        return links;
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) print('Error fetching streaming links: ${e.message}');
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching streaming links: $e');
      return [];
    }
  }

  Future<List<Anime>> searchAnime(String query) async {
    try {
      final response = await _dio.get('/api/search',
          queryParameters: {'q': query});
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as List;
        return data.map((e) => Anime.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) print('Error searching anime: ${e.message}');
      return [];
    } catch (e) {
      if (kDebugMode) print('Error searching anime: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      final response = await _dio.get('/api/genres');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as List;
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) print('Error fetching genres: ${e.message}');
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching genres: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSchedule() async {
    try {
      final response = await _dio.get('/api/schedule');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return {};
    } on DioException catch (e) {
      if (kDebugMode) print('Error fetching schedule: ${e.message}');
      return {};
    } catch (e) {
      if (kDebugMode) print('Error fetching schedule: $e');
      return {};
    }
  }
}