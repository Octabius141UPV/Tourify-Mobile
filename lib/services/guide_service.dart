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
  }) async {
    try {
      if (!AuthService.isAuthenticated) {
        throw Exception('User must be authenticated to create a guide');
      }

      final String userId = AuthService.userId!;

      // Create the guide document
      final guideRef = await _firestore.collection('guides').add({
        'title': 'Guía de $destination',
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

  Future<Map<String, dynamic>> getGuideDetails(String guideId) async {
    try {
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
}
