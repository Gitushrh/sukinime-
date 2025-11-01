// screens/home_screen.dart - Premium Enhanced UI
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../providers/anime_provider.dart';
import '../widgets/anime_card.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late AnimationController _starController;
  late Animation<double> _fadeAnimation;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _starController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _controllersInitialized = true;
    _fadeController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnimeProvider>(context, listen: false).fetchLatestAnimes();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    if (!provider.isLoading && !provider.isLoadingMore && provider.hasMorePages) {
      provider.fetchLatestAnimes(page: provider.currentPage + 1);
    }
  }

  Future<void> _refresh() async {
    AnimeCard.clearCache();
    await Provider.of<AnimeProvider>(context, listen: false).fetchLatestAnimes();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controllersInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF818CF8),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Animated Background Stars
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _starController,
              builder: (context, child) {
                return CustomPaint(
                  painter: StarfieldPainter(_starController.value),
                );
              },
            ),
          ),

          // Main Content
          RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFF818CF8),
            backgroundColor: const Color(0xFF1A1A2E),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Enhanced App Bar
                SliverAppBar(
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFF0A0A0A),
                  elevation: 0,
                  toolbarHeight: 80,
                  flexibleSpace: Stack(
                      children: [
                        // Gradient Background
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF6366F1).withOpacity(0.12),
                                const Color(0xFF8B5CF6).withOpacity(0.08),
                                const Color(0xFF0A0A0A),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                        // Animated Gradient Orbs
                        Positioned(
                          top: -40,
                          right: -40,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF818CF8).withOpacity(0.2),
                                  const Color(0xFF6366F1).withOpacity(0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -20,
                          left: -40,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF8B5CF6).withOpacity(0.15),
                                  const Color(0xFF6366F1).withOpacity(0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Content - Aligned with AppBar
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 80, 12),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF818CF8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1).withOpacity(0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.play_circle_filled_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Sukinime',
                                          style: GoogleFonts.poppins(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.8,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Your anime universe',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF94A3B8),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      child: IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SearchScreen(),
                            ),
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.12),
                                Colors.white.withOpacity(0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        tooltip: 'Search',
                      ),
                    ),
                  ],
                ),

                // Content Section
                Consumer<AnimeProvider>(
                  builder: (context, provider, _) {
                    return SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Section Header with gradient accent
                          Container(
                            margin: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            child: Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF6366F1),
                                        Color(0xFF8B5CF6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6366F1).withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Latest Episodes',
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFF8FAFC),
                                          letterSpacing: -0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Fresh anime content',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (provider.latestAnimes.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF6366F1).withOpacity(0.2),
                                          const Color(0xFF8B5CF6).withOpacity(0.15),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF6366F1).withOpacity(0.4),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1).withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${provider.latestAnimes.length}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF818CF8),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Error Message
                          if (provider.errorMessage != null)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFEF4444).withOpacity(0.1),
                                    const Color(0xFFDC2626).withOpacity(0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFEF4444).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.warning_rounded,
                                      color: Color(0xFFEF4444),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      provider.errorMessage!,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFFCA5A5),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                // Anime Grid
                Consumer<AnimeProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading && provider.latestAnimes.isEmpty) {
                      return const SliverToBoxAdapter(child: LoadingShimmer());
                    }

                    if (provider.latestAnimes.isEmpty) {
                      return SliverFillRemaining(child: _buildEmptyState());
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 20,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= provider.latestAnimes.length) {
                              return const LoadingCard();
                            }
                            return FadeTransition(
                              opacity: _fadeAnimation,
                              child: AnimeCard(anime: provider.latestAnimes[index]),
                            );
                          },
                          childCount: provider.latestAnimes.length +
                              (provider.isLoadingMore ? 2 : 0),
                        ),
                      ),
                    );
                  },
                ),

                // Loading More Indicator
                Consumer<AnimeProvider>(
                  builder: (context, provider, _) {
                    if (!provider.isLoadingMore) return const SliverToBoxAdapter();

                    return SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF818CF8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Loading more anime...',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Bottom Padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSparkle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.4),
            Colors.transparent,
          ],
        ),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withOpacity(0.15),
                        const Color(0xFF8B5CF6).withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF334155),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.video_library_outlined,
                    size: 40,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'No anime available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFCBD5E1),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pull down to refresh',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _starController.dispose();
    super.dispose();
  }
}

// Custom Painter for Animated Starfield Background
class StarfieldPainter extends CustomPainter {
  final double animation;
  final List<Star> stars = [];

  StarfieldPainter(this.animation) {
    final random = math.Random(42);
    for (int i = 0; i < 50; i++) {
      stars.add(Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 2 + 0.5,
        speed: random.nextDouble() * 0.5 + 0.3,
        opacity: random.nextDouble() * 0.5 + 0.3,
      ));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var star in stars) {
      final twinkle = (math.sin(animation * math.pi * 2 * star.speed) + 1) / 2;
      final opacity = star.opacity * twinkle * 0.4;
      
      paint.color = const Color(0xFF818CF8).withOpacity(opacity);
      
      final x = star.x * size.width;
      final y = star.y * size.height;
      
      canvas.drawCircle(Offset(x, y), star.size, paint);
      
      // Draw cross sparkle
      if (star.size > 1.5) {
        paint.color = const Color(0xFF6366F1).withOpacity(opacity * 0.6);
        canvas.drawLine(
          Offset(x - star.size * 2, y),
          Offset(x + star.size * 2, y),
          paint..strokeWidth = 0.5,
        );
        canvas.drawLine(
          Offset(x, y - star.size * 2),
          Offset(x, y + star.size * 2),
          paint..strokeWidth = 0.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(StarfieldPainter oldDelegate) => true;
}

class Star {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}