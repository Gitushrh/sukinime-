// services/poster_loader_service.dart - FIXED: URL CLEANING + CACHING
// ✅ Uses the same endpoint as detail_anime_screen.dart: /anime/:animeId
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PosterLoaderService {
  final String baseUrl = 'https://anime-backend-tau.vercel.app/';
  late Dio _dio;
  
  // Memory cache
  final Map<String, String?> _posterCache = {};
  
  // Queue to batch requests
  final List<String> _queue = [];
  bool _isProcessing = false;
  
  // Cache expiry (24 hours)
  static const int _cacheExpiryHours = 24;
  static const String _cacheKey = 'poster_cache_v1';
  static const String _cacheTimeKey = 'poster_cache_time_v1';

  PosterLoaderService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Sukinime/2.0',
      },
      validateStatus: (status) => status != null && status < 500,
    ));
    
    // Load cache from storage
    _loadCacheFromStorage();
  }

  /// ✅ FIX: Clean poster URL by removing -Episode-X suffix
  String _cleanPosterUrl(String url) {
    if (url.isEmpty || !url.contains('samehadaku')) return url;
    
    try {
      // Pattern: -Episode-123.jpg → .jpg
      final cleaned = url.replaceAll(RegExp(r'-Episode-\d+(\.[a-z]+)$'), r'$1');
      
      if (cleaned != url && kDebugMode) {
        print('🧹 Cleaned URL:');
        print('   Before: ${url.substring(url.lastIndexOf('/') + 1)}');
        print('   After: ${cleaned.substring(cleaned.lastIndexOf('/') + 1)}');
      }
      
      return cleaned;
    } catch (e) {
      if (kDebugMode) print('⚠️ Error cleaning URL: $e');
      return url;
    }
  }

  /// Load cache from SharedPreferences
  Future<void> _loadCacheFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      final cacheTime = prefs.getInt(_cacheTimeKey);
      
      if (cacheJson != null && cacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final age = now - cacheTime;
        final ageHours = age / (1000 * 60 * 60);
        
        if (ageHours < _cacheExpiryHours) {
          final Map<String, dynamic> decoded = json.decode(cacheJson);
          _posterCache.addAll(decoded.map((k, v) => MapEntry(k, v as String?)));
          
          if (kDebugMode) {
            print('✅ Loaded ${_posterCache.length} posters from cache');
            print('   Age: ${ageHours.toStringAsFixed(1)} hours');
          }
        } else {
          if (kDebugMode) print('⚠️ Cache expired (${ageHours.toStringAsFixed(1)} hours old)');
          await _clearStorageCache();
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Error loading cache: $e');
    }
  }

  /// Save cache to SharedPreferences
  Future<void> _saveCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = json.encode(_posterCache);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setString(_cacheKey, cacheJson);
      await prefs.setInt(_cacheTimeKey, now);
      
      if (kDebugMode) print('💾 Saved ${_posterCache.length} posters to cache');
    } catch (e) {
      if (kDebugMode) print('⚠️ Error saving cache: $e');
    }
  }

  /// Clear storage cache
  Future<void> _clearStorageCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimeKey);
      if (kDebugMode) print('🧹 Storage cache cleared');
    } catch (e) {
      if (kDebugMode) print('⚠️ Error clearing cache: $e');
    }
  }

  Future<String?> getPosterUrl(String animeId) async {
    // Validation
    if (animeId.isEmpty || animeId.trim().isEmpty) {
      if (kDebugMode) print('⚠️ Empty animeId');
      return null;
    }
    
    // Check memory cache
    if (_posterCache.containsKey(animeId)) {
      if (kDebugMode) print('✅ Cache hit: $animeId');
      return _posterCache[animeId];
    }
    
    // Add to queue
    if (!_queue.contains(animeId)) {
      _queue.add(animeId);
    }
    
    // Start processing
    if (!_isProcessing) {
      _processQueue();
    }
    
    // Wait for result (max 5 seconds)
    int retries = 0;
    while (!_posterCache.containsKey(animeId) && retries < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
    
    return _posterCache[animeId];
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    
    if (kDebugMode) print('🎬 Processing ${_queue.length} poster requests');
    
    int successCount = 0;
    
    while (_queue.isNotEmpty) {
      final animeId = _queue.removeAt(0);
      
      if (_posterCache.containsKey(animeId)) continue;
      if (animeId.isEmpty || animeId.trim().isEmpty) {
        _posterCache[animeId] = null;
        continue;
      }
      
      try {
        // ✅ FETCH FROM DETAIL ANIME ENDPOINT (detail_anime_screen.dart uses this)
        final response = await _dio.get('/anime/$animeId');
        
        if (response.statusCode == 200) {
          final responseData = response.data;
          
          if (responseData is Map && 
              (responseData['status'] == 'Ok' || responseData['status'] == 'success')) {
            final animeData = responseData['data'];
            
            // ✅ Try to get poster from detail endpoint
            String? posterUrl = animeData['poster']?.toString();
            
            // ✅ CLEAN THE URL (remove -Episode-X suffix)
            if (posterUrl != null && posterUrl.isNotEmpty) {
              posterUrl = _cleanPosterUrl(posterUrl);
              
              // Validate URL
              if (posterUrl.startsWith('http') && 
                  !posterUrl.contains('placehold.co')) {
                _posterCache[animeId] = posterUrl;
                successCount++;
                
                if (kDebugMode) {
                  final filename = posterUrl.split('/').last;
                  print('✅ Poster loaded: $animeId');
                  print('   URL: .../${filename}');
                }
              } else {
                if (kDebugMode) print('⚠️ Invalid poster URL for $animeId');
                _posterCache[animeId] = null;
              }
            } else {
              if (kDebugMode) print('⚠️ No poster field for $animeId');
              _posterCache[animeId] = null;
            }
          } else {
            if (kDebugMode) print('⚠️ Invalid response status for $animeId');
            _posterCache[animeId] = null;
          }
        } else {
          if (kDebugMode) print('⚠️ HTTP ${response.statusCode} for $animeId');
          _posterCache[animeId] = null;
        }
      } on DioException catch (e) {
        _posterCache[animeId] = null;
        if (kDebugMode) {
          if (e.response?.statusCode == 404) {
            print('⚠️ Anime not found: $animeId');
          } else if (e.response?.statusCode != null) {
            print('⚠️ HTTP ${e.response?.statusCode} for $animeId');
          } else {
            print('⚠️ Network error for $animeId: ${e.type}');
          }
        }
      } catch (e) {
        _posterCache[animeId] = null;
        if (kDebugMode) print('⚠️ Unexpected error for $animeId: ${e.toString().substring(0, 100)}');
      }
      
      // Small delay to avoid overwhelming server
      await Future.delayed(const Duration(milliseconds: 250));
    }
    
    // Save to storage after processing
    if (successCount > 0) {
      await _saveCacheToStorage();
    }
    
    if (kDebugMode) {
      print('\n📊 Poster Loading Summary:');
      print('   ✅ Successful: $successCount');
      print('   ❌ Failed: ${_posterCache.length - successCount}');
      print('   💾 Total Cached: ${_posterCache.length}');
      print('   📦 Storage Saved: ${successCount > 0 ? 'Yes' : 'No'}\n');
    }
    
    _isProcessing = false;
  }

  /// Get cache stats
  Map<String, int> getCacheStats() {
    final successful = _posterCache.values.where((v) => v != null).length;
    final failed = _posterCache.values.where((v) => v == null).length;
    
    return {
      'total': _posterCache.length,
      'successful': successful,
      'failed': failed,
      'queued': _queue.length,
    };
  }

  /// Clear all caches
  Future<void> clearCache() async {
    _posterCache.clear();
    _queue.clear();
    await _clearStorageCache();
    if (kDebugMode) print('🧹 All caches cleared');
  }

  /// Force refresh cache (clear and reload)
  Future<void> refreshCache() async {
    await clearCache();
    if (kDebugMode) print('🔄 Cache refreshed');
  }

  int get cacheSize => _posterCache.length;
  bool get isProcessing => _isProcessing;
  int get queueLength => _queue.length;
}