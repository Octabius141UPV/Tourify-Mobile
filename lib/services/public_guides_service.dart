import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourify_flutter/config/api_config.dart';

class PublicGuidesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Registra una vista de guía pública usando el endpoint del backend
  /// Incrementa el contador de views y guarda el userRef como viewer
  static Future<void> registerPublicGuideView(String guideId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Usuario no autenticado, no se puede registrar vista');
        return;
      }

      // Obtener el token de autenticación
      final token = await user.getIdToken();

      print('Registrando vista para guía: $guideId');
      ApiConfig.printConfig();

      // Llamar al endpoint del backend
      final response = await http.post(
        Uri.parse(ApiConfig.getPublicGuideViewUrl(guideId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Respuesta del servidor: ${response.statusCode}');
      print('Cuerpo de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Vista de guía pública registrada correctamente');
        } else {
          print('Error al registrar vista: ${data['message']}');
        }
      } else {
        print('Error HTTP al registrar vista: ${response.statusCode}');
        print('Respuesta: ${response.body}');
      }
    } catch (e) {
      print('Error al registrar vista de guía pública: $e');
    }
  }

  /// Obtiene el número de vistas de una guía pública
  static Future<int> getPublicGuideViewCount(String guideId) async {
    try {
      print('Obteniendo contador de vistas para guía: $guideId');
      ApiConfig.printConfig();

      final response = await http.get(
        Uri.parse(ApiConfig.getPublicGuideViewsUrl(guideId)),
      );

      print('Respuesta del servidor: ${response.statusCode}');
      print('Cuerpo de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final viewCount = data['viewCount'] ?? 0;
          print('Contador de vistas obtenido: $viewCount');
          return viewCount;
        }
      }

      print('No se pudo obtener el contador de vistas');
      return 0;
    } catch (e) {
      print('Error al obtener contador de vistas: $e');
      return 0;
    }
  }

  /// Obtiene las 4 guías públicas con más vistas
  static Future<List<Map<String, dynamic>>> getTopRatedPublicGuides(
      {int limit = 4}) async {
    try {
      final querySnapshot = await _firestore
          .collection('guides')
          .orderBy('views', descending: true)
          .where('isPublic', isEqualTo: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> guides = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // Obtener días y actividades de la subcolección 'days'
        final daysSnapshot = await _firestore
            .collection('guides')
            .doc(doc.id)
            .collection('days')
            .get();

        int totalDays = daysSnapshot.docs.length;
        int totalActivities = 0;
        for (final dayDoc in daysSnapshot.docs) {
          final dayData = dayDoc.data();
          if (dayData['activities'] is List) {
            totalActivities += (dayData['activities'] as List).length;
          }
        }

        guides.add({
          'id': doc.id,
          'title': data['title'] ?? 'Sin título',
          'author': data['author'] ?? 'Autor desconocido',
          'userRef': data['userRef'],
          'userId': data['userId'],
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'rating': (data['rating'] ?? 0.0).toDouble(),
          'duration': totalDays > 0
              ? '$totalDays día${totalDays == 1 ? '' : 's'}'
              : 'Duración no especificada',
          'activities': totalActivities,
          'city': data['city'] ?? '',
          'description': data['description'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'createdAt': data['createdAt'],
          'isPublic': data['isPublic'] ?? true,
          'views': data['views'] ?? 0,
        });
      }

      return guides;
    } catch (e) {
      print('Error fetching top viewed public guides: $e');
      // Retornar datos de fallback en caso de error
      return _getFallbackGuides();
    }
  }

  /// Datos de fallback en caso de que no se puedan cargar desde Firestore
  static List<Map<String, dynamic>> _getFallbackGuides() {
    return [
      {
        'id': 'fallback_1',
        'title': 'Fin de semana en París',
        'author': 'María García',
        'rating': 4.8,
        'duration': '3 días',
        'activities': 12,
        'city': 'París',
        'description':
            'Una guía completa para disfrutar París en un fin de semana',
        'imageUrl': '',
        'isPublic': true,
      },
      {
        'id': 'fallback_2',
        'title': 'Ruta por Berlín',
        'author': 'Juan Pérez',
        'rating': 4.5,
        'duration': '5 días',
        'activities': 18,
        'city': 'Berlín',
        'description': 'Descubre la historia y cultura de Berlín',
        'imageUrl': '',
        'isPublic': true,
      },
      {
        'id': 'fallback_3',
        'title': 'Budapest en 4 días',
        'author': 'Ana Martínez',
        'rating': 4.9,
        'duration': '4 días',
        'activities': 15,
        'city': 'Budapest',
        'description': 'La perla del Danubio te espera',
        'imageUrl': '',
        'isPublic': true,
      },
      {
        'id': 'fallback_4',
        'title': 'Roma Clásica',
        'author': 'Carlos Rodríguez',
        'rating': 4.7,
        'duration': '4 días',
        'activities': 16,
        'city': 'Roma',
        'description': 'Descubre la ciudad eterna',
        'imageUrl': '',
        'isPublic': true,
      },
    ];
  }

  /// Búsqueda de guías públicas por texto
  static Future<List<Map<String, dynamic>>> searchPublicGuides(
      String query) async {
    try {
      if (query.isEmpty) {
        return await getTopRatedPublicGuides(limit: 10);
      }

      // Búsqueda por título (Firestore no tiene búsqueda de texto completo nativa)
      final querySnapshot = await _firestore
          .collection('PublicGuides')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .orderBy('title')
          .orderBy('rating', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> results = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Sin título',
          'author': data['author'] ?? 'Autor desconocido',
          'rating': (data['rating'] ?? 0.0).toDouble(),
          'duration': data['duration'] ?? 'Duración no especificada',
          'activities': data['activities'] ?? 0,
          'city': data['city'] ?? '',
          'description': data['description'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'createdAt': data['createdAt'],
          'isPublic': data['isPublic'] ?? true,
        };
      }).toList();

      // Si no hay resultados por título, buscar por ciudad
      if (results.isEmpty) {
        final cityQuerySnapshot = await _firestore
            .collection('PublicGuides')
            .where('city', isGreaterThanOrEqualTo: query)
            .where('city', isLessThanOrEqualTo: '$query\uf8ff')
            .orderBy('city')
            .orderBy('rating', descending: true)
            .limit(10)
            .get();

        results = cityQuerySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Sin título',
            'author': data['author'] ?? 'Autor desconocido',
            'rating': (data['rating'] ?? 0.0).toDouble(),
            'duration': data['duration'] ?? 'Duración no especificada',
            'activities': data['activities'] ?? 0,
            'city': data['city'] ?? '',
            'description': data['description'] ?? '',
            'imageUrl': data['imageUrl'] ?? '',
            'createdAt': data['createdAt'],
            'isPublic': data['isPublic'] ?? true,
          };
        }).toList();
      }

      return results;
    } catch (e) {
      print('Error searching public guides: $e');
      return [];
    }
  }

  /// Obtiene una guía pública específica por ID
  static Future<Map<String, dynamic>?> getPublicGuideById(
      String guideId) async {
    try {
      final doc =
          await _firestore.collection('PublicGuides').doc(guideId).get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Sin título',
          'author': data['author'] ?? 'Autor desconocido',
          'rating': (data['rating'] ?? 0.0).toDouble(),
          'duration': data['duration'] ?? 'Duración no especificada',
          'activities': data['activities'] ?? 0,
          'city': data['city'] ?? '',
          'description': data['description'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'createdAt': data['createdAt'],
          'isPublic': data['isPublic'] ?? true,
        };
      }

      return null;
    } catch (e) {
      print('Error fetching public guide by ID: $e');
      return null;
    }
  }
}
