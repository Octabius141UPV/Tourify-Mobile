import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _onboardingKey = 'has_completed_onboarding';
  static const String _onboardingVersionKey = 'onboarding_version';
  static const int _currentOnboardingVersion =
      1; // Incrementar si cambias el onboarding

  /// Verifica si el usuario ya completó el onboarding
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompleted = prefs.getBool(_onboardingKey) ?? false;
      final version = prefs.getInt(_onboardingVersionKey) ?? 0;

      // Si la versión del onboarding es diferente, mostrar onboarding nuevamente
      return hasCompleted && version >= _currentOnboardingVersion;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }

  /// Marca el onboarding como completado
  static Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
      await prefs.setInt(_onboardingVersionKey, _currentOnboardingVersion);
      print('Onboarding marcado como completado');
    } catch (e) {
      print('Error marking onboarding as completed: $e');
    }
  }

  /// Resetea el estado del onboarding (útil para testing)
  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingKey);
      await prefs.remove(_onboardingVersionKey);
      print('Onboarding reseteado');
    } catch (e) {
      print('Error resetting onboarding: $e');
    }
  }

  /// Verifica si es la primera vez que abre la app
  static Future<bool> isFirstLaunch() async {
    try {
      const String firstLaunchKey = 'is_first_launch';
      final prefs = await SharedPreferences.getInstance();
      final isFirst = prefs.getBool(firstLaunchKey) ?? true;

      if (isFirst) {
        await prefs.setBool(firstLaunchKey, false);
      }

      return isFirst;
    } catch (e) {
      print('Error checking first launch: $e');
      return true;
    }
  }
}
