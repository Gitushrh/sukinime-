// widgets/anime_video_player.dart - MODERN GLASS UI
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/anime_model.dart';
import 'dart:async';

class AnimeVideoPlayer extends StatefulWidget {
  final Episode episodeToLoad;
  final String animeTitle;
  final List<Episode> allEpisodes;
  final String? animePoster;
  final Function(String episodeUrl)? onEpisodeCached;

  const AnimeVideoPlayer({
    super.key,
    required this.episodeToLoad,
    required this.animeTitle,
    required this.allEpisodes,
    this.animePoster,
    this.onEpisodeCached,
  });

  @override
  State<AnimeVideoPlayer> createState() => _AnimeVideoPlayerState();
}

class _AnimeVideoPlayerState extends State<AnimeVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  StreamLink? _currentStreamLink;
  List<StreamLink> _allAvailableQualities = [];
  Episode? _currentEpisode;
  
  bool _isLoadingEpisode = true;
  bool _isLoadingPlayer = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlayerInitialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  
  int _currentPage = 0;
  static const int _episodesPerPage = 12;
  
  static const platform = MethodChannel('com.sukinime/pip');
  bool _isPiPSupported = false;
  bool _isInPiP = false;
  
  static final Map<String, List<StreamLink>> _episodeCache = {};
  
  static bool isEpisodeCached(String episodeUrl) {
    return _episodeCache.containsKey(episodeUrl);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentEpisode = widget.episodeToLoad;
    _enableWakelock();
    _checkPiPSupport();
    _setupPiPListener();
    _hideSystemUI();
    _loadEpisodeAndPlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isInPiP && state == AppLifecycleState.paused) return;
    if (state == AppLifecycleState.paused) {
      _disableWakelock();
    } else if (state == AppLifecycleState.resumed && _videoController?.value.isPlaying == true) {
      _enableWakelock();
      _hideSystemUI();
    }
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Failed to disable wakelock: $e');
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    if (_videoController?.value.isPlaying == true) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _showControls && _videoController?.value.isPlaying == true) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  Future<void> _checkPiPSupport() async {
    try {
      final bool result = await platform.invokeMethod('isPiPSupported');
      if (mounted) setState(() => _isPiPSupported = result);
    } catch (e) {}
  }

  void _setupPiPListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onPiPModeChanged') {
        final bool isInPiP = call.arguments['isInPiP'] ?? false;
        if (mounted) {
          setState(() => _isInPiP = isInPiP);
          if (isInPiP && _videoController != null && !_videoController!.value.isPlaying) {
            _videoController!.play();
            _enableWakelock();
          }
        }
      }
    });
  }

  Future<void> _enterPiP() async {
    if (!_isPiPSupported || _isInPiP) return;
    try {
      if (_videoController != null && !_videoController!.value.isPlaying) {
        await _videoController!.play();
        await _enableWakelock();
      }
      await platform.invokeMethod('enterPiP');
    } catch (e) {}
  }

  Future<void> _loadEpisodeAndPlay() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingEpisode = true;
      _hasError = false;
      _errorMessage = null;
    });

    if (_episodeCache.containsKey(_currentEpisode!.url)) {
      if (kDebugMode) print('🚀 Using cached data for: ${_currentEpisode!.url}');
      
      final cachedLinks = _episodeCache[_currentEpisode!.url]!;
      final defaultLink = _selectBestQuality(cachedLinks);
      
      if (mounted) {
        setState(() {
          _allAvailableQualities = cachedLinks;
          _currentStreamLink = defaultLink;
          _isLoadingEpisode = false;
        });
        
        await _initializePlayer();
      }
      return;
    }

    try {
      if (kDebugMode) print('🔄 Fetching: ${_currentEpisode!.url}');
      
      final response = await http.get(
        Uri.parse('https://anime-backend-tau.vercel.app/episode/${_currentEpisode!.url}')
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'Ok' && data['data'] != null) {
          final episodeData = data['data'];
          final List<StreamLink> fetchedLinks = [];

          if (episodeData['resolved_links'] != null) {
            for (var linkData in episodeData['resolved_links']) {
              fetchedLinks.add(StreamLink(
                provider: linkData['provider'] ?? 'Unknown',
                url: linkData['url'] ?? '',
                type: linkData['type'] ?? 'mp4',
                quality: linkData['quality'] ?? 'auto',
              ));
            }
          }

          final playableLinks = fetchedLinks.where((l) => l.type != 'mega').toList();

          if (playableLinks.isEmpty) {
            if (mounted) {
              setState(() {
                _isLoadingEpisode = false;
                _hasError = true;
                _errorMessage = 'No playable links available';
              });
            }
            return;
          }

          _episodeCache[_currentEpisode!.url] = playableLinks;
          if (kDebugMode) print('💾 Cached ${playableLinks.length} links for: ${_currentEpisode!.url}');
          
          widget.onEpisodeCached?.call(_currentEpisode!.url);

          final defaultLink = _selectBestQuality(playableLinks);

          if (mounted) {
            setState(() {
              _allAvailableQualities = playableLinks;
              _currentStreamLink = defaultLink;
              _isLoadingEpisode = false;
            });
            
            await _initializePlayer();
          }
        } else {
          throw Exception('Invalid response data');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Fetch error: $e');
      if (mounted) {
        setState(() {
          _isLoadingEpisode = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  StreamLink _selectBestQuality(List<StreamLink> links) {
    final bloggerDefault = links.firstWhere(
      (l) => l.provider.contains('Blogger Default'),
      orElse: () => StreamLink(provider: '', url: '', type: ''),
    );
    if (bloggerDefault.url.isNotEmpty) return bloggerDefault;

    final blogger = links.firstWhere(
      (l) => l.url.contains('blogger.com') || l.url.contains('blogspot.com'),
      orElse: () => StreamLink(provider: '', url: '', type: ''),
    );
    if (blogger.url.isNotEmpty) return blogger;

    final pixeldrain = links.firstWhere(
      (l) => l.url.contains('pixeldrain.com'),
      orElse: () => StreamLink(provider: '', url: '', type: ''),
    );
    if (pixeldrain.url.isNotEmpty) return pixeldrain;

    return links.first;
  }

  bool get hasNextEpisode {
    if (_currentEpisode == null) return false;
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    return currentIndex >= 0 && currentIndex < widget.allEpisodes.length - 1;
  }

  bool get hasPreviousEpisode {
    if (_currentEpisode == null) return false;
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    return currentIndex > 0;
  }

  void _playNextEpisode() {
    if (!hasNextEpisode) return;
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    final nextEpisode = widget.allEpisodes[currentIndex + 1];
    _switchEpisode(nextEpisode);
  }

  void _playPreviousEpisode() {
    if (!hasPreviousEpisode) return;
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    final prevEpisode = widget.allEpisodes[currentIndex - 1];
    _switchEpisode(prevEpisode);
  }

  Future<void> _switchEpisode(Episode newEpisode) async {
    _chewieController?.dispose();
    _videoController?.dispose();
    
    setState(() {
      _currentEpisode = newEpisode;
      _isPlayerInitialized = false;
      _currentStreamLink = null;
      _allAvailableQualities = [];
    });

    await _loadEpisodeAndPlay();
  }

  Future<void> _initializePlayer() async {
    if (!mounted || _currentStreamLink == null) return;
    
    setState(() {
      _isLoadingPlayer = true;
      _hasError = false;
      _isPlayerInitialized = false;
    });

    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_currentStreamLink!.url),
        httpHeaders: _getHttpHeaders(_currentStreamLink!.url),
      );
      
      await _videoController!.initialize();
      
      _videoController!.addListener(() {
        if (mounted) {
          setState(() {});
          if (_videoController!.value.isPlaying) {
            _enableWakelock();
          } else {
            _disableWakelock();
          }
        }
      });

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        aspectRatio: 16 / 9,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: false,
        showOptions: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF6366F1),
          handleColor: const Color(0xFF6366F1),
          backgroundColor: Colors.grey,
          bufferedColor: const Color(0xFF6366F1).withOpacity(0.5),
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          ),
        ),
        errorBuilder: (context, errorMessage) => _buildErrorWidget(),
      );

      if (mounted) {
        setState(() {
          _isLoadingPlayer = false;
          _isPlayerInitialized = true;
        });
        _startHideTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlayer = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        _disableWakelock();
      }
    }
  }

  Map<String, String> _getHttpHeaders(String url) {
    final urlLower = url.toLowerCase();
    if (urlLower.contains('pixeldrain.com')) {
      return {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'Accept': 'video/mp4,video/*'};
    }
    if (urlLower.contains('googlevideo.com')) {
      return {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'Referer': 'https://www.blogger.com/'};
    }
    return {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'Accept': 'video/*'};
  }

  Future<void> _changeQuality(StreamLink newLink) async {
    if (_currentStreamLink?.url == newLink.url) return;
    final currentPosition = _videoController?.value.position ?? Duration.zero;
    final wasPlaying = _videoController?.value.isPlaying ?? false;
    
    _chewieController?.dispose();
    _videoController?.dispose();
    
    if (mounted) {
      setState(() {
        _currentStreamLink = newLink;
      });
    }
    
    await _initializePlayer();
    
    if (currentPosition.inSeconds > 0 && _isPlayerInitialized && _videoController != null) {
      await _videoController!.seekTo(currentPosition);
      if (wasPlaying) {
        await _videoController!.play();
        await _enableWakelock();
      }
    }
  }

  void _showQualityBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildQualityBottomSheet(),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _extractEpisodeNumber(String title) {
    final match = RegExp(r'Episode\s*(\d+)', caseSensitive: false).firstMatch(title);
    return match?.group(1) ?? title;
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _disableWakelock();
    WidgetsBinding.instance.removeObserver(this);
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _showSystemUI();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    if (isLandscape) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: _buildLandscapePlayer()),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildPortraitPlayer(),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEpisodeInfo(),
                    _buildEpisodeList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitPlayer() {
    return Container(
      color: Colors.black,
      child: GestureDetector(
        onTap: _isPlayerInitialized && !_hasError && !_isLoadingEpisode && !_isLoadingPlayer ? _toggleControls : null,
        child: Stack(
          children: [
            if (_isPlayerInitialized && !_hasError && !_isLoadingEpisode && _chewieController != null)
              Center(child: Chewie(controller: _chewieController!)),
            if (_isLoadingEpisode || _isLoadingPlayer) _buildLoadingScreen(),
            if (_hasError) _buildErrorWidget(),
            if (_showControls && _isPlayerInitialized && !_isInPiP) _buildPortraitTopBar(),
            if (_showControls && _isPlayerInitialized && !_isInPiP && _videoController != null)
              _buildPortraitCenterControls(),
            if (_showControls && _isPlayerInitialized && !_isInPiP && _videoController != null)
              _buildPortraitBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapePlayer() {
    return GestureDetector(
      onTap: _isPlayerInitialized && !_hasError && !_isLoadingEpisode && !_isLoadingPlayer ? _toggleControls : null,
      child: Stack(
        children: [
          if (_isPlayerInitialized && !_hasError && !_isLoadingEpisode && _chewieController != null)
            Center(child: AspectRatio(aspectRatio: 16 / 9, child: Chewie(controller: _chewieController!))),
          if (_isLoadingEpisode || _isLoadingPlayer) _buildLoadingScreen(),
          if (_hasError) _buildErrorWidget(),
          if (_showControls && _isPlayerInitialized && !_isInPiP) _buildTopBar(true),
          if (_showControls && _isPlayerInitialized && !_isInPiP && _videoController != null)
            _buildCenterControls(),
          if (_showControls && _isPlayerInitialized && !_isInPiP && _videoController != null)
            _buildBottomControls(true),
        ],
      ),
    );
  }

  Widget _buildPortraitTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              iconSize: 20,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const Spacer(),
            if (hasPreviousEpisode)
              IconButton(
                onPressed: _playPreviousEpisode,
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            if (hasNextEpisode)
              IconButton(
                onPressed: _playNextEpisode,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            if (_isPiPSupported)
              IconButton(
                onPressed: _enterPiP,
                icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            if (_allAvailableQualities.length > 1)
              IconButton(
                onPressed: _showQualityBottomSheet,
                icon: const Icon(Icons.high_quality_rounded, color: Colors.white),
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitCenterControls() {
    final isPlaying = _videoController!.value.isPlaying;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.3)),
            child: IconButton(
              onPressed: () {
                final currentPosition = _videoController!.value.position;
                final newPosition = currentPosition - const Duration(seconds: 10);
                _videoController!.seekTo(newPosition);
                _startHideTimer();
              },
              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
              iconSize: 24,
              padding: const EdgeInsets.all(8),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.9),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.5), blurRadius: 15, spreadRadius: 2)],
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  if (isPlaying) {
                    _videoController!.pause();
                    _hideControlsTimer?.cancel();
                    _disableWakelock();
                  } else {
                    _videoController!.play();
                    _startHideTimer();
                    _enableWakelock();
                  }
                });
              },
              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
              iconSize: 28,
              padding: const EdgeInsets.all(10),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.3)),
            child: IconButton(
              onPressed: () {
                final currentPosition = _videoController!.value.position;
                final duration = _videoController!.value.duration;
                final newPosition = currentPosition + const Duration(seconds: 10);
                if (newPosition < duration) _videoController!.seekTo(newPosition);
                _startHideTimer();
              },
              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
              iconSize: 24,
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitBottomControls() {
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_formatDuration(position), style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: const Color(0xFF6366F1),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFF6366F1),
                      overlayColor: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        final newPosition = duration * value;
                        _videoController!.seekTo(newPosition);
                      },
                      onChangeStart: (_) => _hideControlsTimer?.cancel(),
                      onChangeEnd: (_) => _startHideTimer(),
                    ),
                  ),
                ),
                Text(_formatDuration(duration), style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      final currentVolume = _videoController!.value.volume;
                      _videoController!.setVolume(currentVolume > 0 ? 0 : 1);
                    });
                  },
                  icon: Icon(_videoController!.value.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white),
                  iconSize: 18,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  onPressed: () {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                  },
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                  iconSize: 18,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isLandscape) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              iconSize: 20,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
            const Spacer(),
            if (hasPreviousEpisode)
              IconButton(
                onPressed: _playPreviousEpisode,
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                iconSize: 22,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            if (hasNextEpisode)
              IconButton(
                onPressed: _playNextEpisode,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                iconSize: 22,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            if (_isPiPSupported)
              IconButton(
                onPressed: _enterPiP,
                icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            if (_allAvailableQualities.length > 1)
              IconButton(
                onPressed: _showQualityBottomSheet,
                icon: const Icon(Icons.high_quality_rounded, color: Colors.white),
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    final isPlaying = _videoController!.value.isPlaying;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.3)),
            child: IconButton(
              onPressed: () {
                final currentPosition = _videoController!.value.position;
                final newPosition = currentPosition - const Duration(seconds: 10);
                _videoController!.seekTo(newPosition);
                _startHideTimer();
              },
              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
              iconSize: 32,
              padding: const EdgeInsets.all(12),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.9),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.5), blurRadius: 20, spreadRadius: 2)],
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  if (isPlaying) {
                    _videoController!.pause();
                    _hideControlsTimer?.cancel();
                    _disableWakelock();
                  } else {
                    _videoController!.play();
                    _startHideTimer();
                    _enableWakelock();
                  }
                });
              },
              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
              iconSize: 36,
              padding: const EdgeInsets.all(12),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.3)),
            child: IconButton(
              onPressed: () {
                final currentPosition = _videoController!.value.position;
                final duration = _videoController!.value.duration;
                final newPosition = currentPosition + const Duration(seconds: 10);
                if (newPosition < duration) _videoController!.seekTo(newPosition);
                _startHideTimer();
              },
              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
              iconSize: 32,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool isLandscape) {
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_formatDuration(position), style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: const Color(0xFF6366F1),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFF6366F1),
                      overlayColor: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        final newPosition = duration * value;
                        _videoController!.seekTo(newPosition);
                      },
                      onChangeStart: (_) => _hideControlsTimer?.cancel(),
                      onChangeEnd: (_) => _startHideTimer(),
                    ),
                  ),
                ),
                Text(_formatDuration(duration), style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      final currentVolume = _videoController!.value.volume;
                      _videoController!.setVolume(currentVolume > 0 ? 0 : 1);
                    });
                  },
                  icon: Icon(_videoController!.value.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white),
                  iconSize: 20,
                ),
                IconButton(
                  onPressed: () {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                  },
                  icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityBottomSheet() {
    final qualityGroups = <String, List<StreamLink>>{};
    for (final link in _allAvailableQualities) {
      final quality = link.quality ?? 'auto';
      qualityGroups.putIfAbsent(quality, () => []).add(link);
    }
    final sortedQualities = qualityGroups.keys.toList()
      ..sort((a, b) {
        if (a == 'auto') return 1;
        if (b == 'auto') return -1;
        final qA = int.tryParse(a.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final qB = int.tryParse(b.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        return qB.compareTo(qA);
      });
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.98),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.high_quality_rounded,
                    color: const Color(0xFF818CF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Quality',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: Colors.white.withOpacity(0.08),
            height: 1,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              itemCount: sortedQualities.length,
              itemBuilder: (context, index) {
                final quality = sortedQualities[index];
                final links = qualityGroups[quality]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (index > 0) const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        quality.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF818CF8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...links.map((link) {
                      final isSelected = _currentStreamLink?.url == link.url;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _changeQuality(link);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6366F1).withOpacity(0.15)
                                    : const Color(0xFF0F0F0F),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : Colors.white.withOpacity(0.08),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF6366F1).withOpacity(0.2)
                                          : Colors.white.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.play_arrow_rounded,
                                      color: isSelected
                                          ? const Color(0xFF818CF8)
                                          : Colors.white54,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      link.provider,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEpisodeInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.animeTitle,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Episode ${_extractEpisodeNumber(_currentEpisode!.number)}',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
              if (_currentStreamLink?.quality != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _currentStreamLink!.quality!.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF818CF8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeList() {
    final allEpisodes = widget.allEpisodes.reversed.toList();
    final totalPages = (allEpisodes.length / _episodesPerPage).ceil();
    final startIndex = _currentPage * _episodesPerPage;
    final endIndex = (startIndex + _episodesPerPage).clamp(0, allEpisodes.length);
    final displayedEpisodes = allEpisodes.sublist(startIndex, endIndex);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Episodes',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Text(
                    '${startIndex + 1}-$endIndex of ${allEpisodes.length}',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: displayedEpisodes.length,
              itemBuilder: (context, index) {
                final episode = displayedEpisodes[index];
                final isCurrentEpisode = _currentEpisode?.url == episode.url;
                
                return Container(
                  decoration: BoxDecoration(
                    color: isCurrentEpisode 
                        ? const Color(0xFF6366F1).withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrentEpisode
                          ? const Color(0xFF6366F1)
                          : Colors.white.withOpacity(0.08),
                      width: isCurrentEpisode ? 1.5 : 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isCurrentEpisode ? null : () => _switchEpisode(episode),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isCurrentEpisode
                                    ? const Color(0xFF6366F1).withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: isCurrentEpisode
                                    ? const Color(0xFF818CF8)
                                    : Colors.white70,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${episode.episodeNumber ?? index + 1 + startIndex}',
                              style: GoogleFonts.inter(
                                color: isCurrentEpisode
                                    ? const Color(0xFF818CF8)
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (totalPages > 1) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                color: _currentPage > 0
                                    ? Colors.white
                                    : Colors.white24,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '${_currentPage + 1} / $totalPages',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _currentPage < totalPages - 1
                                ? () => setState(() => _currentPage++)
                                : null,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: _currentPage < totalPages - 1
                                    ? Colors.white
                                    : Colors.white24,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF6366F1)),
          const SizedBox(height: 16),
          Text(
            _isLoadingEpisode ? 'Loading episode...' : 'Initializing player...',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to Play Video',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadEpisodeAndPlay,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}