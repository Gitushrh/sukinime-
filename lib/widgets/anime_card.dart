// widgets/anime_card.dart - Enhanced Card with Better Typography
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../models/anime_model.dart';
import '../screens/detail_anime_screen.dart';

class AnimeCard extends StatefulWidget {
  final Anime anime;

  const AnimeCard({super.key, required this.anime});

  static final Map<String, String?> _posterCache = {};
  static final Map<String, int> _failureCount = {};
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://anime-backend-tau.vercel.app/',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Sukinime/2.0',
    },
  ));

  static DateTime? _lastRequestTime;
  static const _minRequestInterval = Duration(milliseconds: 800); // Increased delay
  static int _concurrentRequests = 0;
  static const _maxConcurrentRequests = 3; // Limit concurrent requests

  static void clearCache() {
    _posterCache.clear();
    _failureCount.clear();
    _lastRequestTime = null;
    if (kDebugMode) print('Cleared cache');
  }

  static Map<String, int> getCacheStats() {
    final successful = _posterCache.values.where((v) => v != null).length;
    final failed = _posterCache.values.where((v) => v == null).length;
    
    return {
      'total': _posterCache.length,
      'successful': successful,
      'failed': failed,
    };
  }

  static String _cleanPosterUrl(String url) {
    if (url.isEmpty || !url.contains('samehadaku')) return url;
    try {
      return url.replaceAll(RegExp(r'-Episode-\d+(\.[a-z]+)$'), r'$1');
    } catch (e) {
      return url;
    }
  }

  static Future<void> _waitForThrottle() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        final waitTime = _minRequestInterval - elapsed;
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  static Future<String?> _fetchPosterOnce(String animeId) async {
    if (animeId.isEmpty || animeId.trim().isEmpty) return null;

    if (_posterCache.containsKey(animeId)) {
      return _posterCache[animeId];
    }

    final failures = _failureCount[animeId] ?? 0;
    if (failures >= 2) { // Reduced from 3 to 2 attempts
      _posterCache[animeId] = null;
      return null;
    }

    // Wait if too many concurrent requests
    while (_concurrentRequests >= _maxConcurrentRequests) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      _concurrentRequests++;
      await _waitForThrottle();

      final response = await _dio.get('/anime/$animeId');
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && 
            (responseData['status'] == 'Ok' || responseData['status'] == 'success')) {
          final animeData = responseData['data'];
          String? posterUrl = animeData['poster']?.toString();
          
          if (posterUrl != null && posterUrl.isNotEmpty) {
            posterUrl = _cleanPosterUrl(posterUrl);
            
            if (posterUrl.startsWith('http') && !posterUrl.contains('placehold.co')) {
              _posterCache[animeId] = posterUrl;
              _failureCount.remove(animeId);
              return posterUrl;
            }
          }
        }
      }
      
      _failureCount[animeId] = failures + 1;
      _posterCache[animeId] = null;
      return null;
      
    } catch (e) {
      _failureCount[animeId] = failures + 1;
      _posterCache[animeId] = null;
      if (kDebugMode) print('Poster error for $animeId: $e');
      return null;
    } finally {
      _concurrentRequests--;
    }
  }

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  String? _posterUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }

  @override
  void didUpdateWidget(AnimeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anime.id != widget.anime.id) {
      _loadPoster();
    }
  }

  Future<void> _loadPoster() async {
    final animeId = widget.anime.id;
    if (animeId.isEmpty || animeId.trim().isEmpty) return;

    if (AnimeCard._posterCache.containsKey(animeId)) {
      if (mounted) {
        setState(() {
          _posterUrl = AnimeCard._posterCache[animeId];
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    final posterUrl = await AnimeCard._fetchPosterOnce(animeId);

    if (mounted) {
      setState(() {
        _posterUrl = posterUrl;
        _isLoading = false;
      });
    }
  }

  bool _isValidPoster(String? url) {
    return url != null && 
           url.isNotEmpty && 
           url.startsWith('http') &&
           !url.contains('placehold.co') &&
           !url.contains('placeholder');
  }

  @override
  Widget build(BuildContext context) {
    final hasValidPoster = _isValidPoster(_posterUrl);
    final isCached = AnimeCard._posterCache.containsKey(widget.anime.id);

    return GestureDetector(
      onTap: () {
        if (widget.anime.id.isEmpty || widget.anime.id.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid anime ID',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DetailAnimeScreen(animeId: widget.anime.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E293B),
              const Color(0xFF0F172A),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster Image
              if (hasValidPoster)
                CachedNetworkImage(
                  imageUrl: _posterUrl!,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 300),
                  placeholder: (context, url) => _buildPlaceholder(false),
                  errorWidget: (context, url, error) => _buildPlaceholder(false),
                )
              else
                _buildPlaceholder(_isLoading && !isCached),
              
              // Enhanced Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.4, 0.7, 1.0],
                  ),
                ),
              ),
              
              // Episodes Badge (top-right)
              if (widget.anime.totalEpisodes != null && 
                  widget.anime.id.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1).withOpacity(0.9),
                          const Color(0xFF818CF8).withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.video_library_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${widget.anime.totalEpisodes}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Bottom Info with Enhanced Typography
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title with better contrast
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          widget.anime.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.25,
                            letterSpacing: -0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.8),
                                offset: const Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.anime.latestEpisode != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF10B981),
                                Color(0xFF059669),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  widget.anime.latestEpisode!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool showLoading) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: showLoading
            ? SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF818CF8),
                  ),
                ),
              )
            : Icon(
                Icons.image_not_supported_rounded,
                size: 36,
                color: Colors.white.withOpacity(0.15),
              ),
      ),
    );
  }
}