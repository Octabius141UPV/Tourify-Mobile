import 'package:shared_preferences/shared_preferences.dart';

class GuideTutorialService {
  static const String _guideTutorialKey = 'guide_tutorial_completed';
  static const String _guideTutorialVersionKey = 'guide_tutorial_version';
  static const int _currentGuideTutorialVersion = 1;

  /// Verifica si el usuario ya ha completado el tutorial de guías
  static Future<bool> hasCompletedGuideTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_guideTutorialKey) ?? false;
    final version = prefs.getInt(_guideTutorialVersionKey) ?? 0;

    // Si el tutorial ya se completó con la versión actual, no mostrar
    return completed && version >= _currentGuideTutorialVersion;
  }

  /// Marca el tutorial de guías como completado
  static Future<void> markGuideTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guideTutorialKey, true);
    await prefs.setInt(_guideTutorialVersionKey, _currentGuideTutorialVersion);
  }

  /// Resetea el tutorial de guías (útil para testing)
  static Future<void> resetGuideTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guideTutorialKey, false);
    await prefs.remove(_guideTutorialVersionKey);
  }

  /// Verifica si es la primera vez que se abre una guía
  static Future<bool> isFirstGuideOpen() async {
    return !(await hasCompletedGuideTutorial());
  }
}
