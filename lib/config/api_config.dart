import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // URL base del servidor con fallback
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  }

  // Endpoints específicos
  static String get publicGuidesEndpoint => '$baseUrl/public-guides';
  static String get discoverEndpoint => '$baseUrl/discover';
  static String get authEndpoint => '$baseUrl/auth';
  static String get collaboratorsEndpoint => '$baseUrl/collaborators';
  static String get guidesEndpoint => '$baseUrl/guides';

  // Métodos para construir URLs específicas
  static String getPublicGuideViewUrl(String guideId) =>
      '$publicGuidesEndpoint/$guideId/view';
  static String getPublicGuideViewsUrl(String guideId) =>
      '$publicGuidesEndpoint/$guideId/views';

  // Debug info
  static void printConfig() {
    print('🔧 API Configuration:');
    print('   Base URL: $baseUrl');
    print('   Public Guides: $publicGuidesEndpoint');
    print('   Discover: $discoverEndpoint');
    print('   Auth: $authEndpoint');
  }
}
