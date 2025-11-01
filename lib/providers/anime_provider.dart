// providers/anime_provider.dart - WITH PAGINATION SUPPORT
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';
import '../services/anime_service.dart';

class AnimeProvider extends ChangeNotifier {
  final AnimeService _service = AnimeService();

  // Lists
  List<Anime> homeOngoing = [];
  List<Anime> homeComplete = [];
  List<Anime> recentAnimes = [];
  List<Anime> ongoingAnimes = [];
  List<Anime> completedAnimes = [];
  List<Anime> popularAnimes = [];
  List<Anime> movieAnimes = [];
  List<Anime> allAnimes = [];
  List<Anime> searchResults = [];
  List<Anime> genreAnimes = [];
  List<Anime> latestAnimes = [];
  
  // Status
  bool isLoading = false;
  bool isLoadingMore = false;
  bool isLoadingGenres = false;
  String? errorMessage;

  // Pagination
  int currentPage = 1;
  bool hasMorePages = true;
  int totalPages = 1;  // ✅ NEW: Track total pages

  // Current data
  AnimeDetail? currentAnime;
  List<StreamLink> currentStreamLinks = [];
  Map<String, dynamic> schedule = {};
  List<Map<String, dynamic>> genres = [];
  List<Map<String, dynamic>> batchList = [];
  Map<String, dynamic>? currentEpisodeData;

  // Search
  Timer? _searchDebounce;
  String _lastSearchQuery = '';

  // HOME
  Future<void> fetchHome() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final homeData = await _service.getHome();
      homeOngoing = homeData['ongoing'] ?? [];
      homeComplete = homeData['complete'] ?? [];
      
