import 'package:tourify_flutter/data/mock_activities.dart';
import 'package:tourify_flutter/services/api_service.dart';
import 'package:tourify_flutter/data/activity_mapper.dart';
import 'package:tourify_flutter/services/auth_service.dart';
import 'package:tourify_flutter/services/guide_service.dart';

class DiscoverService {
  static final ApiService _apiService = ApiService();

  // Lista de actividades aceptadas
  static final List<Activity> _acceptedActivities = [];

  // Lista de actividades rechazadas
  static final List<Activity> _rejectedActivities = [];

  // Estado de carga
  static bool _isLoading = false;
  static bool get isLoading => _isLoading;

  // Obtener actividades aceptadas
  static List<Activity> get acceptedActivities => _acceptedActivities;

  // Obtener actividades rechazadas
  static List<Activity> get rejectedActivities => _rejectedActivities;

  // Verificar si se puede deshacer la última acción
  static bool get canUndo => _actionHistory.isNotEmpty;

  // Obtener la última actividad del historial sin quitarla
  static Activity? get lastActionActivity {
    if (_actionHistory.isEmpty) return null;
    return _actionHistory.last['activity'] as Activity;
  }

  // Obtener si la última acción fue una aceptación
  static bool get lastActionWasAccept {
    if (_actionHistory.isEmpty) return false;
    return _actionHistory.last['wasAccepted'] as bool;
  }

  // Limpiar el estado
  static void reset() {
    _acceptedActivities.clear();
    _rejectedActivities.clear();
    _actionHistory.clear();
  }

  // Cargar actividades desde la API con streaming
  static Stream<List<Activity>> fetchActivitiesStream({
    required String destination,
    DateTime? startDate,
    DateTime? endDate,
    String lang = 'es',
    int? limit = 15, // Valor por defecto de 15 actividades
    List<String>? existingTitles,
    List<String>? discardedTitles,
    int? travelers,
    List<String>? travelModes,
  }) async* {
    try {
      _isLoading = true;

      // Verificar autenticación
      if (!AuthService.isAuthenticated) {
        throw Exception('Se requiere autenticación para obtener actividades');
      }

      // ApiService ya maneja automáticamente el token a través de _getHeaders()
      await for (final apiActivities in _apiService.fetchActivitiesStream(
        location: destination,
        startDate: startDate,
        endDate: endDate,
        lang: lang,
        limit: limit,
        existingTitles: existingTitles,
        discardedTitles: discardedTitles,
        travelers: travelers,
        travelModes: travelModes,
      )) {
        // Convertir actividades del API al formato local
        final activities = ActivityMapper.fromApiListToLocal(apiActivities);

        // Emitir las actividades conforme van llegando SIN ordenar para no interferir con el stream
        yield activities;
      }

      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      print('Error en DiscoverService.fetchActivitiesStream: $e');

      // En caso de error, emitir una lista vacía
      yield [];
    }
  }

  // Cargar actividades desde la API
  static Future<List<Activity>> fetchActivities({
    required String destination,
    DateTime? startDate,
    DateTime? endDate,
    String lang = 'es',
    int? limit = 15, // Valor por defecto de 15 actividades
    List<String>? existingTitles,
    List<String>? discardedTitles,
    int? travelers,
    List<String>? travelModes,
  }) async {
    try {
      _isLoading = true;

      // Verificar autenticación
      if (!AuthService.isAuthenticated) {
        throw Exception('Se requiere autenticación para obtener actividades');
      }

      // ApiService ya maneja automáticamente el token a través de _getHeaders()
      final apiActivities = await _apiService.fetchActivities(
        location: destination,
        startDate: startDate,
        endDate: endDate,
        lang: lang,
        limit: limit,
        existingTitles: existingTitles,
        discardedTitles: discardedTitles,
        travelers: travelers,
        travelModes: travelModes,
      );

      // Convertir actividades del API al formato local
      final activities = ActivityMapper.fromApiListToLocal(apiActivities);

      _isLoading = false;
      return activities;
    } catch (e) {
      _isLoading = false;
      print('Error en DiscoverService.fetchActivities: $e');

      // En caso de error, devolver una lista vacía
      return [];
    }
  }

  // Registrar una actividad aceptada
  static void acceptActivity(Activity activity) {
    _acceptedActivities.add(activity);

    // Registrar en el historial para poder deshacer
    _actionHistory.add({
      'activity': activity,
      'wasAccepted': true,
      'timestamp': DateTime.now(),
    });

    // NO enviar rating inmediatamente - se enviará al final
  }

  // Registrar una actividad rechazada
  static void rejectActivity(Activity activity) {
    _rejectedActivities.add(activity);

    // Registrar en el historial para poder deshacer
    _actionHistory.add({
      'activity': activity,
      'wasAccepted': false,
      'timestamp': DateTime.now(),
    });

    // NO enviar rating inmediatamente - se enviará al final
  }

  // Historial de acciones para poder deshacer
  static final List<Map<String, dynamic>> _actionHistory = [];

  // Deshacer la última acción
  static Activity? undoLastAction() {
    if (_actionHistory.isEmpty) {
      return null;
    }

    final lastAction = _actionHistory.removeLast();
    final activity = lastAction['activity'] as Activity;
    final wasAccepted = lastAction['wasAccepted'] as bool;

    // Quitar de la lista correspondiente
    if (wasAccepted) {
      _acceptedActivities.removeWhere((a) => a.id == activity.id);
    } else {
      _rejectedActivities.removeWhere((a) => a.id == activity.id);
    }

    // Enviar al servidor que se deshizo la acción
    _sendUndoRating(activity, wasAccepted);

    return activity;
  }

