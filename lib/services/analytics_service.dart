import 'package:flutter/foundation.dart';

/// Servicio centralizado para manejar analytics y tracking de eventos
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool _isInitialized = false;
  String? _currentScreen;
  Map<String, dynamic> _sessionData = {};

  /// Inicializa el servicio de analytics
  static Future<void> initialize() async {
    try {
      if (_instance._isInitialized) return;

      debugPrint('✅ AnalyticsService inicializado');
      _instance._isInitialized = true;
    } catch (e) {
      debugPrint('❌ Error inicializando AnalyticsService: $e');
    }
  }

  /// Registra una vista de pantalla en Microsoft Clarity
  static void trackScreenView(String screenName,
      {Map<String, dynamic>? parameters}) {
    try {
      if (!_instance._isInitialized) return;

      // Log para debug
      debugPrint('📊 Screen view: $screenName');
      if (parameters != null) {
        debugPrint('   Parámetros: $parameters');
      }

      // Actualizar pantalla actual
      _instance._currentScreen = screenName;

      // Guardar datos de la sesión para análisis posterior
      _instance._sessionData['last_screen'] = screenName;
      _instance._sessionData['last_screen_time'] =
          DateTime.now().toIso8601String();

      if (parameters != null) {
        _instance._sessionData.addAll(parameters);
      }
    } catch (e) {
      debugPrint('❌ Error tracking screen view: $e');
    }
  }

  /// Registra un evento personalizado
  static void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    try {
      if (!_instance._isInitialized) return;

      debugPrint('📊 Event: $eventName');
      if (parameters != null) {
        debugPrint('   Parámetros: $parameters');
      }

      // Guardar evento en datos de sesión
      final eventData = {
        'event': eventName,
        'timestamp': DateTime.now().toIso8601String(),
        'screen': _instance._currentScreen ?? 'unknown',
        ...?parameters,
      };

      _instance._sessionData['last_event'] = eventData;
    } catch (e) {
      debugPrint('❌ Error tracking event: $e');
    }
  }

  /// Registra inicio de sesión
  static void trackLogin(String method) {
    trackEvent('login', parameters: {
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra cierre de sesión
  static void trackLogout() {
    trackEvent('logout', parameters: {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra creación de guía
  static void trackGuideCreation(String guideId, String destination) {
    trackEvent('guide_created', parameters: {
      'guide_id': guideId,
      'destination': destination,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra visualización de guía
  static void trackGuideView(String guideId, String guideTitle) {
    trackEvent('guide_viewed', parameters: {
      'guide_id': guideId,
      'guide_title': guideTitle,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra interacción con actividad
  static void trackActivityInteraction(String action, String activityId) {
    trackEvent('activity_interaction', parameters: {
      'action': action, // 'accept', 'reject', 'undo', 'edit', etc.
      'activity_id': activityId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra uso de funciones premium
  static void trackPremiumFeatureUsage(String feature) {
    trackEvent('premium_feature_used', parameters: {
      'feature': feature,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra errores importantes
  static void trackError(String error, String context) {
    trackEvent('error', parameters: {
      'error_message': error,
      'context': context,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra el estado del usuario
  static void setUserProperties({
    String? userId,
    bool? isPremium,
    String? userType,
  }) {
    try {
      if (!_instance._isInitialized) return;

      if (userId != null) {
        _instance._sessionData['user_id'] = userId;
        debugPrint('📊 User ID set: $userId');
      }

      if (isPremium != null) {
        _instance._sessionData['is_premium'] = isPremium.toString();
        debugPrint('📊 Premium status: $isPremium');
      }

      if (userType != null) {
        _instance._sessionData['user_type'] = userType;
        debugPrint('📊 User type: $userType');
      }
    } catch (e) {
      debugPrint('❌ Error setting user properties: $e');
    }
  }

  /// Registra el inicio del discover de actividades
  static void trackDiscoverStart(String destination, int travelers) {
    trackEvent('discover_started', parameters: {
      'destination': destination,
      'travelers': travelers.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra la finalización del discover
  static void trackDiscoverComplete(
      int acceptedActivities, int rejectedActivities) {
    trackEvent('discover_completed', parameters: {
      'accepted_activities': acceptedActivities.toString(),
      'rejected_activities': rejectedActivities.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra navegación entre colaboradores
  static void trackCollaboratorAction(String action, String guideId) {
    trackEvent('collaborator_action', parameters: {
      'action': action, // 'add', 'remove', 'view'
      'guide_id': guideId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra uso del mapa
  static void trackMapUsage(String action, String? location) {
    trackEvent('map_usage', parameters: {
      'action': action, // 'view', 'search', 'marker_tap'
      'location': location ?? 'unknown',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