      if (homeOngoing.isEmpty && homeComplete.isEmpty) {
        errorMessage = 'Tidak ada data home';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchHome: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // LATEST ANIMES
  Future<void> fetchLatestAnimes({int page = 1}) async {
  if (page == 1) {
    isLoading = true;
    latestAnimes = [];
  } else {
    isLoadingMore = true;
  }
  
  errorMessage = null;
  notifyListeners();

  try {
    final animes = await _service.getRecentAnime(page: page);
    
    if (page == 1) {
      latestAnimes = animes;
    } else {
      final existingIds = latestAnimes.map((a) => a.id).toSet();
      final newAnimes = animes.where((a) => !existingIds.contains(a.id)).toList();
      latestAnimes.addAll(newAnimes);
    }
    
    currentPage = page;
    hasMorePages = animes.length >= 16; // Changed from 20 to 16
    
    if (latestAnimes.isEmpty) {
      errorMessage = 'Tidak ada anime terbaru';
    }
  } catch (e) {
    errorMessage = 'Error: $e';
    if (kDebugMode) print('❌ Error in fetchLatestAnimes: $e');
  }

  isLoading = false;
  isLoadingMore = false;
  notifyListeners();
}

  // RECENT
  Future<void> fetchRecentAnimes({int page = 1}) async {
  if (page == 1) {
    isLoading = true;
    recentAnimes = [];
  } else {
    isLoadingMore = true;
  }
  
  errorMessage = null;
  notifyListeners();

  try {
    final animes = await _service.getRecentAnime(page: page);
    
    if (page == 1) {
      recentAnimes = animes;
    } else {
      final existingIds = recentAnimes.map((a) => a.id).toSet();
      final newAnimes = animes.where((a) => !existingIds.contains(a.id)).toList();
      recentAnimes.addAll(newAnimes);
    }
    
    currentPage = page;
    hasMorePages = animes.length >= 16; // Changed from 20 to 16
    
    if (recentAnimes.isEmpty) {
      errorMessage = 'Tidak ada anime recent';
    }
  } catch (e) {
    errorMessage = 'Error: $e';
    if (kDebugMode) print('❌ Error in fetchRecentAnimes: $e');
  }

  isLoading = false;
  isLoadingMore = false;
  notifyListeners();
}
  

  // SEARCH
  void searchAnimesDebounced(String query) {
    _searchDebounce?.cancel();
    
    if (query.trim().isEmpty) {
      searchResults = [];
      _lastSearchQuery = '';
      notifyListeners();
      return;
    }
    
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      searchAnimes(query);
    });
  }

  Future<void> searchAnimes(String query, {int page = 1}) async {
  if (page == 1) {
    isLoading = true;
    searchResults = [];
  } else {
    isLoadingMore = true;
  }
  
  errorMessage = null;
  _lastSearchQuery = query;
  notifyListeners();

  try {
    final animes = await _service.searchAnime(query, page: page);
    
    if (page == 1) {
      searchResults = animes;
    } else {
      final existingIds = searchResults.map((a) => a.id).toSet();
      final newAnimes = animes.where((a) => !existingIds.contains(a.id)).toList();
      searchResults.addAll(newAnimes);
    }
    
    currentPage = page;
    hasMorePages = animes.length >= 16; // Changed from 20 to 16
    
    if (searchResults.isEmpty) {
      errorMessage = 'Anime "$query" tidak ditemukan';
    }
  } catch (e) {
    errorMessage = 'Error: $e';
    if (kDebugMode) print('❌ Error in searchAnimes: $e');
  }

  isLoading = false;
  isLoadingMore = false;
  notifyListeners();
}

  // ONGOING
  Future<void> fetchOngoingAnimes({int page = 1, String order = 'popular'}) async {
  if (page == 1) {
    isLoading = true;
    ongoingAnimes = [];
  } else {
    isLoadingMore = true;
  }
  
  errorMessage = null;
  notifyListeners();

  try {
    final animes = await _service.getOngoingAnime(page: page, order: order);
    
    if (page == 1) {
      ongoingAnimes = animes;
    } else {
      final existingIds = ongoingAnimes.map((a) => a.id).toSet();
      final newAnimes = animes.where((a) => !existingIds.contains(a.id)).toList();
      ongoingAnimes.addAll(newAnimes);
    }
    
    currentPage = page;
    hasMorePages = animes.length >= 16; // Changed from 20 to 16
    
    if (ongoingAnimes.isEmpty) {
      errorMessage = 'Tidak ada anime ongoing';
    }
  } catch (e) {
    errorMessage = 'Error: $e';
    if (kDebugMode) print('❌ Error in fetchOngoingAnimes: $e');
  }

  isLoading = false;
  isLoadingMore = false;
  notifyListeners();
}

  // COMPLETED
  Future<void> fetchCompletedAnimes({int page = 1, String order = 'latest'}) async {
  if (page == 1) {
    isLoading = true;
    completedAnimes = [];
  } else {
    isLoadingMore = true;
  }
  
  errorMessage = null;
  notifyListeners();

  try {
    final animes = await _service.getCompletedAnime(page: page, order: order);
    
    if (page == 1) {
      completedAnimes = animes;
    } else {
      final existingIds = completedAnimes.map((a) => a.id).toSet();
      final newAnimes = animes.where((a) => !existingIds.contains(a.id)).toList();
      completedAnimes.addAll(newAnimes);
    }
    
    currentPage = page;
    hasMorePages = animes.length >= 16; // Changed from 20 to 16
    
    if (completedAnimes.isEmpty) {
      errorMessage = 'Tidak ada anime completed';
    }
  } catch (e) {
    errorMessage = 'Error: $e';
    if (kDebugMode) print('❌ Error in fetchCompletedAnimes: $e');
  }

  isLoading = false;
  isLoadingMore = false;
  notifyListeners();
}

  // POPULAR
  Future<void> fetchPopularAnimes({int page = 1}) async {
  if (page == 1) {
    isLoading = true;
    popularAnimes = [];
  } else {
    isLoadingMore = true;
  }
  
  errorMessage = null;
  notifyListeners();

  try {
    final animes = await _service.getPopularAnime(page: page);
    
    if (page == 1) {
      popularAnimes = animes;
    } else {
      final existingIds = popularAnimes.map((a) => a.id).toSet();
      final newAnimes = animes.where((a) => !existingIds.contains(a.id)).toList();
      popularAnimes.addAll(newAnimes);
    }
    
    currentPage = page;
    hasMorePages = animes.length >= 16; // Changed from 20 to 16
    
    if (popularAnimes.isEmpty) {
      errorMessage = 'Tidak ada anime popular';
    }
  } catch (e) {
    errorMessage = 'Error: $e';
    if (kDebugMode) print('❌ Error in fetchPopularAnimes: $e');
  }

  isLoading = false;
  isLoadingMore = false;
  notifyListeners();
}

  // MOVIES
  Future<void> fetchMovies({int page = 1, String order = 'update'}) async {
  if (page == 1) {
    isLoading = true;
    movieAnimes = [];
  } else {
    isLoadingMore = true;
  }
  
  errorMessage = null;
  notifyListeners();

  try {
    final animes = await _service.getMovies(page: page, order: order);
    
    if (page == 1) {
      movieAnimes = animes;
    } else {
      final existingIds = movieAnimes.map((a) => a.id).toSet();
      final newAnimes = animes.where((a) => !existingIds.contains(a.id)).toList();
      movieAnimes.addAll(newAnimes);
    }
    
    currentPage = page;
    hasMorePages = animes.length >= 16; // Changed from 20 to 16
    
    if (movieAnimes.isEmpty) {
      errorMessage = 'Tidak ada movie';
    }
  } catch (e) {
    errorMessage = 'Error: $e';
    if (kDebugMode) print('❌ Error in fetchMovies: $e');
  }

  isLoading = false;
  isLoadingMore = false;
  notifyListeners();
}

  // ALL ANIME LIST
  Future<void> fetchAllAnimes({int page = 1, String? query}) async {
  if (page == 1) {
    isLoading = true;
    allAnimes = [];
  } else {
    isLoadingMore = true;
  }
  
  errorMessage = null;
  notifyListeners();

  try {
    List<Anime> animes;
    
    if (query != null && query.trim().isNotEmpty) {
      animes = await _service.searchAnime(query, page: page);
    } else {
      if (page == 1) {
        animes = await _service.getAllAnimeList();
      } else {
        animes = [];
      }
    }
    
    if (page == 1) {
      allAnimes = animes;
    } else {
      final existingIds = allAnimes.map((a) => a.id).toSet();
      final newAnimes = animes.where((a) => !existingIds.contains(a.id)).toList();
      allAnimes.addAll(newAnimes);
    }
    
    currentPage = page;
    hasMorePages = animes.length >= 16; // Changed from 20 to 16
    
    if (allAnimes.isEmpty) {
      errorMessage = query != null 
          ? 'Anime "$query" tidak ditemukan' 
          : 'Tidak ada data anime';
    }
  } catch (e) {
    errorMessage = 'Error: $e';
    if (kDebugMode) print('❌ Error in fetchAllAnimes: $e');
  }

  isLoading = false;
  isLoadingMore = false;
  notifyListeners();
}

  // SCHEDULE
  Future<void> fetchSchedule() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      schedule = await _service.getSchedule();
      
      if (schedule.isEmpty) {
        errorMessage = 'Jadwal tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchSchedule: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // GENRES
  Future<void> fetchGenres() async {
    isLoadingGenres = true;
    errorMessage = null;
    notifyListeners();

    try {
      genres = await _service.getGenres();
      
      if (genres.isEmpty) {
        errorMessage = 'Genre tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchGenres: $e');
    }

    isLoadingGenres = false;
    notifyListeners();
  }

  // ✅ IMPROVED: Anime by Genre with Pagination Support
  Future<void> fetchAnimeByGenre(String genreId, {int page = 1}) async {
    if (page == 1) {
      isLoading = true;
      genreAnimes = [];
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }
    
    errorMessage = null;
    notifyListeners();

    try {
      // ✅ Use new method that returns pagination info
      final result = await _service.getAnimeByGenreWithPagination(genreId, page: page);
      
      final animes = result['animes'] as List<Anime>;
      final pagination = result['pagination'] as Map<String, dynamic>;
      
      // ✅ Update pagination state
      currentPage = pagination['currentPage'] ?? page;
      hasMorePages = pagination['hasNextPage'] ?? false;
      totalPages = pagination['totalPages'] ?? 1;
      
      if (kDebugMode) {
        print('📄 Provider pagination state:');
        print('   Current: $currentPage/$totalPages');
        print('   Has more: $hasMorePages');
        print('   Anime count: ${animes.length}');
      }
      
      if (page == 1) {
        genreAnimes = animes;
      } else {
        final existingIds = genreAnimes.map((a) => a.id).toSet();
        final newAnimes = animes.where((a) => !existingIds.contains(a.id)).toList();
        genreAnimes.addAll(newAnimes);
      }
      
      if (genreAnimes.isEmpty) {
        errorMessage = 'Anime genre tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchAnimeByGenre: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // BATCH
  Future<void> fetchBatchList({int page = 1}) async {
  if (page == 1) {
    isLoading = true;
    batchList = [];
  } else {
    isLoadingMore = true;
  }
  
  errorMessage = null;
  notifyListeners();

  try {
    final batches = await _service.getBatchList(page: page);
    
    if (page == 1) {
      batchList = batches;
    } else {
      batchList.addAll(batches);
    }
    
    currentPage = page;
    hasMorePages = batches.length >= 16; // Changed from 20 to 16
    
    if (batchList.isEmpty) {
      errorMessage = 'Tidak ada batch';
    }
  } catch (e) {
    errorMessage = 'Error: $e';
    if (kDebugMode) print('❌ Error in fetchBatchList: $e');
  }

  isLoading = false;
  isLoadingMore = false;
  notifyListeners();
}
  // ANIME DETAIL
  Future<void> fetchAnimeDetail(String animeId) async {
    isLoading = true;
    errorMessage = null;
    currentAnime = null;
    notifyListeners();

    try {
      if (kDebugMode) print('🔍 PROVIDER: Fetching anime detail for $animeId');
      
      currentAnime = await _service.getAnimeDetail(animeId);
      
      if (currentAnime == null) {
        errorMessage = 'Anime tidak ditemukan';
        if (kDebugMode) print('❌ PROVIDER: currentAnime is null');
      } else {
        if (kDebugMode) {
          print('✅ PROVIDER: Anime loaded successfully');
          print('   Title: ${currentAnime!.title}');
          print('   Episodes count: ${currentAnime!.episodes.length}');
        }
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ PROVIDER Error in fetchAnimeDetail: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // STREAMING LINKS
   Future<void> fetchStreamingLinks(String episodeId) async {
    currentStreamLinks = [];
    currentEpisodeData = null; // ✅ Reset episode data
    errorMessage = null;
    
    try {
      if (kDebugMode) print('🔥 PROVIDER: Requesting streaming for $episodeId');
      
      // ✅ Get full episode data from service
      final episodeData = await _service.getEpisodeDetail(episodeId);
      
      if (episodeData != null) {
        currentEpisodeData = episodeData;
        
        // ✅ Extract streaming links from episode data
        if (episodeData['resolved_links'] != null) {
          final links = episodeData['resolved_links'] as List;
          currentStreamLinks = links.map((l) => StreamLink.fromJson(l)).toList();
        }
        
        if (kDebugMode) {
          print('✅ PROVIDER: Got ${currentStreamLinks.length} links');
          if (episodeData['recommendedEpisodeList'] != null) {
            final recList = episodeData['recommendedEpisodeList'] as List;
            print('✅ PROVIDER: Got ${recList.length} recommended episodes');
          }
        }
      }
      
      if (currentStreamLinks.isEmpty) {
        errorMessage = 'Streaming link tidak ditemukan';
        if (kDebugMode) print('⚠️ No streaming links found: $episodeId');
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchStreamingLinks: $e');
    }
    
    notifyListeners();
  }

  // BATCH DETAIL
  Future<Map<String, dynamic>?> fetchBatchDetail(String batchId) async {
    try {
      final batchDetail = await _service.getBatchDetail(batchId);
      return batchDetail;
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchBatchDetail: $e');
      return null;
    }
  }

  // SERVER URL
  Future<String?> fetchServerUrl(String serverId) async {
    try {
      final url = await _service.getServerUrl(serverId);
      return url;
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchServerUrl: $e');
      return null;
    }
  }

  // HELPERS
  String get lastSearchQuery => _lastSearchQuery;

  void clearSearchResults() {
  searchResults = [];
  _lastSearchQuery = '';
  errorMessage = null;
  currentPage = 1;
  hasMorePages = true;
  notifyListeners();
}

  void reset() {
    _searchDebounce?.cancel();
    homeOngoing = [];
    homeComplete = [];
    recentAnimes = [];
    ongoingAnimes = [];
    completedAnimes = [];
    popularAnimes = [];
    movieAnimes = [];
    allAnimes = [];
    searchResults = [];
    genreAnimes = [];
    latestAnimes = [];
    currentAnime = null;
    currentStreamLinks = [];
    schedule = {};
    genres = [];
    batchList = [];
    errorMessage = null;
    _lastSearchQuery = '';
    hasMorePages = true;
    currentPage = 1;
    totalPages = 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}