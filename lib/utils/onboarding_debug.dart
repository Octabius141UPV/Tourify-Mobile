import 'package:flutter/foundation.dart';
import '../services/onboarding_service.dart';

/// Funciones de utilidad para desarrollo y testing del onboarding
class OnboardingDebugUtils {
  /// Resetea completamente el onboarding para verlo desde el inicio
  /// Úsalo durante desarrollo para probar el flujo completo
  static Future<void> resetOnboardingForDev() async {
    if (kDebugMode) {
      await OnboardingService.resetOnboarding();
      await OnboardingService.resetWelcomeScreen();
      debugPrint('🔄 Onboarding reseteado para desarrollo');
      debugPrint('📱 Reinicia la app para ver la pantalla de bienvenida');
    }
  }

  /// Solo resetea la pantalla de bienvenida
  static Future<void> resetWelcomeOnly() async {
    if (kDebugMode) {
      await OnboardingService.resetWelcomeScreen();
      debugPrint('👋 Welcome screen reseteado - reinicia la app');
    }
  }

  /// Solo resetea el onboarding (mantiene welcome como visto)
  static Future<void> resetOnboardingOnly() async {
    if (kDebugMode) {
      await OnboardingService.resetOnboarding();
      debugPrint('🎓 Onboarding reseteado - reinicia la app');
    }
  }

  /// Muestra el estado actual del onboarding
  static Future<void> showCurrentState() async {
    if (kDebugMode) {
      final hasSeenWelcome = await OnboardingService.hasSeenWelcomeScreen();
      final hasCompletedOnboarding =
          await OnboardingService.hasCompletedOnboarding();
      final isFirstLaunch = await OnboardingService.isFirstLaunch();

      debugPrint('📊 Estado actual del onboarding:');
      debugPrint('   👋 Ha visto bienvenida: $hasSeenWelcome');
      debugPrint('   🎓 Ha completado onboarding: $hasCompletedOnboarding');
      debugPrint('   🚀 Es primer lanzamiento: $isFirstLaunch');
    }
  }
}

/// Funciones globales para usar fácilmente en desarrollo
/// Puedes llamarlas desde cualquier lugar del código

/// Resetea todo para ver el onboarding completo desde el inicio
Future<void> devResetOnboarding() async {
  await OnboardingDebugUtils.resetOnboardingForDev();
}

/// Muestra el estado actual
Future<void> devShowOnboardingState() async {
  await OnboardingDebugUtils.showCurrentState();
}
