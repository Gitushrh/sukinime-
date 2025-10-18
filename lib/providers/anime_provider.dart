import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';
import '../services/anime_service.dart';

class AnimeProvider extends ChangeNotifier {
  final AnimeService _service = AnimeService();

  List<Anime> latestAnimes = [];
  List<Anime> popularAnimes = [];
  List<Anime> ongoingAnimes = [];
  AnimeDetail? currentAnime;
  List<StreamLink> currentStreamLinks = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchLatestAnimes() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      latestAnimes = await _service.getLatestAnime();
      if (latestAnimes.isEmpty) {
        errorMessage = 'Tidak ada anime terbaru ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPopularAnimes() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      popularAnimes = await _service.getPopularAnime();
      if (popularAnimes.isEmpty) {
        errorMessage = 'Tidak ada anime populer ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchOngoingAnimes() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      ongoingAnimes = await _service.getOngoingAnime();
      if (ongoingAnimes.isEmpty) {
        errorMessage = 'Tidak ada anime ongoing ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAnimeDetail(String animeId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentAnime = await _service.getAnimeDetail(animeId);
      if (currentAnime == null) {
        errorMessage = 'Anime tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchStreamingLinks(String episodeId) async {
    try {
      currentStreamLinks = await _service.getStreamingLinks(episodeId);
      if (currentStreamLinks.isEmpty) {
        errorMessage = 'Streaming link tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
    }
    notifyListeners();
  }

  Future<void> searchAnimes(String query) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      latestAnimes = await _service.searchAnime(query);
      if (latestAnimes.isEmpty) {
        errorMessage = 'Anime "$query" tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  void reset() {
    latestAnimes = [];
    popularAnimes = [];
    ongoingAnimes = [];
    currentAnime = null;
    currentStreamLinks = [];
    errorMessage = null;
    notifyListeners();
  }
}