import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:clarity_flutter/clarity_flutter.dart' as clarity;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Servicio centralizado para manejar analytics y tracking de eventos
/// Utiliza Firebase Analytics y está preparado para Microsoft Clarity
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;
  static bool _isFirebaseInitialized = false;
  static bool _isClarityInitialized = false;
  String? _currentScreen;
  Map<String, dynamic> _sessionData = {};

  // Constantes para límites de Firebase Analytics
  static const int _maxScreenNameLength = 100;
  static const int _maxParameterValueLength = 100;
  static const int _maxEventNameLength = 40;

  /// Getter para el observer de Firebase Analytics
  static FirebaseAnalyticsObserver? get observer => _observer;

  /// Inicializa ambos servicios de analytics
  static Future<void> initialize() async {
    try {
      // Inicializar Firebase Analytics
      await _initializeFirebase();

      // Inicializar Microsoft Clarity (si hay Project ID configurado)
      await _initializeClarity();

      debugPrint(
          '🎯 Analytics Service inicializado: Firebase=${_isFirebaseInitialized}, Clarity=${_isClarityInitialized}');
    } catch (e) {
      debugPrint('❌ Error inicializando Analytics Service: $e');
    }
  }

  /// Inicializa Firebase Analytics
  static Future<void> _initializeFirebase() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _isFirebaseInitialized = true;
      debugPrint('✅ Firebase Analytics inicializado');
    } catch (e) {
      debugPrint('❌ Error inicializando Firebase Analytics: $e');
      _isFirebaseInitialized = false;
    }
  }

  /// Inicializa Microsoft Clarity si se configura un Project ID válido en las
  /// variables de entorno (.env → CLARITY_PROJECT_ID).
  static Future<void> _initializeClarity() async {
    try {
      // Comprobamos que existe CLARITY_PROJECT_ID para habilitar Clarity.
      final projectId = dotenv.env['CLARITY_PROJECT_ID'] ?? '';

      if (projectId.isEmpty || projectId == 'tu_clarity_project_id_aqui') {
        debugPrint('ℹ️ Project ID de Clarity no configurado, se omite init');
        _isClarityInitialized = false;
        return;
      }

      // La inicialización real se realiza en main.dart envolviendo la app
      // con ClarityWidget. Aquí solo marcamos la bandera.
      _isClarityInitialized = true;
      debugPrint('✅ Microsoft Clarity habilitado en AnalyticsService');
    } catch (e) {
      debugPrint('❌ Error inicializando Microsoft Clarity: $e');
      _isClarityInitialized = false;
    }
  }

  /// Sanitiza y trunca un nombre de pantalla para cumplir con los límites de Firebase
  static String _sanitizeScreenName(String screenName) {
    if (screenName.isEmpty) return 'unknown_screen';

    // Detectar si es un deep link de Firebase Auth
    if (_isFirebaseAuthDeepLink(screenName)) {
      return 'firebase_auth_callback';
    }

    // Detectar si es una URL larga
    if (screenName.startsWith('http') || screenName.contains('://')) {
      return 'deep_link_callback';
    }

    // Detectar si contiene parámetros de query
    if (screenName.contains('?') || screenName.contains('&')) {
      return 'callback_screen';
    }

    // Limpiar caracteres especiales y truncar
    String sanitized = screenName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();

    // Truncar si es muy largo
    if (sanitized.length > _maxScreenNameLength) {
      sanitized = sanitized.substring(0, _maxScreenNameLength - 3) + '...';
    }

    return sanitized.isEmpty ? 'unknown_screen' : sanitized;
  }

  /// Detecta si el nombre de pantalla es un deep link de Firebase Auth
  static bool _isFirebaseAuthDeepLink(String screenName) {
    return screenName.contains('firebaseauth') ||
        screenName.contains('auth/callback') ||
        screenName.contains('recaptchaToken') ||
        screenName.contains('authType=verifyApp');
  }

  /// Sanitiza y trunca parámetros para cumplir con los límites de Firebase
  static Map<String, Object> _sanitizeParameters(
      Map<String, dynamic>? parameters) {
    if (parameters == null) return {};

    Map<String, Object> sanitized = {};

    for (final entry in parameters.entries) {
      String key = _sanitizeParameterKey(entry.key);
      Object value = _sanitizeParameterValue(entry.value);

      if (key.isNotEmpty) {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  /// Sanitiza la clave de un parámetro
  static String _sanitizeParameterKey(String key) {
    return key
        .replaceAll(RegExp(r'[^\w]'), '_')
        .toLowerCase()
        .substring(0, key.length > 40 ? 40 : key.length);
  }

  /// Sanitiza el valor de un parámetro
  static Object _sanitizeParameterValue(dynamic value) {
    if (value == null) return 'null';

    String stringValue = value.toString();

    // Si es una URL o deep link muy largo, truncarlo
    if (stringValue.startsWith('http') ||
        stringValue.contains('://') ||
        stringValue.length > _maxParameterValueLength) {
      if (_isFirebaseAuthDeepLink(stringValue)) {
        return 'firebase_auth_callback';
      }

      if (stringValue.contains('?') || stringValue.contains('&')) {
        return 'deep_link_callback';
      }

      // Truncar valores largos
      if (stringValue.length > _maxParameterValueLength) {
        return stringValue.substring(0, _maxParameterValueLength - 3) + '...';
      }
    }

    return stringValue;
  }

  /// Registra un evento en ambos servicios
  static Future<void> trackEvent(String eventName,
      {Map<String, dynamic>? parameters}) async {
    try {
      // Sanitizar nombre del evento
      String sanitizedEventName = _sanitizeEventName(eventName);

      // Sanitizar parámetros
      Map<String, Object> sanitizedParams = _sanitizeParameters(parameters);

      // Firebase Analytics
      if (_isFirebaseInitialized && _analytics != null) {
        await _analytics!.logEvent(
          name: sanitizedEventName,
          parameters: sanitizedParams,
        );
      }

      // TODO: Microsoft Clarity tracking
      if (_isClarityInitialized) {
        try {
          // Enviar evento personalizado
          clarity.Clarity.sendCustomEvent(sanitizedEventName);

          // Opcional: enviar cada parámetro como tag para filtrado
          for (final entry in sanitizedParams.entries) {
            clarity.Clarity.setCustomTag(entry.key, entry.value.toString());
          }
        } catch (e) {
          debugPrint('⚠️ No se pudo enviar evento a Clarity: $e');
        }
      }

      // Debug print
      debugPrint('📊 Evento enviado a Firebase: $sanitizedEventName');
      if (sanitizedParams.isNotEmpty) {
        debugPrint('   Parámetros: $sanitizedParams');
      }
    } catch (e) {
      debugPrint('❌ Error enviando evento $eventName: $e');
    }
  }

  /// Registra vista de pantalla en ambos servicios
  static Future<void> trackScreenView(String screenName,
      {Map<String, dynamic>? parameters}) async {
    try {
      // Sanitizar nombre de pantalla
      String sanitizedScreenName = _sanitizeScreenName(screenName);

      // Sanitizar parámetros
      Map<String, Object> sanitizedParams = _sanitizeParameters(parameters);

      // Firebase Analytics
      if (_isFirebaseInitialized && _analytics != null) {
        await _analytics!.logScreenView(
          screenName: sanitizedScreenName,
          parameters: sanitizedParams,
        );
      }

      // Microsoft Clarity tracking (establecer nombre de pantalla)
      if (_isClarityInitialized) {
        clarity.Clarity.setCurrentScreenName(sanitizedScreenName);
        debugPrint('📱 Clarity: Vista de pantalla - $sanitizedScreenName');
      }

      debugPrint('📱 Vista de pantalla registrada: $sanitizedScreenName');
    } catch (e) {
      debugPrint('❌ Error registrando vista de pantalla $screenName: $e');
    }
  }

  /// Establece propiedades del usuario en ambos servicios
  static Future<void> setUserProperties(Map<String, dynamic> properties) async {
    try {
      // Firebase Analytics
      if (_isFirebaseInitialized && _analytics != null) {
        for (final entry in properties.entries) {
          await _analytics!.setUserProperty(
            name: entry.key,
            value: entry.value?.toString(),
          );
        }
      }

      // Microsoft Clarity
      if (_isClarityInitialized) {
        try {
          for (final entry in properties.entries) {
            clarity.Clarity.setCustomTag(entry.key, entry.value.toString());
          }
        } catch (e) {
          debugPrint('⚠️ No se pudieron setear tags en Clarity: $e');
        }
      }

      debugPrint('👤 Propiedades de usuario establecidas: $properties');
    } catch (e) {
      debugPrint('❌ Error estableciendo propiedades de usuario: $e');
    }
  }

  /// Establece ID de usuario en ambos servicios
  static Future<void> setUserId(String userId) async {
    try {
      // Firebase Analytics
      if (_isFirebaseInitialized && _analytics != null) {
        await _analytics!.setUserId(id: userId);
      }

      // Microsoft Clarity
      if (_isClarityInitialized) {
        try {
          await clarity.Clarity.setCustomUserId(userId);
          debugPrint('🆔 Clarity: ID de usuario establecido');
        } catch (e) {
          debugPrint('⚠️ No se pudo establecer customUserId en Clarity: $e');
        }
      }

      debugPrint('🆔 ID de usuario establecido: $userId');
    } catch (e) {
      debugPrint('❌ Error estableciendo ID de usuario: $e');
    }
  }

  /// Sanitiza nombres de eventos para Firebase (solo letras, números y guiones bajos)
  static String _sanitizeEventName(String eventName) {
    return eventName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
  }

  /// Registra inicio de sesión
  static Future<void> trackLogin(String method) async {
    await trackEvent('login', parameters: {
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra cierre de sesión
  static Future<void> trackLogout() async {
    await trackEvent('logout', parameters: {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra creación de guía
  static Future<void> trackGuideCreation(
      String guideId, String destination) async {
    await trackEvent('guide_created', parameters: {
      'guide_id': guideId,
      'destination': destination,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra visualización de guía
  static Future<void> trackGuideView(String guideId, String destination) async {
    await trackEvent('guide_viewed', parameters: {
      'guide_id': guideId,
      'destination': destination,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra búsqueda de destino
  static Future<void> trackDestinationSearch(
      String query, int resultsCount) async {
    await trackEvent('destination_search', parameters: {
      'query': query,
      'results_count': resultsCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra uso de funciones premium
  static Future<void> trackPremiumFeatureUsage(String feature) async {
    await trackEvent('premium_feature_used', parameters: {
      'feature': feature,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra clics en el botón de pagar suscripción premium
  static Future<void> trackPremiumPaymentClick(String source) async {
    await trackEvent('premium_payment_click', parameters: {
      'source': source, // 'subscription_screen', 'feature_modal', etc.
      'price': '5_eur_per_month',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registra errores de la aplicación
  static Future<void> trackError(String error, String? stackTrace) async {
    await trackEvent('app_error', parameters: {
      'error': error,
      'stack_trace': stackTrace ?? 'No stack trace',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Obtiene datos de la sesión actual
  Map<String, dynamic> getSessionData() {
    return Map<String, dynamic>.from(_sessionData);
  }

  /// Limpia datos de la sesión
  void clearSessionData() {
    _sessionData.clear();
    debugPrint('🧹 Datos de sesión limpiados');
  }

  /// Genera un ID único para el usuario de Clarity
  static String generateClarityUserId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(timestamp);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8).toUpperCase();
  }
}
