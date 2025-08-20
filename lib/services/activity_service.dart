import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Actualiza las actividades de un día concreto en una guía
  static Future<bool> updateDayActivities({
    required String guideId,
    required int dayNumber,
    required List<Map<String, dynamic>> activities,
  }) async {
    try {
      final activitiesData = activities.map((activity) => activity).toList();
      await _firestore
          .collection('guides')
          .doc(guideId)
          .collection('days')
          .doc(dayNumber.toString())
          .set({
        'activities': activitiesData,
        'dayNumber': dayNumber,
      });
      return true;
    } catch (e) {
      print('Error actualizando actividades: $e');
      return false;
    }
  }

  /// Elimina una actividad de un día concreto
  static Future<bool> deleteActivity({
    required String guideId,
    required int dayNumber,
    required String activityId,
    required List<Map<String, dynamic>> currentActivities,
  }) async {
    try {
      final updatedActivities = currentActivities
          .where((a) => (a['id'] ?? '') != activityId)
          .toList();
      return await updateDayActivities(
        guideId: guideId,
        dayNumber: dayNumber,
        activities: updatedActivities,
      );
    } catch (e) {
      print('Error eliminando actividad: $e');
      return false;
    }
  }

  /// Añade una nueva actividad a un día concreto
  static Future<bool> addActivity({
    required String guideId,
    required int dayNumber,
    required Map<String, dynamic> newActivity,
    required List<Map<String, dynamic>> currentActivities,
  }) async {
    try {
      final updatedActivities = [
        ...currentActivities,
        newActivity,
      ];
      return await updateDayActivities(
        guideId: guideId,
        dayNumber: dayNumber,
        activities: updatedActivities,
      );
    } catch (e) {
      print('Error añadiendo actividad: $e');
      return false;
    }
  }
}
