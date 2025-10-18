import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:better_player/better_player.dart';
import 'services/api_service.dart';
import 'config/app_config.dart';

void main() {
  // Print setup instructions in debug mode
  if (AppConfig.isDebugMode) {
    AppConfig.printInfo('Starting AnimeHub Flutter App');
    AppConfig.printInfo('Backend URL: ${AppConfig.API_BASE_URL}');
    print('\n' + '='*50);
    RailwaySetupInstructions.printInstructions();
    print('='*50 + '\n');
  }
  
  runApp(const AnimeApp());
}

// Note: API URLs are now managed in services/api_service.dart

class AnimeApp extends StatelessWidget {
  const AnimeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.APP_NAME,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(AppConfig.PRIMARY_COLOR),
        scaffoldBackgroundColor: Color(AppConfig.BACKGROUND_COLOR),
        cardColor: Color(AppConfig.CARD_COLOR),
        colorScheme: ColorScheme.dark(
          primary: Color(AppConfig.PRIMARY_COLOR),
          secondary: Color(AppConfig.SECONDARY_COLOR),
          surface: Color(AppConfig.CARD_COLOR),
          background: Color(AppConfig.BACKGROUND_COLOR),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A2B44),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const OngoingAnimePage(),
    const SearchAnimePage(),
    const HomeAnimePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A4E69), Color(0xFFF72585)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4A4E69).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Text('🎬', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Color(0xFF4A4E69), Color(0xFFF72585)],
              ).createShader(bounds),
              child: const Text(
                'AnimeHub',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 26),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2B44),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFFF72585),
          unselectedItemColor: Colors.grey[400],
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 13,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline, size: 28),
              activeIcon: Icon(Icons.play_circle, size: 28),
              label: 'Ongoing',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined, size: 28),
              activeIcon: Icon(Icons.search, size: 28),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 28),
              activeIcon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeAnimePage extends StatefulWidget {
  const HomeAnimePage({Key? key}) : super(key: key);

  @override
  State<HomeAnimePage> createState() => _HomeAnimePageState();
}

class _HomeAnimePageState extends State<HomeAnimePage> {
  Map<String, dynamic>? homeData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHomeData();
  }

  Future<void> fetchHomeData() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.fetchHomeData();
      setState(() {
        homeData = data['data'];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading home data: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF72585)),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchHomeData,
      color: const Color(0xFFF72585),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A4E69), Color(0xFFF72585)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF4A4E69).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Discover the latest anime',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.95),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.movie_filter, color: Colors.white, size: 42),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.whatshot, color: Color(0xFFF72585), size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Ongoing Anime',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OngoingAnimePage()),
                  );
                },
                child: const Text(
                  'See All',
                  style: TextStyle(
                    color: Color(0xFFF72585),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 290,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: (homeData?['ongoing_anime'] as List?)?.length ?? 0,
              itemBuilder: (context, index) {
                final anime = homeData!['ongoing_anime'][index];
                return AnimeCardHorizontal(anime: anime);
              },
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF00D2A0), size: 28),
              SizedBox(width: 12),
              Text(
                'Complete Anime',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(homeData?['complete_anime'] as List? ?? []).map((anime) => 
            AnimeListTile(anime: anime)
          ).toList(),
        ],
      ),
    );
  }
}

class OngoingAnimePage extends StatefulWidget {
  const OngoingAnimePage({Key? key}) : super(key: key);

  @override
  State<OngoingAnimePage> createState() => _OngoingAnimePageState();
}

class _OngoingAnimePageState extends State<OngoingAnimePage> {
  List<dynamic> animeList = [];
  bool isLoading = true;
  int currentPage = 1;

  @override
  void initState() {
    super.initState();
    fetchOngoingAnime();
  }

  Future<void> fetchOngoingAnime() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.fetchOngoingAnime(page: currentPage);
      setState(() {
        animeList = data['data']['ongoingAnimeData'] ?? data['data'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading ongoing anime: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF72585)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ongoing Anime'),
      ),
      body: RefreshIndicator(
        onRefresh: fetchOngoingAnime,
        color: const Color(0xFFF72585),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: animeList.length,
          itemBuilder: (context, index) {
            final anime = animeList[index];
            return AnimeCard(anime: anime);
          },
        ),
      ),
    );
  }
}

class SearchAnimePage extends StatefulWidget {
  const SearchAnimePage({Key? key}) : super(key: key);

  @override
  State<SearchAnimePage> createState() => _SearchAnimePageState();
}

