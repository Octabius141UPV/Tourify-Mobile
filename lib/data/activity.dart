import 'package:google_maps_flutter/google_maps_flutter.dart';

class Activity {
  final String id;
  final String title;
  final String description;
  final int duration; // duración en minutos
  final int day;
  final int? order;
  final List<String> images;
  final String? city;
  final String? category;
  final int likes;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? price;
  final LatLng? location;
  final double? googleRating;
  final String? googleReview;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.day,
    this.order,
    required this.images,
    this.city,
    this.category,
    required this.likes,
    this.startTime,
    this.endTime,
    this.price,
    this.location,
    this.googleRating,
    this.googleReview,
  });

  factory Activity.fromMap(Map<String, dynamic> data, String id) {
    // Soporte flexible para título
    final String title = (data['title'] ?? data['name'] ?? '').toString();
    // PRESERVAR IMÁGENES EXISTENTES - No permitir que se pierdan durante la edición
    List<String> images = [];
    if (data['images'] != null && data['images'] is List) {
      // CRÍTICO: Preservar incluso arrays vacíos - no intentar regenerar
      images = List<String>.from(data['images']);
    } else if (data['imageUrl'] != null &&
        data['imageUrl'].toString().isNotEmpty) {
      images = [data['imageUrl'].toString()];
    }
    // NO crear imágenes por defecto aquí - esto causaba el problema de cambio de imágenes
    LatLng? location;

    // PRIORIDAD 1: Buscar en 'coordinates' (nuevo formato)
    if (data['coordinates'] != null && data['coordinates'] is Map) {
      final coords = data['coordinates'];
      if (coords['latitude'] != null && coords['longitude'] != null) {
        final lat = coords['latitude'];
        final lng = coords['longitude'];
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          location = LatLng((lat as num).toDouble(), (lng as num).toDouble());
        }
      }
    }

    // PRIORIDAD 2: Buscar en 'location' (formato antiguo, compatibilidad)
    if (location == null &&
        data['location'] != null &&
        data['location'] is Map) {
      final loc = data['location'];
      if (loc['lat'] != null && loc['lng'] != null) {
        location = LatLng(
            (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
      }
    }
    return Activity(
      id: id,
      title: title,
      description: (data['description'] ?? '').toString(),
      duration: (data['duration'] is int)
          ? data['duration']
          : (data['duration'] is double)
              ? data['duration'].toInt()
              : 60,
      day: (data['day'] is int)
          ? data['day']
          : (data['day'] is double)
              ? data['day'].toInt()
              : 1,
      order: (data['order'] is int)
          ? data['order']
          : (data['order'] is double)
              ? data['order'].toInt()
              : null,
      images: images,
      city: data['city']?.toString(),
      category: data['category']?.toString(),
      likes: (data['likes'] is int)
          ? data['likes']
          : (data['likes'] is double)
              ? data['likes'].toInt()
              : 0,
      startTime: data['startTime']?.toDate(),
      endTime: data['endTime']?.toDate(),
      price: data['price']?.toString(),
      location: location,
      googleRating: data['googleRating'] != null
          ? (data['googleRating'] as num).toDouble()
          : null,
      googleReview: data['googleReview']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'duration': duration,
      'day': day,
      'order': order,
      'images': images,
      // INCLUIR imageUrl para compatibilidad si solo hay una imagen
      'imageUrl': images.isNotEmpty ? images.first : null,
      'city': city,
      'category': category,
      'likes': likes,
      'startTime': startTime,
      'endTime': endTime,
      'price': price,
      // Coordenadas en formato nuevo (preferido)
      'coordinates': location != null
          ? {'latitude': location!.latitude, 'longitude': location!.longitude}
          : null,
      // Coordenadas en formato antiguo (compatibilidad)
      'location': location != null
          ? {'lat': location!.latitude, 'lng': location!.longitude}
          : null,
      'googleRating': googleRating,
      'googleReview': googleReview,
    };
  }
}

class DayActivities {
  final int dayNumber;
  final List<Activity> activities;

  DayActivities({
    required this.dayNumber,
    required this.activities,
  });
}
