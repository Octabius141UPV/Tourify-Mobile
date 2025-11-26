import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourify_flutter/services/onboarding_service.dart';
import 'package:tourify_flutter/config/debug_config.dart';

/// Helpers para desarrollo y testing
class DevelopmentHelpers {
  /// 🔧 Resetea completamente la app para testing
  static Future<void> resetAppForTesting() async {
    if (!kDebugMode) {
      print('❌ Esta función solo está disponible en modo debug');
      return;
    }

    print('🧹 Reseteando aplicación para testing...');

    // 1. Cerrar sesión de Firebase
    await FirebaseAuth.instance.signOut();
    print('   ✅ Sesión Firebase cerrada');

    // 2. Resetear onboarding
    await OnboardingService.resetOnboarding();
    print('   ✅ Onboarding reseteado');

    // 3. Resetear welcome screen
    await OnboardingService.resetWelcomeScreen();
    print('   ✅ Welcome screen reseteado');

    print('🎉 Reset completo! Reinicia la app para ver WelcomeScreen');
  }

  /// 📊 Muestra el estado actual de la app
  static Future<void> showAppStatus() async {
    if (!kDebugMode) return;

    print('\n📊 === ESTADO ACTUAL DE LA APP ===');

    // Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    print('🔐 Usuario autenticado: ${user != null}');
    if (user != null) {
      print('    - UID: ${user.uid}');
      print('    - Email: ${user.email}');
    }

    // Onboarding
    final hasCompleted = await OnboardingService.hasCompletedOnboarding();
    final hasSeenWelcome = await OnboardingService.hasSeenWelcomeScreen();
    print('🎓 Onboarding completado: $hasCompleted');
    print('👋 Ha visto Welcome: $hasSeenWelcome');

    // Debug settings
    print('🔧 Bypass SMS habilitado: ${DebugConfig.shouldBypassSMS()}');

    print('================================\n');
  }

  /// 🔧 Toggle del bypass SMS (solo en debug)
  static void toggleSMSBypass() {
    if (!kDebugMode) return;

    // Nota: Como DebugConfig.bypassSMSInDevelopment es const,
    // no se puede cambiar en runtime. Para cambiarlo necesitas
    // modificar el archivo debug_config.dart directamente.
    print(
        '🔧 Para cambiar el bypass SMS, modifica DebugConfig.bypassSMSInDevelopment');
    print('   Valor actual: ${DebugConfig.bypassSMSInDevelopment}');
  }
}

/// Funciones globales para llamar fácilmente desde cualquier lugar

/// Resetea la app completamente
Future<void> devResetApp() => DevelopmentHelpers.resetAppForTesting();

/// Muestra el estado actual
Future<void> devShowStatus() => DevelopmentHelpers.showAppStatus();

/// Info sobre bypass SMS
void devSMSInfo() => DevelopmentHelpers.toggleSMSBypass();