class _SearchAnimePageState extends State<SearchAnimePage> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> searchResults = [];
  bool isLoading = false;

  Future<void> searchAnime(String keyword) async {
    if (keyword.isEmpty) return;
    
    setState(() => isLoading = true);
    try {
      final data = await ApiService.searchAnime(keyword);
      setState(() {
        searchResults = data['search_results'] ?? data['data'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search error: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2B44),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search your favorite anime...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFF72585)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Color(0xFFF72585)),
                onPressed: () => searchAnime(_controller.text),
              ),
              filled: true,
              fillColor: const Color(0xFF3A3B5B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: searchAnime,
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF72585)))
              : searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 100, color: Colors.grey[600]),
                          const SizedBox(height: 20),
                          Text(
                            'Search for your favorite anime!',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final anime = searchResults[index];
                        return AnimeListTile(anime: anime);
                      },
                    ),
        ),
      ],
    );
  }
}

class AnimeCard extends StatelessWidget {
  final dynamic anime;

  const AnimeCard({Key? key, required this.anime}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnimeDetailPage(
              slug: anime['slug'] ?? '',
              title: anime['title'] ?? '',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF2A2B44),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: anime['poster'] ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[700]!,
                        highlightColor: Colors.grey[600]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.movie, size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF72585), Color(0xFFFF8F6B)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFF72585).withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        anime['current_episode'] ?? anime['episode_count'] ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.play_circle_fill, color: Color(0xFFF72585), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          anime['current_episode'] ?? anime['episode_count'] ?? '',
                          style: const TextStyle(
                            color: Color(0xFFF72585),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimeCardHorizontal extends StatelessWidget {
  final dynamic anime;

  const AnimeCardHorizontal({Key? key, required this.anime}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnimeDetailPage(
              slug: anime['slug'] ?? '',
              title: anime['title'] ?? '',
            ),
          ),
        );
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF2A2B44),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: CachedNetworkImage(
                      imageUrl: anime['poster'] ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[700]!,
                        highlightColor: Colors.grey[600]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.movie, size: 40),
                      ),
                    ),
                  ),
                  if (anime['current_episode'] != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFF72585), Color(0xFFFF8F6B)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFF72585).withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (anime['current_episode'] != null)
                    Text(
                      anime['current_episode'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF72585),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimeListTile extends StatelessWidget {
  final dynamic anime;

  const AnimeListTile({Key? key, required this.anime}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2B44),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[700]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: anime['poster'] ?? '',
            width: 60,
            height: 80,
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey[700]!,
              highlightColor: Colors.grey[600]!,
              child: Container(color: Colors.white),
            ),
            errorWidget: (context, error, stackTrace) => Container(
              width: 60,
              height: 80,
              color: Colors.grey[800],
              child: const Icon(Icons.movie, size: 30),
            ),
          ),
        ),
        title: Text(
          anime['title'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              if (anime['rating'] != null) ...[
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text(
                  anime['rating'],
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (anime['current_episode'] != null)
                Text(
                  anime['current_episode'],
                  style: const TextStyle(
                    color: Color(0xFFF72585),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFFF72585)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnimeDetailPage(
                slug: anime['slug'] ?? '',
                title: anime['title'] ?? '',
              ),
            ),
          );
        },
      ),
    );
  }
}

class AnimeDetailPage extends StatefulWidget {
  final String slug;
  final String title;

