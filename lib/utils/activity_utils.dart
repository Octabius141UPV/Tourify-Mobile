import '../data/activity.dart';

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