  // Deshacer una actividad específica
  static bool undoSpecificActivity(Activity activity) {
    // Buscar la actividad en el historial
    int actionIndex = -1;
    bool wasAccepted = false;

    for (int i = _actionHistory.length - 1; i >= 0; i--) {
      final action = _actionHistory[i];
      if ((action['activity'] as Activity).id == activity.id) {
        actionIndex = i;
        wasAccepted = action['wasAccepted'] as bool;
        break;
      }
    }

    if (actionIndex == -1) {
      return false; // Actividad no encontrada en el historial
    }

    // Quitar del historial
    _actionHistory.removeAt(actionIndex);

    // Quitar de la lista correspondiente
    if (wasAccepted) {
      _acceptedActivities.removeWhere((a) => a.id == activity.id);
    } else {
      _rejectedActivities.removeWhere((a) => a.id == activity.id);
    }

    // Enviar al servidor que se deshizo la acción
    _sendUndoRating(activity, wasAccepted);

    return true;
  }

  // Enviar valoración al servidor
  static Future<void> _sendRating(Activity activity, bool isLiked) async {
    if (!AuthService.isAuthenticated) {
      return; // Solo enviar valoraciones si está autenticado
    }

    final rating = {
      'activityId': activity.id,
      'value': isLiked ? 1 : 0,
      'activityData': {
        'title': activity.name,
        'description': activity.description,
        'image': activity.imageUrl,
        'category': activity.category,
      }
    };

    await _apiService.submitRatings([rating]);
  }

  // Enviar notificación de que se deshizo una valoración
  static Future<void> _sendUndoRating(
      Activity activity, bool wasAccepted) async {
    if (!AuthService.isAuthenticated) {
      return;
    }

    print(
        '⚠️ Undo action para actividad: ${activity.name} (era ${wasAccepted ? "aceptada" : "rechazada"})');

    // Por ahora, simplemente no enviamos nada al servidor para evitar errores 400
    // El servidor puede manejar esto de manera diferente en el futuro
  }

  // Enviar todas las valoraciones acumuladas al final en un solo lote
  static Future<void> _sendAllRatingsAtEnd() async {
    if (!AuthService.isAuthenticated) {
      return;
    }

    List<Map<String, dynamic>> allRatings = [];

    // Añadir actividades aceptadas (rating positivo)
    for (final activity in _acceptedActivities) {
      allRatings.add({
        'activityId': activity.id,
        'value': 1,
        'activityData': {
          'title': activity.name,
          'description': activity.description,
          'image': activity.imageUrl,
          'category': activity.category,
        }
      });
    }

    // Añadir actividades rechazadas (rating negativo)
    for (final activity in _rejectedActivities) {
      allRatings.add({
        'activityId': activity.id,
        'value': 0,
        'activityData': {
          'title': activity.name,
          'description': activity.description,
          'image': activity.imageUrl,
          'category': activity.category,
        }
      });
    }

    // Enviar todas las valoraciones en un solo lote
    if (allRatings.isNotEmpty) {
      print('📊 Enviando ${allRatings.length} valoraciones al final');
      await _apiService.submitRatings(allRatings);
    }
  }

  // Crear una guía con las actividades seleccionadas
  static Future<String?> createGuide({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required int travelers,
    required List<String> travelModes,
    bool isPublic = false,
    String? guideName,
    String? guideDescription,
  }) async {
    try {
      if (!AuthService.isAuthenticated) {
        throw Exception('Se requiere autenticación para crear una guía');
      }

      // ENVIAR TODAS LAS VALORACIONES AL FINAL, antes de crear la guía
      await _sendAllRatingsAtEnd();

      // Usar el servicio de Firebase para crear la guía
      final guideId = await GuideService.createGuide(
        destination: destination,
        startDate: startDate,
        endDate: endDate,
        selectedActivities: _acceptedActivities,
        rejectedActivities: _rejectedActivities,
        travelers: travelers,
        travelModes: travelModes,
        isPublic: isPublic,
        guideName: guideName,
        guideDescription: guideDescription,
      );

      return guideId;
    } catch (e) {
      print('Error en DiscoverService.createGuide: $e');
      return null;
    } finally {
      // Siempre limpiar los arrays de actividades, sin importar si hay error o no
      reset();
    }
  }

  // Alternativa usando API en lugar de Firebase
  static Future<String?> createGuideViaApi({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required int travelers,
  }) async {
    try {
      if (!AuthService.isAuthenticated) {
        throw Exception('Se requiere autenticación para crear una guía');
      }

      // ENVIAR TODAS LAS VALORACIONES AL FINAL, antes de crear la guía
      await _sendAllRatingsAtEnd();

      // Convertir actividades aceptadas al formato de la API
      final List<Map<String, dynamic>> activities = _acceptedActivities
          .map((activity) => ActivityMapper.fromLocalToApi(activity))
          .toList();

      // Convertir actividades rechazadas al formato de la API
      final List<Map<String, dynamic>> rejectedActivities = _rejectedActivities
          .map((activity) => {
                'id': activity.id,
                'title': activity.name,
                'category': activity.category,
                'value': 0, // Valor 0 para actividades rechazadas
              })
          .toList();

      final guideId = await _apiService.createGuide(
        destination: destination,
        startDate: startDate,
        endDate: endDate,
        activities: activities,
        rejectedActivities: rejectedActivities,
        travelers: travelers,
      );

      return guideId;
    } catch (e) {
      print('Error en DiscoverService.createGuideViaApi: $e');
      return null;
    } finally {
      // Siempre limpiar los arrays de actividades, sin importar si hay error o no
      reset();
    }
  }
}
