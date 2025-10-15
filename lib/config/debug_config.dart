import 'package:flutter/foundation.dart';

/// Configuración de debugging para la aplicación
class DebugConfig {
  /// 🔧 BYPASS SMS para desarrollo/simulador
  /// Cambia a `false` para habilitar SMS en producción
  static const bool bypassSMSInDevelopment = false;

  /// Determina si se debe hacer bypass del SMS
  static bool shouldBypassSMS() {
    // Solo hacer bypass en modo debug
    if (kDebugMode && bypassSMSInDevelopment) {
      return true;
    }
    return false;
  }

  /// Mostrar información de debugging en consola
  static void debugPrint(String message) {
    if (kDebugMode) {
      print('🔧 [DEBUG] $message');
    }
  }

  /// Configuraciones adicionales de debug
  static const bool showDebugBanners = false;
  static const bool enableDetailedLogging = false;

  /// Filtrado de adjuntos (tickets) en servidor con Firestore
  /// Actívalo cuando tengas creados los índices compuestos necesarios.
  /// En modo viewer se sigue aplicando un filtro adicional en cliente
  /// para incluir los creados por el usuario si no hay índice OR.
  static const bool enableServerSideAttachmentFilters = true;

  /// Forzar cerrar sesión al iniciar en modo debug (útil para probar flujos
  /// de bienvenida/onboarding sin que Firebase restaure sesiones previas).
  static const bool forceSignOutOnStart = false;

  /// Registrar en consola el estado de autenticación al iniciar (UID, email,
  /// providers, etc.). Solo tiene efecto en modo debug.
  static const bool logAuthStatusOnStart = false;

  static bool shouldForceSignOutOnStart() {
    return kDebugMode && forceSignOutOnStart;
  }

  static bool shouldLogAuthStatusOnStart() {
    return kDebugMode && logAuthStatusOnStart;
  }
}
