import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GuestGuideService {
  static const String _guestGuideKey = 'temporary_guest_guide';

  /// Guarda temporalmente una guía de invitado
  static Future<void> saveTemporaryGuide(Map<String, dynamic> guide) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guideJson = jsonEncode(guide);
      await prefs.setString(_guestGuideKey, guideJson);
      print('Guía temporal guardada para registro posterior');
    } catch (e) {
      print('Error guardando guía temporal: $e');
    }
  }

  /// Guarda una guía con duración en días
  static Future<void> saveTemporaryGuideWithDuration(
      Map<String, dynamic> guide, int days) async {
    try {
      final guideWithDuration = Map<String, dynamic>.from(guide);

      guideWithDuration['duration'] = {
        'days': days,
        'displayName': _getDurationDisplayName(days)
      };

      final prefs = await SharedPreferences.getInstance();
      final guideJson = jsonEncode(guideWithDuration);
      await prefs.setString(_guestGuideKey, guideJson);
      print(
          'Guía temporal guardada con duración: ${guideWithDuration['duration']['displayName']}');
    } catch (e) {
      print('Error guardando guía temporal con duración: $e');
    }
  }

  /// Genera el nombre de visualización según los días
  static String _getDurationDisplayName(int days) {
    if (days == 1) {
      return '1 día';
    } else if (days == 2) {
      return 'Fin de semana (2 días)';
    } else if (days >= 3 && days <= 4) {
      return 'Escapada corta ($days días)';
    } else if (days == 7) {
      return 'Una semana';
    } else if (days >= 8 && days <= 10) {
      return 'Semana larga ($days días)';
    } else if (days == 14) {
      return 'Dos semanas';
    } else if (days >= 21 && days <= 31) {
      return 'Un mes ($days días)';
    } else {
      return '$days días';
    }
  }

  /// Recupera la guía temporal de invitado
  static Future<Map<String, dynamic>?> getTemporaryGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guideJson = prefs.getString(_guestGuideKey);

      if (guideJson != null) {
        return jsonDecode(guideJson) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      print('Error recuperando guía temporal: $e');
      return null;
    }
  }

  /// Limpia la guía temporal (después de que se registre)
  static Future<void> clearTemporaryGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestGuideKey);
      print('Guía temporal limpiada');
    } catch (e) {
      print('Error limpiando guía temporal: $e');
    }
  }

  /// Verifica si hay una guía temporal guardada
  static Future<bool> hasTemporaryGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_guestGuideKey);
    } catch (e) {
      print('Error verificando guía temporal: $e');
      return false;
    }
  }

  /// Obtiene la duración del viaje de la guía temporal
  static Future<Map<String, dynamic>?> getTripDuration() async {
    try {
      final guide = await getTemporaryGuide();
      if (guide != null && guide.containsKey('duration')) {
        return guide['duration'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error obteniendo duración del viaje: $e');
      return null;
    }
  }

  /// Actualiza solo la duración de la guía temporal existente
  static Future<void> updateTripDuration(int days) async {
    try {
      final guide = await getTemporaryGuide();
      if (guide != null) {
        guide['duration'] = {
          'days': days,
          'displayName': _getDurationDisplayName(days)
        };

        final prefs = await SharedPreferences.getInstance();
        final guideJson = jsonEncode(guide);
        await prefs.setString(_guestGuideKey, guideJson);
        print('Duración actualizada: ${guide['duration']['displayName']}');
      }
    } catch (e) {
      print('Error actualizando duración: $e');
    }
  }

  /// Obtiene el rango de días disponibles (1-7 días)
  static List<int> getAvailableDays() {
    return List.generate(7, (index) => index + 1);
  }

  /// Obtiene los días desde la guía temporal
  static Future<int?> getTripDays() async {
    try {
      final durationData = await getTripDuration();
      return durationData?['days'] as int?;
    } catch (e) {
      print('Error obteniendo días del viaje: $e');
      return null;
    }
  }
}
