import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourify_flutter/data/mock_activities.dart';
import 'package:tourify_flutter/services/auth_service.dart';

class GuideService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new guide for authenticated users
  static Future<String?> createGuide({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required List<Activity> selectedActivities,
    List<Activity>? rejectedActivities,
    int travelers = 1,
    List<String> travelModes = const [
      'cultura',
      'fiesta'
    ], // Añadir estilos de viaje
    bool isPublic = false, // Nuevo parámetro para indicar si debe ser pública
    String? guideName,
    String? guideDescription,
  }) async {
    try {
      if (!AuthService.isAuthenticated) {
        throw Exception('User must be authenticated to create a guide');
      }

      final String userId = AuthService.userId!;

      // Create the guide document
      final guideRef = await _firestore.collection('guides').add({
        'title':
            guideName?.isNotEmpty == true ? guideName : 'Guía de $destination',
        'name':
            guideName?.isNotEmpty == true ? guideName : 'Guía de $destination',
        'description':
            guideDescription?.isNotEmpty == true ? guideDescription : null,
        'city': destination,
        'destination': destination,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'travelers': travelers, // Guardar número de viajeros
        'travelModes': travelModes, // Guardar estilos de viaje
        'userRef': _firestore.collection('users').doc(userId),
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'draft',
        'views': 0,
        'isPublic': isPublic, // Usar el parámetro isPublic
        'selectedActivities': selectedActivities
            .map((activity) => {
                  'id': activity.id,
                  'name': activity.name,
                  'description': activity.description,
                  'imageUrl': activity.imageUrl,
                  'rating': activity.rating,
                  'reviews': activity.reviews,
                  'category': activity.category,
                  'price': activity.price,
                  'duration': activity.duration,
                  'tags': activity.tags,
                })
            .toList(),
        'rejectedActivities': rejectedActivities
                ?.map((activity) => {
                      'id': activity.id,
                      'name': activity.name,
                      'category': activity.category,
                    })
                .toList() ??
            [],
        'totalActivities': selectedActivities.length,
      });

      // Create initial days for the guide
      await _createGuideDays(
          guideRef.id, startDate, endDate, selectedActivities);

      // Si la guía debe ser pública, también crearla en la colección PublicGuides
      if (isPublic) {
        await _publishToPublicGuides(
          guideRef.id,
          destination,
          startDate,
          endDate,
          selectedActivities,
          travelers,
          travelModes,
          userId,
        );
      }

      return guideRef.id;
    } catch (e) {
      print('Error creating guide: $e');
      return null;
    }
  }

  // Create guide days with activities distributed across them
  static Future<void> _createGuideDays(
    String guideId,
    DateTime startDate,
    DateTime endDate,
    List<Activity> activities,
  ) async {
    try {
      final days = _getDaysBetweenDates(startDate, endDate);
      final activitiesPerDay = (activities.length / days.length).ceil();

      for (int i = 0; i < days.length; i++) {
        final startIndex = i * activitiesPerDay;
        final endIndex =
            (startIndex + activitiesPerDay).clamp(0, activities.length);
        final dayActivities = activities.sublist(startIndex, endIndex);

        await _firestore
            .collection('guides')
            .doc(guideId)
            .collection('days')
            .doc((i + 1)
                .toString()) // Usar el número de día como ID del documento
            .set({
          'date': Timestamp.fromDate(days[i]),
          'dayNumber': i + 1,
          'activities': dayActivities
              .map((activity) => {
                    'id': activity.id,
                    'name': activity.name,
                    'description': activity.description,
                    'imageUrl': activity.imageUrl,
                    'rating': activity.rating,
                    'reviews': activity.reviews,
                    'category': activity.category,
                    'price': activity.price,
                    'duration': activity.duration,
                    'tags': activity.tags,
                    'order': dayActivities.indexOf(activity),
                  })
              .toList(),
          'totalDuration': dayActivities.fold<int>(
            0,
            (sum, activity) => sum + activity.duration,
          ),
          'totalPrice': dayActivities.fold<double>(
            0.0,
            (sum, activity) => sum + activity.price,
          ),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating guide days: $e');
    }
  }

  // Get days between two dates
  static List<DateTime> _getDaysBetweenDates(
      DateTime startDate, DateTime endDate) {
    final List<DateTime> days = [];
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final DateTime end = DateTime(endDate.year, endDate.month, endDate.day);

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  // Get user's guides
  static Future<List<Map<String, dynamic>>> getUserGuides() async {
    try {
      if (!AuthService.isAuthenticated) {
        return [];
      }

      final String userId = AuthService.userId!;
      final querySnapshot = await _firestore
          .collection('guides')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error fetching user guides: $e');
      return [];
    }
  }

  // Get guide by ID
  static Future<Map<String, dynamic>?> getGuideById(String guideId) async {
    try {
      final doc = await _firestore.collection('guides').doc(guideId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      print('Error fetching guide: $e');
      return null;
    }
  }

  // Get guide days
  static Future<List<Map<String, dynamic>>> getGuideDays(String guideId) async {
    try {
      final querySnapshot = await _firestore
          .collection('guides')
          .doc(guideId)
          .collection('days')
          .orderBy('dayNumber')
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error fetching guide days: $e');
      return [];
    }
  }

  // Update guide visibility
  static Future<bool> updateGuideVisibility(
      String guideId, bool isPublic) async {
    try {
      await _firestore.collection('guides').doc(guideId).update({
        'isPublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating guide visibility: $e');
      return false;
    }
  }

  // Delete guide
  static Future<bool> deleteGuide(String guideId) async {
    try {
      // Delete all days first
      final daysSnapshot = await _firestore
          .collection('guides')
          .doc(guideId)
          .collection('days')
          .get();

      for (final dayDoc in daysSnapshot.docs) {
        await dayDoc.reference.delete();
      }

      // Delete the guide
      await _firestore.collection('guides').doc(guideId).delete();
      return true;
    } catch (e) {
      print('Error deleting guide: $e');
      return false;
    }
  }

  // Publish guide to PublicGuides collection
  static Future<void> _publishToPublicGuides(
    String guideId,
    String destination,
    DateTime startDate,
    DateTime endDate,
    List<Activity> selectedActivities,
    int travelers,
    List<String> travelModes,
    String userId,
  ) async {
    try {
      // Obtener información del usuario para el autor
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final authorName =
          userData?['name'] ?? userData?['displayName'] ?? 'Usuario anónimo';

      // Calcular duración en días
      final duration = endDate.difference(startDate).inDays + 1;

      // Crear entrada en PublicGuides
      await _firestore.collection('PublicGuides').doc(guideId).set({
        'title': 'Guía de $destination',
        'author': authorName,
        'authorId': userId,
        'city': destination,
        'description':
            'Guía de $duration días para $destination con ${selectedActivities.length} actividades',
        'rating': 4.5, // Rating inicial por defecto
        'duration': '$duration ${duration == 1 ? 'día' : 'días'}',
        'activities': selectedActivities.length,
        'travelers': travelers,
        'travelModes': travelModes,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdAt': FieldValue.serverTimestamp(),
        'guideRef': guideId, // Referencia a la guía original
        'imageUrl': selectedActivities.isNotEmpty
            ? selectedActivities.first.imageUrl
            : '',
        'tags': selectedActivities
            .expand((activity) => activity.tags)
            .toSet()
            .toList(),
        'categories': selectedActivities
            .map((activity) => activity.category)
            .toSet()
            .toList(),
        'views': 0,
        'likes': 0,
      });

      print('Guía publicada exitosamente en PublicGuides con ID: $guideId');
    } catch (e) {
      print('Error al publicar guía en PublicGuides: $e');
      // No lanzamos el error para no interrumpir la creación de la guía principal
    }
  }

  // Search public guides (guides with isPublic: true)
  static Future<List<Map<String, dynamic>>> searchPublicGuides(
      String query) async {
    try {
      if (query.isEmpty) {
        return await getTopPublicGuides(limit: 10);
      }

      // Obtener todas las guías públicas para filtrar en el cliente
      // Esto es necesario porque Firestore no tiene búsqueda de texto completo nativa
      final querySnapshot = await _firestore
          .collection('guides')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(100) // Limitamos a 100 para evitar sobrecarga
          .get();

      List<Map<String, dynamic>> allGuides = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final userDoc =
            await _firestore.collection('users').doc(data['userId']).get();
        final userData = userDoc.data();
        final authorName =
            userData?['name'] ?? userData?['displayName'] ?? 'Usuario anónimo';

        // Calcular duración basada en fechas
        int totalDays = 0;
        if (data['startDate'] != null && data['endDate'] != null) {
          final startDate = (data['startDate'] as Timestamp).toDate();
          final endDate = (data['endDate'] as Timestamp).toDate();
          totalDays = endDate.difference(startDate).inDays + 1;
        }

        // Obtener días y actividades de la subcolección 'days'
        final daysSnapshot = await _firestore
            .collection('guides')
            .doc(doc.id)
            .collection('days')
            .get();

        if (totalDays == 0) {
          totalDays = daysSnapshot.docs.length;
        }

        int totalActivities = 0;
        for (final dayDoc in daysSnapshot.docs) {
          final dayData = dayDoc.data();
          if (dayData['activities'] is List) {
            totalActivities += (dayData['activities'] as List).length;
          }
        }

        allGuides.add({
          'id': doc.id,
          'title': data['title'] ?? 'Sin título',
          'author': authorName,
          'rating': 4.5, // Rating por defecto, puedes cambiarlo
          'city': data['city'] ?? data['destination'] ?? '',
          'destination': data['destination'] ?? data['city'] ?? '',
          'description': data['description'] ??
              'Guía de viaje para ${data['destination'] ?? data['city'] ?? 'destino'}',
          'imageUrl': '',
          'createdAt': data['createdAt'],
          'isPublic': data['isPublic'] ?? false,
          'duration': totalDays > 0
              ? '$totalDays día${totalDays == 1 ? '' : 's'}'
              : 'Duración no especificada',
          'activities': totalActivities,
          'totalDays': totalDays,
        });
      }

      // Filtrar por contenido (búsqueda que "contiene" el término)
      final lowerQuery = query.toLowerCase();
      final results = allGuides.where((guide) {
        final title = (guide['title'] ?? '').toString().toLowerCase();
        final city = (guide['city'] ?? '').toString().toLowerCase();
        final destination =
            (guide['destination'] ?? '').toString().toLowerCase();
        final author = (guide['author'] ?? '').toString().toLowerCase();
        final description =
            (guide['description'] ?? '').toString().toLowerCase();

        // Busca el término en título, ciudad, destino, autor o descripción
        return title.contains(lowerQuery) ||
            city.contains(lowerQuery) ||
            destination.contains(lowerQuery) ||
            author.contains(lowerQuery) ||
            description.contains(lowerQuery);
      }).toList();

      // Ordenar resultados por relevancia (primero por título, luego por ciudad)
      results.sort((a, b) {
        final aTitle = (a['title'] ?? '').toString().toLowerCase();
        final bTitle = (b['title'] ?? '').toString().toLowerCase();
        final aCity = (a['city'] ?? '').toString().toLowerCase();
        final bCity = (b['city'] ?? '').toString().toLowerCase();

        // Prioridad: título que contiene la búsqueda
        final aTitleMatch = aTitle.contains(lowerQuery);
        final bTitleMatch = bTitle.contains(lowerQuery);

        if (aTitleMatch && !bTitleMatch) return -1;
        if (!aTitleMatch && bTitleMatch) return 1;

        // Después por ciudad
        final aCityMatch = aCity.contains(lowerQuery);
        final bCityMatch = bCity.contains(lowerQuery);

        if (aCityMatch && !bCityMatch) return -1;
        if (!aCityMatch && bCityMatch) return 1;

        return 0; // Mantener orden original si ambos tienen la misma relevancia
      });

      // Limitar resultados finales
      return results.take(10).toList();
    } catch (e) {
      print('Error searching public guides: $e');
      return [];
    }
  }

  // Get top public guides - Guías predefinidas
  static Future<List<Map<String, dynamic>>> getTopPublicGuides(
      {int limit = 10}) async {
    try {
      // Devolver 4 guías predefinidas de Berlín, Budapest, Roma y Milán
      return [
        {
          'id': 'predefined_berlin',
          'title': 'Berlín en 3 días',
          'author': 'Equipo Tourify',
          'city': 'Berlín',
          'destination': 'Berlín',
          'description':
              'Descubre la vibrante capital alemana con historia, cultura y vida nocturna',
          'imageUrl':
              'https://images.unsplash.com/photo-1597932552386-ad91621e4c8a?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
          'createdAt': DateTime.now(),
          'isPublic': true,
          'duration': '3 días',
          'activities': 9,
          'totalDays': 3,
          'views': 0,
        },
        {
          'id': 'predefined_budapest',
          'title': 'Budapest, la perla del Danubio',
          'author': 'Equipo Tourify',
          'city': 'Budapest',
          'destination': 'Budapest',
          'description':
              'Explora los baños termales, el Parlamento y los barrios históricos',
          'imageUrl':
              'https://images.unsplash.com/photo-1541849546-216549ae216d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
          'createdAt': DateTime.now(),
          'isPublic': true,
          'duration': '4 días',
          'activities': 11,
          'totalDays': 4,
          'views': 0,
        },
        {
          'id': 'predefined_rome',
          'title': 'Roma eterna',
          'author': 'Equipo Tourify',
          'city': 'Roma',
          'destination': 'Roma',
          'description':
              'Sumérgete en la historia antigua del Coliseo, Vaticano y Fontana de Trevi',
          'imageUrl':
              'https://images.unsplash.com/photo-1552832230-c0197dd311b5?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
          'createdAt': DateTime.now(),
          'isPublic': true,
          'duration': '5 días',
          'activities': 15,
          'totalDays': 5,
          'views': 0,
        },
        {
          'id': 'predefined_milan',
          'title': 'Milán, moda y cultura',
          'author': 'Equipo Tourify',
          'city': 'Milán',
          'destination': 'Milán',
          'description':
              'Desde el Duomo hasta la Scala, la elegancia italiana te espera',
          'imageUrl':
              'https://images.unsplash.com/photo-1610016302534-6f67f1c968d8?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
          'createdAt': DateTime.now(),
          'isPublic': true,
          'duration': '3 días',
          'activities': 8,
          'totalDays': 3,
          'views': 0,
        },
      ].take(limit).toList();
    } catch (e) {
      print('Error fetching predefined guides: $e');
      return [];
    }
  }

  // Método para obtener datos mockeados completos de guías predefinidas
  static Map<String, dynamic>? getMockedGuideDetails(String guideId) {
    switch (guideId) {
      case 'predefined_berlin':
        return {
          'id': 'predefined_berlin',
          'title': 'Berlín en 3 días',
          'city': 'Berlín',
          'destination': 'Berlín',
          'author': 'Equipo Tourify',
          'description':
              'Descubre la vibrante capital alemana con historia, cultura y vida nocturna',
          'isPublic': true,
          'isOwner': false,
          'days': [
            {
              'dayNumber': 1,
              'activities': [
                {
                  'id': 'berlin_1_1',
                  'title': 'Puerta de Brandenburgo',
                  'description':
                      'Icónico símbolo de Berlín y punto de partida perfecto para explorar la ciudad',
                  'duration': 60,
                  'category': 'monument',
                  'city': 'Berlín',
                  'images': [
                    'https://images.unsplash.com/photo-1587330979470-3595b84de63e?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'berlin_1_2',
                  'title': 'Reichstag',
                  'description':
                      'Parlamento alemán con su impresionante cúpula de cristal y vistas panorámicas',
                  'duration': 90,
                  'category': 'cultural',
                  'city': 'Berlín',
                  'images': [
                    'https://images.unsplash.com/photo-1539650116574-75c0c6d73d0e?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'berlin_1_3',
                  'title': 'Unter den Linden',
                  'description':
                      'Famosa avenida histórica perfecta para pasear y descubrir la arquitectura berlinesa',
                  'duration': 120,
                  'category': 'tour',
                  'city': 'Berlín',
                  'images': [
                    'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 2,
              'activities': [
                {
                  'id': 'berlin_2_1',
                  'title': 'Muro de Berlín',
                  'description':
                      'Resto histórico del muro que dividió la ciudad, ahora convertido en galería de arte al aire libre',
                  'duration': 120,
                  'category': 'monument',
                  'city': 'Berlín',
                  'images': [
                    'https://images.unsplash.com/photo-1590736969955-71cc94901144?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'berlin_2_2',
                  'title': 'Checkpoint Charlie',
                  'description':
                      'Famoso puesto fronterizo de la Guerra Fría, símbolo de la división alemana',
                  'duration': 60,
                  'category': 'cultural',
                  'city': 'Berlín',
                  'images': [
                    'https://images.unsplash.com/photo-1562832135-14a35d25edef?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'berlin_2_3',
                  'title': 'Isla de los Museos',
                  'description':
                      'Complejo de museos con arte y cultura mundial, Patrimonio de la Humanidad',
                  'duration': 180,
                  'category': 'museum',
                  'city': 'Berlín',
                  'images': [
                    'https://images.unsplash.com/photo-1529260830199-42c24126f198?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 3,
              'activities': [
                {
                  'id': 'berlin_3_1',
                  'title': 'Torre de TV de Berlín',
                  'description':
                      'Vistas panorámicas de toda la ciudad desde 368 metros de altura',
                  'duration': 90,
                  'category': 'sightseeing',
                  'city': 'Berlín',
                  'images': [
                    'https://images.unsplash.com/photo-1566403283473-cb3b16046abe?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'berlin_3_2',
                  'title': 'Alexanderplatz',
                  'description':
                      'Plaza principal con ambiente vibrante, perfecta para compras y vida urbana',
                  'duration': 120,
                  'category': 'shopping',
                  'city': 'Berlín',
                  'images': [
                    'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'berlin_3_3',
                  'title': 'Barrio de Prenzlauer Berg',
                  'description':
                      'Zona bohemia con cafés auténticos, galerías de arte y vida local berlinesa',
                  'duration': 150,
                  'category': 'tour',
                  'city': 'Berlín',
                  'images': [
                    'https://images.unsplash.com/photo-1527838832700-5059252407fa?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
          ],
        };

      case 'predefined_budapest':
        return {
          'id': 'predefined_budapest',
          'title': 'Budapest, la perla del Danubio',
          'city': 'Budapest',
          'destination': 'Budapest',
          'author': 'Equipo Tourify',
          'description':
              'Explora los baños termales, el Parlamento y los barrios históricos',
          'isPublic': true,
          'isOwner': false,
          'days': [
            {
              'dayNumber': 1,
              'activities': [
                {
                  'id': 'budapest_1_1',
                  'title': 'Parlamento Húngaro',
                  'description':
                      'Majestuoso edificio gótico a orillas del Danubio, símbolo de Budapest',
                  'duration': 90,
                  'category': 'monument',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1541849546-216549ae216d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'budapest_1_2',
                  'title': 'Basílica de San Esteban',
                  'description':
                      'Impresionante basílica neoclásica con cúpula panorámica y vistas espectaculares',
                  'duration': 60,
                  'category': 'cultural',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1580658769020-f2547b80b0d3?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'budapest_1_3',
                  'title': 'Mercado Central',
                  'description':
                      'Mercado histórico con productos locales, artesanías húngaras y gastronomía típica',
                  'duration': 90,
                  'category': 'shopping',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1578662996442-48f60103fc96?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 2,
              'activities': [
                {
                  'id': 'budapest_2_1',
                  'title': 'Castillo de Buda',
                  'description':
                      'Palacio real con vistas espectaculares de la ciudad y museos fascinantes',
                  'duration': 120,
                  'category': 'monument',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1571579234835-6fa0e4e8c2e7?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'budapest_2_2',
                  'title': 'Bastión de los Pescadores',
                  'description':
                      'Terraza neogótica con las mejores vistas panorámicas de Budapest',
                  'duration': 60,
                  'category': 'sightseeing',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1578915503866-63ce536c5e73?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'budapest_2_3',
                  'title': 'Iglesia de Matías',
                  'description':
                      'Hermosa iglesia gótica en el distrito del Castillo con arquitectura única',
                  'duration': 45,
                  'category': 'cultural',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1578052047153-0e7845c8b9d9?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 3,
              'activities': [
                {
                  'id': 'budapest_3_1',
                  'title': 'Balneario Széchenyi',
                  'description':
                      'Famosos baños termales al aire libre, perfectos para relajarse',
                  'duration': 180,
                  'category': 'outdoor',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1571747486840-f8dbf2a491ce?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'budapest_3_2',
                  'title': 'Avenida Váci',
                  'description':
                      'Principal calle peatonal con tiendas elegantes y restaurantes tradicionales',
                  'duration': 90,
                  'category': 'shopping',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1578915503866-63ce536c5e73?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 4,
              'activities': [
                {
                  'id': 'budapest_4_1',
                  'title': 'Crucero por el Danubio',
                  'description':
                      'Navegación relajante con vistas de ambas orillas y monumentos iluminados',
                  'duration': 120,
                  'category': 'tour',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1541849546-216549ae216d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'budapest_4_2',
                  'title': 'Ruin Bars',
                  'description':
                      'Emblemáticos bares en edificios abandonados, únicos en el mundo',
                  'duration': 120,
                  'category': 'nightlife',
                  'city': 'Budapest',
                  'images': [
                    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
          ],
        };

      case 'predefined_rome':
        return {
          'id': 'predefined_rome',
          'title': 'Roma eterna',
          'city': 'Roma',
          'destination': 'Roma',
          'author': 'Equipo Tourify',
          'description':
              'Sumérgete en la historia antigua del Coliseo, Vaticano y Fontana de Trevi',
          'isPublic': true,
          'isOwner': false,
          'days': [
            {
              'dayNumber': 1,
              'activities': [
                {
                  'id': 'rome_1_1',
                  'title': 'Coliseo Romano',
                  'description':
                      'El anfiteatro más famoso del mundo antiguo, símbolo del Imperio Romano',
                  'duration': 120,
                  'category': 'monument',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1552832230-c0197dd311b5?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_1_2',
                  'title': 'Foro Romano',
                  'description':
                      'Centro de la vida pública en la antigua Roma, ruinas fascinantes',
                  'duration': 90,
                  'category': 'cultural',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_1_3',
                  'title': 'Monte Palatino',
                  'description':
                      'Cuna legendaria de Roma con vistas panorámicas y restos imperiales',
                  'duration': 60,
                  'category': 'monument',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1529260830199-42c24126f198?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 2,
              'activities': [
                {
                  'id': 'rome_2_1',
                  'title': 'Ciudad del Vaticano',
                  'description':
                      'Estado independiente con la Capilla Sixtina y arte renacentista',
                  'duration': 180,
                  'category': 'cultural',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1578662996442-48f60103fc96?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_2_2',
                  'title': 'Basílica de San Pedro',
                  'description':
                      'La iglesia más grande del cristianismo con la cúpula de Miguel Ángel',
                  'duration': 90,
                  'category': 'monument',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_2_3',
                  'title': 'Castel Sant\'Angelo',
                  'description':
                      'Fortaleza cilíndrica a orillas del Tíber con historia milenaria',
                  'duration': 60,
                  'category': 'monument',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1552832230-c0197dd311b5?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 3,
              'activities': [
                {
                  'id': 'rome_3_1',
                  'title': 'Fontana de Trevi',
                  'description':
                      'La fuente barroca más famosa del mundo, perfecta para pedir deseos',
                  'duration': 45,
                  'category': 'monument',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1552832230-c0197dd311b5?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_3_2',
                  'title': 'Plaza de España',
                  'description':
                      'Escalinata famosa y ambiente elegante, perfecta para fotos',
                  'duration': 60,
                  'category': 'sightseeing',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_3_3',
                  'title': 'Panteón',
                  'description':
                      'Templo romano perfectamente conservado con cúpula impresionante',
                  'duration': 45,
                  'category': 'monument',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1529260830199-42c24126f198?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 4,
              'activities': [
                {
                  'id': 'rome_4_1',
                  'title': 'Villa Borghese',
                  'description':
                      'Parque y galería con arte espectacular y naturaleza en el centro',
                  'duration': 120,
                  'category': 'museum',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_4_2',
                  'title': 'Trastevere',
                  'description':
                      'Barrio bohemio con auténtica vida romana y restaurantes tradicionales',
                  'duration': 120,
                  'category': 'tour',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_4_3',
                  'title': 'Campo de\' Fiori',
                  'description':
                      'Mercado matutino vibrante y vida nocturna auténtica',
                  'duration': 90,
                  'category': 'food',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 5,
              'activities': [
                {
                  'id': 'rome_5_1',
                  'title': 'Termas de Caracalla',
                  'description':
                      'Ruinas impresionantes de los antiguos baños romanos',
                  'duration': 90,
                  'category': 'monument',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1529260830199-42c24126f198?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_5_2',
                  'title': 'Plaza Navona',
                  'description':
                      'Plaza barroca con fuentes espectaculares y ambiente artístico',
                  'duration': 60,
                  'category': 'sightseeing',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1578662996442-48f60103fc96?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'rome_5_3',
                  'title': 'Aventino y Ojo de la Cerradura',
                  'description':
                      'Vista secreta de la cúpula de San Pedro a través de una cerradura',
                  'duration': 60,
                  'category': 'sightseeing',
                  'city': 'Roma',
                  'images': [
                    'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
          ],
        };

      case 'predefined_milan':
        return {
          'id': 'predefined_milan',
          'title': 'Milán, moda y cultura',
          'city': 'Milán',
          'destination': 'Milán',
          'author': 'Equipo Tourify',
          'description':
              'Desde el Duomo hasta la Scala, la elegancia italiana te espera',
          'isPublic': true,
          'isOwner': false,
          'days': [
            {
              'dayNumber': 1,
              'activities': [
                {
                  'id': 'milan_1_1',
                  'title': 'Duomo de Milán',
                  'description':
                      'Catedral gótica con espectaculares agujas y terrazas panorámicas',
                  'duration': 120,
                  'category': 'monument',
                  'city': 'Milán',
                  'images': [
                    'https://images.unsplash.com/photo-1513581166391-887a96ddeafd?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'milan_1_2',
                  'title': 'Galleria Vittorio Emanuele II',
                  'description':
                      'Elegante galería comercial del siglo XIX, símbolo del lujo milanés',
                  'duration': 60,
                  'category': 'shopping',
                  'city': 'Milán',
                  'images': [
                    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'milan_1_3',
                  'title': 'Teatro La Scala',
                  'description':
                      'El teatro de ópera más famoso del mundo, templo de la música',
                  'duration': 90,
                  'category': 'cultural',
                  'city': 'Milán',
                  'images': [
                    'https://images.unsplash.com/photo-1578662996442-48f60103fc96?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 2,
              'activities': [
                {
                  'id': 'milan_2_1',
                  'title': 'Castillo Sforzesco',
                  'description':
                      'Fortaleza medieval con museos fascinantes y patios históricos',
                  'duration': 90,
                  'category': 'monument',
                  'city': 'Milán',
                  'images': [
                    'https://images.unsplash.com/photo-1529260830199-42c24126f198?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'milan_2_2',
                  'title': 'Parque Sempione',
                  'description':
                      'Gran parque urbano perfecto para relajarse en el corazón de Milán',
                  'duration': 60,
                  'category': 'outdoor',
                  'city': 'Milán',
                  'images': [
                    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'milan_2_3',
                  'title': 'Barrio de Brera',
                  'description':
                      'Distrito artístico con galerías exclusivas y boutiques de diseño',
                  'duration': 120,
                  'category': 'tour',
                  'city': 'Milán',
                  'images': [
                    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
            {
              'dayNumber': 3,
              'activities': [
                {
                  'id': 'milan_3_1',
                  'title': 'Quadrilatero della Moda',
                  'description':
                      'Distrito de la moda mundial con las mejores marcas de lujo',
                  'duration': 150,
                  'category': 'shopping',
                  'city': 'Milán',
                  'images': [
                    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
                {
                  'id': 'milan_3_2',
                  'title': 'Navigli',
                  'description':
                      'Canales históricos diseñados por Da Vinci con vida nocturna vibrante',
                  'duration': 120,
                  'category': 'nightlife',
                  'city': 'Milán',
                  'images': [
                    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  ],
                },
              ],
            },
          ],
        };

      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> getGuideDetails(String guideId) async {
    try {
      // Si es una guía predefinida, usar datos mockeados
      if (guideId.startsWith('predefined_')) {
        final mockedData = GuideService.getMockedGuideDetails(guideId);
        if (mockedData != null) {
          return mockedData;
        }
      }

      final user = AuthService.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Cargar datos de la guía principal
      final guideDoc = await _firestore.collection('guides').doc(guideId).get();

      if (!guideDoc.exists) {
        throw Exception('Guía no encontrada');
      }

      final guideData = guideDoc.data()!;
      guideData['id'] = guideDoc.id;

      // Cargar actividades por días
      final daysCollection = await _firestore
          .collection('guides')
          .doc(guideId)
          .collection('days')
          .get();

      final List<Map<String, dynamic>> days = [];
      for (var doc in daysCollection.docs) {
        final data = doc.data();
        data['dayNumber'] = int.tryParse(doc.id) ?? days.length + 1;
        days.add(data);
      }

      // Ordenar días por número
      days.sort((a, b) => a['dayNumber'].compareTo(b['dayNumber']));

      guideData['days'] = days;
      guideData['isOwner'] = guideData['authorId'] == user.uid;

      return guideData;
    } catch (e) {
      print('ERROR en getGuideDetails: $e');
      rethrow;
    }
  }

  // Get community public guides - Guías públicas de la comunidad (excluyendo predefinidas)
  static Future<List<Map<String, dynamic>>> getCommunityPublicGuides(
      {int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection('guides')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> allGuides = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // Excluir guías predefinidas
        if (doc.id.startsWith('predefined_')) {
          continue;
        }

        // Obtener autor
        String authorName = 'Autor desconocido';
        try {
          final userRef = data['userRef'] as DocumentReference?;
          final userId = data['userId'] as String?;

          if (userRef != null) {
            final userDoc = await userRef.get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              authorName = userData['name'] ??
                  userData['displayName'] ??
                  'Autor desconocido';
            }
          } else if (userId != null) {
            final userDoc =
                await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              authorName = userData['name'] ??
                  userData['displayName'] ??
                  'Autor desconocido';
            }
          }
        } catch (e) {
          print('Error obteniendo autor para ${doc.id}: $e');
        }

        // Calcular duración y actividades desde la subcolección 'days'
        int totalDays = 0;
        int totalActivities = 0;

        try {
          final daysSnapshot = await _firestore
              .collection('guides')
              .doc(doc.id)
              .collection('days')
              .get();

          totalDays = daysSnapshot.docs.length;

          for (final dayDoc in daysSnapshot.docs) {
            final dayData = dayDoc.data();
            if (dayData['activities'] is List) {
              totalActivities += (dayData['activities'] as List).length;
            }
          }
        } catch (e) {
          print('Error calculando días/actividades para ${doc.id}: $e');
        }

        allGuides.add({
          'id': doc.id,
          'title': data['title'] ?? 'Sin título',
          'author': authorName,
          'city': data['city'] ?? data['destination'] ?? '',
          'destination': data['destination'] ?? data['city'] ?? '',
          'description': data['description'] ??
              'Guía de viaje para ${data['destination'] ?? data['city'] ?? 'destino'}',
          'imageUrl': data['imageUrl'] ?? '',
          'createdAt': data['createdAt'],
          'isPublic': data['isPublic'] ?? false,
          'duration': totalDays > 0
              ? '$totalDays día${totalDays == 1 ? '' : 's'}'
              : 'Duración no especificada',
          'activities': totalActivities,
          'totalDays': totalDays,
          'views': data['views'] ?? 0,
        });
      }

      return allGuides;
    } catch (e) {
      print('Error fetching community public guides: $e');
      return [];
    }
  }
}