  const AnimeDetailPage({Key? key, required this.slug, required this.title})
      : super(key: key);

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  Map<String, dynamic>? animeDetail;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAnimeDetail();
  }

  Future<void> fetchAnimeDetail() async {
    try {
      final data = await ApiService.fetchAnimeDetail(widget.slug);
      setState(() {
        animeDetail = data['data'];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading anime details: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF22223B),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF72585)))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  backgroundColor: const Color(0xFF2A2B44),
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: animeDetail?['poster'] ?? '',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[700]!,
                            highlightColor: Colors.grey[600]!,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (context, error, stackTrace) => Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.movie, size: 100),
                          ),
                        ),
                        Container(
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
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2B44),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (animeDetail?['rating'] != null)
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Rating: ${animeDetail!['rating']}',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              if (animeDetail?['episode_count'] != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.movie_filter, color: Color(0xFFF72585), size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Episodes: ${animeDetail!['episode_count']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '📝 Synopsis',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2B44),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Text(
                            animeDetail?['synopsis'] ?? 'No synopsis available',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.6,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          '📺 Episodes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...((animeDetail?['episode_lists'] ?? []) as List)
                            .map((ep) => EpisodeCard(episode: ep))
                            .toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class EpisodeCard extends StatelessWidget {
  final dynamic episode;

  const EpisodeCard({Key? key, required this.episode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2B44),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[700]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A4E69), Color(0xFFF72585)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF4A4E69).withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
        ),
        title: Text(
          episode['episode'] ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFFF72585)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerPage(
                episodeSlug: episode['slug'] ?? '',
                episodeTitle: episode['episode'] ?? '',
              ),
            ),
          );
        },
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String episodeSlug;
  final String episodeTitle;

  const VideoPlayerPage({
    Key? key,
    required this.episodeSlug,
    required this.episodeTitle,
  }) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  Map<String, dynamic>? episodeDetail;
  bool isLoading = true;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  BetterPlayerController? _betterPlayerController;
  String selectedQuality = '720p';
  List<String> availableQualities = [];
  Map<String, String> qualityUrls = {};
  String? errorMessage;
  bool useBetterPlayer = false; // Toggle to switch between Chewie and BetterPlayer

  @override
  void initState() {
    super.initState();
    fetchEpisodeDetail();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _betterPlayerController?.dispose();
    super.dispose();
  }

  Future<void> fetchEpisodeDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final data = await ApiService.fetchEpisodeDetail(widget.episodeSlug);
      
      setState(() {
        episodeDetail = data['data'];
        isLoading = false;

        // Clear previous data
        availableQualities.clear();
        qualityUrls.clear();

        // Extract video sources using the API service
        qualityUrls = ApiService.extractVideoSources(episodeDetail!);
        availableQualities = qualityUrls.keys.toList();

        print('Final Available Qualities: $availableQualities');
        print('Final Quality URLs: $qualityUrls');

        // Set default quality using API service helper
        if (availableQualities.isNotEmpty) {
          selectedQuality = ApiService.getPreferredQuality(availableQualities);
          
          if (qualityUrls.containsKey(selectedQuality)) {
            print('Initializing player with quality: $selectedQuality');
            initVideoPlayer(qualityUrls[selectedQuality]!);
          } else {
            setState(() {
              errorMessage = 'No valid video URL found for $selectedQuality';
            });
          }
        } else {
          setState(() {
            errorMessage = 'No video sources available from backend';
          });
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching episode: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void initVideoPlayer(String url) {
    print('Initializing video with URL: $url'); // Debug: Log video URL
    try {
      _videoController?.dispose();
      _chewieController?.dispose();
      _betterPlayerController?.dispose();

      if (useBetterPlayer) {
        // Use BetterPlayer
        _betterPlayerController = BetterPlayerController(
          BetterPlayerConfiguration(
            autoPlay: true,
            fit: BoxFit.contain,
            fullScreenByDefault: false,
            errorBuilder: (context, errorMessage) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 50),
                    const SizedBox(height: 16),
                    Text(
                      'Error: $errorMessage',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
            controlsConfiguration: BetterPlayerControlsConfiguration(
              progressBarPlayedColor: const Color(0xFFF72585),
              progressBarHandleColor: const Color(0xFFF72585),
              progressBarBackgroundColor: Colors.grey[800]!,
              progressBarBufferedColor: Colors.grey[600]!,
              enableQualities: true,
              enableFullscreen: true,
              enableMute: true,
            ),
          ),
          betterPlayerDataSource: BetterPlayerDataSource(
            BetterPlayerDataSourceType.network,
            url,
            headers: {
              'User-Agent': 'Mozilla/5.0',
              'Referer': 'https://www.sankavollerei.com',
            },
          ),
        );
        setState(() {});
      } else {
        // Use Chewie
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(url),
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': 'https://www.sankavollerei.com',
          },
        )..initialize().then((_) {
            setState(() {
              _chewieController = ChewieController(
                videoPlayerController: _videoController!,
                autoPlay: true,
                looping: false,
                allowFullScreen: true,
                allowMuting: true,
                showControls: true,
                errorBuilder: (context, errorMessage) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading video: $errorMessage',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              useBetterPlayer = true; // Switch to BetterPlayer on error
                              initVideoPlayer(url);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF72585),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Try Alternative Player'),
                        ),
                      ],
                    ),
                  );
                },
                materialProgressColors: ChewieProgressColors(
                  playedColor: const Color(0xFFF72585),
                  handleColor: const Color(0xFFF72585),
                  backgroundColor: Colors.grey[800]!,
                  bufferedColor: Colors.grey[600]!,
                ),
              );
            });
          }).catchError((error) {
            setState(() {
              errorMessage = 'Failed to load video: $error';
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load video: $error'),
                  backgroundColor: Colors.red[600],
                ),
              );
            }
          });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to initialize video: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize video: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void changeQuality(String quality) {
    if (qualityUrls.containsKey(quality)) {
      final currentPosition = useBetterPlayer
          ? _betterPlayerController?.videoPlayerController?.value.position
          : _videoController?.value.position;
      setState(() {
        selectedQuality = quality;
        errorMessage = null;
      });
      initVideoPlayer(qualityUrls[quality]!);

      if (currentPosition != null) {
        if (useBetterPlayer) {
          _betterPlayerController?.seekTo(currentPosition);
        } else {
          _videoController?.seekTo(currentPosition);
        }
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quality changed to $quality'),
          backgroundColor: const Color(0xFF00D2A0),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void showQualitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2B44),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Quality',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: Colors.grey[700]),
              const SizedBox(height: 16),
              ...availableQualities.map((quality) {
                bool isSelected = quality == selectedQuality;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [Color(0xFF4A4E69), Color(0xFFF72585)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF3A3B5B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.high_quality,
                      color: isSelected ? Colors.white : const Color(0xFFF72585),
                    ),
                  ),
                  title: Text(
                    quality,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? const Color(0xFFF72585) : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.done, color: Color(0xFFF72585))
                      : null,
                  onTap: () => changeQuality(quality),
                );
              }).toList(),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3B5B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    useBetterPlayer ? Icons.check_circle : Icons.videocam,
                    color: const Color(0xFFF72585),
                  ),
                ),
                title: Text(
                  useBetterPlayer ? 'Using Alternative Player' : 'Switch to Alternative Player',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  setState(() {
                    useBetterPlayer = !useBetterPlayer;
                    if (qualityUrls.containsKey(selectedQuality)) {
                      initVideoPlayer(qualityUrls[selectedQuality]!);
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (useBetterPlayer && (_betterPlayerController?.isFullScreen() ?? false)) {
          _betterPlayerController?.exitFullScreen();
          return false;
        } else if (_chewieController?.isFullScreen ?? false) {
          _chewieController?.exitFullScreen();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF22223B),
        appBar: AppBar(
          title: Text(
            widget.episodeTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF2A2B44),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (availableQualities.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.high_quality),
                onPressed: showQualitySelector,
                tooltip: 'Quality',
              ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF72585)))
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: fetchEpisodeDetail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF72585),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                        if (qualityUrls.containsKey(selectedQuality))
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                useBetterPlayer = !useBetterPlayer;
                                initVideoPlayer(qualityUrls[selectedQuality]!);
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D2A0),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(useBetterPlayer
                                ? 'Switch to Chewie Player'
                                : 'Try Alternative Player'),
                          ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        height: (useBetterPlayer
                                ? (_betterPlayerController?.isFullScreen() ?? false)
                                : (_chewieController?.isFullScreen ?? false))
                            ? MediaQuery.of(context).size.height
                            : 280,
                        color: Colors.black,
                        child: useBetterPlayer
                            ? (_betterPlayerController != null
                                ? BetterPlayer(controller: _betterPlayerController!)
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: Color(0xFFF72585)),
                                        SizedBox(height: 16),
                                        Text(
                                          'Loading video...',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ))
                            : (_chewieController != null &&
                                    _videoController!.value.isInitialized
                                ? Chewie(controller: _chewieController!)
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: Color(0xFFF72585)),
                                        SizedBox(height: 16),
                                        Text(
                                          'Loading video...',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  )),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2B44),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (availableQualities.isNotEmpty)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: showQualitySelector,
                                  icon: const Icon(Icons.high_quality, size: 20),
                                  label: Text(selectedQuality),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF72585),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Color(0xFFF72585), size: 26),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Video Info (${useBetterPlayer ? 'Alternative Player' : 'Default Player'})',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2B44),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[700]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.play_circle,
                                            color: Color(0xFFF72585), size: 22),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            widget.episodeTitle,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        const Icon(Icons.high_quality,
                                            color: Colors.amber, size: 22),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Current Quality: $selectedQuality',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.amber,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (availableQualities.length > 1) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'Available: ${availableQualities.join(", ")}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                '💡 Tips:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildTipItem('Tap screen to show/hide controls'),
                              _buildTipItem('Use fullscreen for better experience'),
                              _buildTipItem('Change quality based on your connection'),
                              _buildTipItem('Drag progress bar to seek'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chevron_right, color: Color(0xFFF72585), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}