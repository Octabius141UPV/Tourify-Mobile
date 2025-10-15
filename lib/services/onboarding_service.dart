import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingService {
  static const String _onboardingKey = 'has_completed_onboarding';
  static const String _onboardingVersionKey = 'onboarding_version';
  static const String _welcomeScreenKey = 'has_seen_welcome_screen';
  static const int _currentOnboardingVersion =
      1; // Incrementar si cambias el onboarding

  /// Verifica si el usuario ya completó el onboarding
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompleted = prefs.getBool(_onboardingKey) ?? false;
      final version = prefs.getInt(_onboardingVersionKey) ?? 0;

      // Si la versión del onboarding es diferente, mostrar onboarding nuevamente
      if (hasCompleted && version >= _currentOnboardingVersion) {
        return true;
      }

      // Fallback/Sync con Firestore: si el usuario está autenticado y en
      // su documento figura que ya completó el onboarding, respetarlo y
      // sincronizar el flag local para no volver a pedirlo en este dispositivo.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final snap =
              await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (snap.exists) {
            final data = snap.data() as Map<String, dynamic>?;
            final remoteCompleted = (data?['hasCompletedOnboarding'] as bool?) ?? false;
            if (remoteCompleted) {
              await prefs.setBool(_onboardingKey, true);
              await prefs.setInt(_onboardingVersionKey, _currentOnboardingVersion);
              return true;
            }
          }
        } catch (_) {
          // Silencioso: si falla la red, mantener el comportamiento previo
        }
      }

      return false;
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

      // También reflejar en Firestore si el usuario está autenticado
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'hasCompletedOnboarding': true}, SetOptions(merge: true));
        } catch (e) {
          print('Error actualizando flag remoto de onboarding: $e');
        }
      }
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

  /// Verifica si el usuario ya vio la pantalla de bienvenida
  static Future<bool> hasSeenWelcomeScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_welcomeScreenKey) ?? false;
    } catch (e) {
      print('Error checking welcome screen status: $e');
      return false;
    }
  }

  /// Marca la pantalla de bienvenida como vista
  static Future<void> markWelcomeScreenSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeScreenKey, true);
      print('Welcome screen marcada como vista');
    } catch (e) {
      print('Error marking welcome screen as seen: $e');
    }
  }

  /// Resetea el estado de la pantalla de bienvenida (útil para testing)
  static Future<void> resetWelcomeScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_welcomeScreenKey);
      print('Welcome screen reseteada');
    } catch (e) {
      print('Error resetting welcome screen: $e');
    }
  }
}
