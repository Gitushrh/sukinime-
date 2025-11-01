import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pod_player/pod_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../models/anime_model.dart';

class AnimeVideoPlayer extends StatefulWidget {
  final StreamLink streamLink;
  final String episodeTitle;

  const AnimeVideoPlayer({
    super.key,
    required this.streamLink,
    required this.episodeTitle,
  });

  @override
  State<AnimeVideoPlayer> createState() => _AnimeVideoPlayerState();
}

class _AnimeVideoPlayerState extends State<AnimeVideoPlayer> {
  late PodPlayerController _controller;
  bool _isPlayerReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _initializePlayer() {
    try {
      final httpHeaders = _getHttpHeaders();

      _controller = PodPlayerController(
        playVideoFrom: PlayVideoFrom.network(
          widget.streamLink.url,
          httpHeaders: httpHeaders,
        ),
        podPlayerConfig: PodPlayerConfig(
          autoPlay: true,
          isLooping: false,
          videoQualityPriority: [720, 480, 360, 240],
          forcedVideoFocus: true,
          wakelockEnabled: true,
        ),
      )..initialise().then((_) {
          if (mounted) {
            setState(() {
              _isPlayerReady = true;
            });
          }
        }).catchError((error) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Error loading video: ${error.toString()}';
            });
          }
        });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing player: ${e.toString()}';
      });
    }
  }

  Map<String, String> _getHttpHeaders() {
    final url = widget.streamLink.url.toLowerCase();
    
    if (url.contains('googlevideo.com') || url.contains('blogger.com')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://www.blogger.com/',
        'Origin': 'https://www.blogger.com',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Sec-Fetch-Dest': 'video',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site',
      };
    }
    
    if (url.contains('streamtape')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://streamtape.com/',
        'Accept': '*/*',
      };
    }
    
    if (url.contains('mp4upload')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://mp4upload.com/',
        'Accept': '*/*',
      };
    }
    
    if (url.contains('acefile')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://acefile.co/',
        'Accept': '*/*',
      };
    }
    
    if (url.contains('filelions')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://filelions.com/',
        'Accept': '*/*',
      };
    }
    
    if (url.contains('vidguard')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://vidguard.to/',
        'Accept': '*/*',
      };
    }
    
    if (url.contains('streamwish') || url.contains('wish')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://streamwish.to/',
        'Accept': '*/*',
      };
    }
    
    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://otakudesu.cloud/',
      'Accept': '*/*',
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _errorMessage != null
            ? _buildErrorWidget()
            : _isPlayerReady
                ? Column(
                    children: [
                      Expanded(
                        child: PodVideoPlayer(
                          controller: _controller,
                          frameAspectRatio: 16 / 9,
                          videoAspectRatio: 16 / 9,
                          alwaysShowProgressBar: true,
                          matchVideoAspectRatioToFrame: true,
                          matchFrameAspectRatioToVideo: true,
                        ),
                      ),
                      _buildVideoInfo(),
                    ],
                  )
                : _buildLoadingWidget(),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0a0e27),
            const Color(0xFF1a1f3a),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/loading.json',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 32),
            Text(
              'Memuat Video',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.episodeTitle,
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0a0e27),
            const Color(0xFF1a1f3a),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Gagal Memutar Video',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage ?? 'Terjadi kesalahan yang tidak diketahui',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        _isPlayerReady = false;
                      });
                      _initializePlayer();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      'Coba Lagi',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      'Kembali',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                      side: BorderSide(
                        color: Colors.grey[600]!,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.deepPurple,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.streamLink.type == 'hls'
                          ? Icons.stream
                          : Icons.play_circle,
                      color: Colors.deepPurple[200],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.streamLink.type.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.deepPurple[200],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_isPlayerReady)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'AUTO',
                    style: GoogleFonts.poppins(
                      color: Colors.green[200],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.streamLink.provider,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.episodeTitle,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Kembali'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[400],
                ),
              ),
              if (_isPlayerReady)
                Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '1.0x',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}