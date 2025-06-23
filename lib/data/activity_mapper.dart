import 'package:tourify_flutter/data/mock_activities.dart';

class ActivityMapper {
  // Convertir actividad del API a la clase Activity local
  static Activity fromApiToLocal(Map<String, dynamic> apiActivity) {
    return Activity(
      id: apiActivity['_id'] ?? apiActivity['id'] ?? '',
      name: apiActivity['title'] ?? apiActivity['name'] ?? '',
      description: apiActivity['description'] ?? '',
      imageUrl: _getFirstImage(apiActivity),
      rating: _parseRating(apiActivity),
      reviews: apiActivity['reviewCount'] ?? apiActivity['likes'] ?? 0,
      category: apiActivity['category'] ?? 'Turismo',
      price: _parsePrice(apiActivity),
      duration: _parseDuration(apiActivity),
      tags: _parseTags(apiActivity),
    );
  }

  // Convertir lista de actividades del API a lista local
  static List<Activity> fromApiListToLocal(List<dynamic> apiActivities) {
    return apiActivities.map((activity) => fromApiToLocal(activity)).toList();
  }

  // Convertir actividad local a formato para enviar al API
  static Map<String, dynamic> fromLocalToApi(Activity activity) {
    return {
      'id': activity.id,
      'title': activity.name,
      'description': activity.description,
      'image': activity.imageUrl,
      'category': activity.category,
      'value': 1, // Valor positivo para actividades aceptadas
    };
  }

  // Obtener primera imagen o imagen por defecto
  static String _getFirstImage(Map<String, dynamic> activity) {
    if (activity['images'] != null &&
        activity['images'] is List &&
        (activity['images'] as List).isNotEmpty) {
      return activity['images'][0];
    } else if (activity['image'] != null && activity['image'] is String) {
      return activity['image'];
    }
    return 'https://via.placeholder.com/150';
  }

  // Convertir rating a double
  static double _parseRating(Map<String, dynamic> activity) {
    if (activity['rating'] != null) {
      return (activity['rating'] is int)
          ? (activity['rating'] as int).toDouble()
          : activity['rating'] as double;
    }
    return 4.5; // Valor por defecto
  }

  // Convertir precio a double
  static double _parsePrice(Map<String, dynamic> activity) {
    if (activity['price'] != null) {
      if (activity['price'] is int) {
        return (activity['price'] as int).toDouble();
      } else if (activity['price'] is double) {
        return activity['price'];
      } else if (activity['price'] is String) {
        return double.tryParse(activity['price']) ?? 0.0;
      }
    }
    return 0.0; // Valor por defecto
  }

  // Convertir duración a int (en minutos)
  static int _parseDuration(Map<String, dynamic> activity) {
    if (activity['duration'] != null) {
      if (activity['duration'] is int) {
        return activity['duration'];
      } else if (activity['duration'] is double) {
        return (activity['duration'] as double).round();
      } else if (activity['duration'] is String) {
        return int.tryParse(activity['duration']) ?? 120;
      }
    }
    return 120; // Valor por defecto: 2 horas
  }

  // Extraer tags
  static List<String> _parseTags(Map<String, dynamic> activity) {
    if (activity['tags'] != null && activity['tags'] is List) {
      return (activity['tags'] as List).map((tag) => tag.toString()).toList();
    }
    // Generar tags a partir de la categoría si no hay tags
    if (activity['category'] != null) {
      return [activity['category']];
    }
    return ['Turismo']; // Tag por defecto
  }
}
