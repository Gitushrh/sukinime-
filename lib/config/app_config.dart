class AppConfig {
  // 🚀 RAILWAY BACKEND CONFIGURATION
  // Update these URLs with your actual Railway deployment URLs
  
  // Main API endpoint - Replace with your Railway backend URL
  static const String RAILWAY_BASE_URL = 'https://anime-backend.up.railway.app';
  
  // API endpoints
  static const String API_BASE_URL = '$RAILWAY_BASE_URL/api/anime';
  static const String ANIME_BASE_URL = '$RAILWAY_BASE_URL/anime';
  
  // Alternative URLs (if you have multiple deployments)
  static const String FALLBACK_URL = 'https://your-backup-deployment.up.railway.app';
  
  // App configuration
  static const String APP_NAME = 'AnimeHub';
  static const String APP_VERSION = '1.0.0';
  static const String USER_AGENT = 'Flutter AnimeApp/1.0';
  
  // API settings
  static const int REQUEST_TIMEOUT = 30; // seconds
  static const int MAX_RETRIES = 3;
  
  // Video player settings
  static const List<String> PREFERRED_QUALITIES = ['720p', '480p', '360p'];
  static const String DEFAULT_QUALITY = '720p';
  
  // Colors
  static const int PRIMARY_COLOR = 0xFF4A4E69;
  static const int SECONDARY_COLOR = 0xFFF72585;
  static const int BACKGROUND_COLOR = 0xFF22223B;
  static const int CARD_COLOR = 0xFF2A2B44;
  
  // Development mode
  static const bool DEBUG_MODE = true; // Set to false in production
  
  // Helper methods
  static bool get isDebugMode => DEBUG_MODE;
  
  static void printDebug(String message) {
    if (DEBUG_MODE) {
      print('🐛 DEBUG: $message');
    }
  }
  
  static void printInfo(String message) {
    print('ℹ️ INFO: $message');
  }
  
  static void printError(String message) {
    print('❌ ERROR: $message');
  }
}

// Railway deployment instructions
class RailwaySetupInstructions {
  static const String instructions = '''
🚀 RAILWAY DEPLOYMENT SETUP INSTRUCTIONS

1. Update your Railway backend URL:
   - Open lib/config/app_config.dart
   - Replace 'https://anime-backend.up.railway.app' with your actual Railway URL
   - You can find this URL in your Railway dashboard

2. Backend API Endpoints:
   Your backend should be accessible at these endpoints:
   - GET /api/anime/home - Homepage data
   - GET /api/anime/ongoing - Ongoing anime list
   - GET /api/anime/search/{query} - Search anime
   - GET /api/anime/{slug} - Anime details
   - GET /api/anime/episode/{slug} - Episode details with video sources
   - GET /api/anime/schedule - Weekly schedule
   - GET /api/anime/genre/{genre} - Anime by genre
   - GET /api/anime/release-year/{year} - Anime by year

3. Expected Response Format:
   All endpoints should return JSON in this format:
   {
     "status": "success",
     "data": { ... },
     "message": "Optional message"
   }

4. Video Sources Format:
   Episode endpoints should return:
   {
     "status": "success",
     "data": {
       "video_sources": [
         {
           "url": "https://example.com/video.mp4",
           "quality": "720p",
           "type": "mp4",
           "provider": "direct"
         }
       ],
       "download_urls": { ... }, // Legacy format support
       "stream_urls": [ ... ]    // HLS sources
     }
   }

5. Testing:
   - Use a tool like Postman to test your Railway endpoints
   - Check that CORS is properly configured for mobile apps
   - Ensure all video URLs are accessible and properly formatted

6. Troubleshooting:
   - Check Railway logs if endpoints return errors
   - Verify environment variables are set correctly
   - Make sure your backend is deployed and running
   - Test individual endpoints before running the Flutter app
''';
  
  static void printInstructions() {
    print(instructions);
  }
}