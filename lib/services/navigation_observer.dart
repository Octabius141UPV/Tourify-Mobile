import 'package:flutter/material.dart';
import 'analytics_service.dart';

/// NavigatorObserver personalizado para tracking automático de navegación
class AnalyticsNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRouteChange(route, 'push');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackRouteChange(previousRoute, 'pop');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackRouteChange(newRoute, 'replace');
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (previousRoute != null) {
      _trackRouteChange(previousRoute, 'remove');
    }
  }

  /// Registra el cambio de ruta en el servicio de analytics
  void _trackRouteChange(Route<dynamic> route, String action) {
    try {
      final screenName = _extractScreenName(route);

      if (screenName.isNotEmpty) {
        // Registrar vista de pantalla
        AnalyticsService.trackScreenView(screenName, parameters: {
          'action': action,
          'route_type': route.runtimeType.toString(),
        });

        // Registrar evento de navegación
        AnalyticsService.trackEvent('screen_navigation', parameters: {
          'screen_name': screenName,
          'action': action,
          'timestamp': DateTime.now().toIso8601String(),
        });

        debugPrint('🧭 Navigation tracked: $action -> $screenName');
      }
    } catch (e) {
      debugPrint('❌ Error tracking navigation: $e');
    }
  }

  /// Extrae el nombre de la pantalla de la ruta
  String _extractScreenName(Route<dynamic> route) {
    try {
      // Obtener nombre de la ruta
      String? routeName = route.settings.name;

      if (routeName != null && routeName.isNotEmpty && routeName != '/') {
        // Limpiar nombre de ruta
        String screenName = routeName.replaceFirst('/', '');
        return _formatScreenName(screenName);
      }

      // Si no hay nombre de ruta, intentar extraer del tipo de página
      if (route is PageRoute) {
        String pageType = route.runtimeType.toString();
        if (pageType.contains('MaterialPageRoute') ||
            pageType.contains('CupertinoPageRoute')) {
          return 'unknown_page';
        }
        return _formatScreenName(pageType);
      }

      // Como último recurso, usar tipo de ruta
      String routeType = route.runtimeType.toString();
      return _formatScreenName(routeType);
    } catch (e) {
      debugPrint('❌ Error extracting screen name: $e');
      return 'unknown_screen';
    }
  }

  /// Formatea el nombre de pantalla para hacerlo más legible
  String _formatScreenName(String rawName) {
    if (rawName.isEmpty) return 'unknown';

    // Mapeo de rutas conocidas a nombres amigables
    final Map<String, String> routeMapping = {
      'login': 'Login',
      'register': 'Register',
      'home': 'Home',
      'profile': 'Profile',
      'my-guides': 'My Guides',
      'guide-detail': 'Guide Detail',
      'verify-email': 'Verify Email',
      'forgot-password': 'Forgot Password',
      'discover': 'Discover Activities',
      'collaborators': 'Collaborators',
      'premium': 'Premium Subscription',
      'guide-map': 'Guide Map',
    };

    // Buscar mapeo directo
    String lowerName = rawName.toLowerCase();
    if (routeMapping.containsKey(lowerName)) {
      return routeMapping[lowerName]!;
    }

    // Limpiar nombres de clases/widgets
    String cleanedName = rawName
        .replaceAll('Screen', '')
        .replaceAll('Page', '')
        .replaceAll('Route', '')
        .replaceAll('Widget', '');

    // Convertir CamelCase a palabras separadas
    cleanedName = cleanedName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .trim();

    // Capitalizar primera letra de cada palabra
    return cleanedName
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : word)
        .join(' ');
  }
}
