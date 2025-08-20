import 'package:tourify_flutter/data/activity.dart';
import 'package:flutter/material.dart';

/// Función para determinar si una actividad es cultural
bool isCulturalActivity(Activity activity) {
  // Si la actividad tiene una categoría definida, verificar si es cultural
  if (activity.category != null) {
    return activity.category!.toLowerCase() == 'cultural';
  }

  // Si no tiene categoría, usar lógica basada en palabras clave
  // para compatibilidad con actividades existentes
  const culturalKeywords = [
    "museo",
    "museum",
    "galería",
    "gallery",
    "exposición",
    "exhibition",
    "arte",
    "art",
    "monumento",
    "monument",
    "cultural",
    "culture",
    "histórico",
    "historic",
    "patrimonio",
    "heritage",
    "teatro",
    "theatre",
    "concierto",
    "concert",
    "ópera",
    "opera",
    "catedral",
    "cathedral",
    "iglesia",
    "church",
    "palacio",
    "palace"
  ];

  final title = activity.title.toLowerCase();
  final description = activity.description.toLowerCase();

  return culturalKeywords.any(
      (keyword) => title.contains(keyword) || description.contains(keyword));
}

/// Función para determinar si una actividad es de tipo tour
bool isTourActivity(Activity activity) {
  // Si la actividad tiene una categoría definida, verificar si es tour
  if (activity.category != null) {
    return activity.category!.toLowerCase() == 'tour';
  }
  return false;
}

class ActivityUtils {
  static List<Activity> groupActivitiesByDay(List<Activity> activities) {
    // Tu implementación actual aquí
    return activities;
  }

  static List<Activity> filterActivitiesByDay(
      List<Activity> activities, int day) {
    return activities.where((activity) => activity.day == day).toList();
  }
}

class DayColors {
  // Colores para cada día
  static const List<Color> _dayColors = [
    Color(0xFF0062FF), // Día 1 - Azul
    Color(0xFFFF6B35), // Día 2 - Naranja
    Color(0xFF2ECC71), // Día 3 - Verde
    Color(0xFFE74C3C), // Día 4 - Rojo
    Color(0xFF9B59B6), // Día 5 - Morado
    Color(0xFFF39C12), // Día 6 - Amarillo
    Color(0xFF1ABC9C), // Día 7 - Turquesa
    Color(0xFFE91E63), // Día 8 - Rosa
    Color(0xFF34495E), // Día 9 - Gris oscuro
    Color(0xFF16A085), // Día 10 - Verde azulado
  ];

  /// Obtiene el color para un día específico
  static Color getColorForDay(int day) {
    return _dayColors[(day - 1) % _dayColors.length];
  }
}
