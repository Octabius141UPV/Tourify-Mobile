import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:tourify_flutter/config/app_colors.dart';
import 'package:tourify_flutter/data/activity.dart';
import 'package:tourify_flutter/services/guide_service.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:tourify_flutter/services/guest_guide_service.dart';
// import 'package:tourify_flutter/services/discover_service.dart';
import 'package:tourify_flutter/services/map/geocoding_service.dart';
import 'package:tourify_flutter/services/map/places_service.dart';
// import 'package:tourify_flutter/utils/activity_utils.dart';
import 'package:tourify_flutter/widgets/map/activity_marker_utils.dart';
import 'package:tourify_flutter/widgets/edit_activity_dialog.dart';
import 'package:tourify_flutter/widgets/add_activity_dialog.dart';
import 'package:tourify_flutter/widgets/collaborators_modal.dart';
import 'package:tourify_flutter/widgets/organize_activities_modal.dart';
import 'package:tourify_flutter/services/collaborators_service.dart';
import 'package:tourify_flutter/services/public_guides_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:tourify_flutter/screens/guides/collaborators_screen.dart';
// import 'package:tourify_flutter/screens/other/premium_subscription_screen.dart';
// import 'package:tourify_flutter/screens/guides/guide_map_screen.dart';
import 'package:tourify_flutter/widgets/travel_agent_chat_widget.dart';
import 'package:tourify_flutter/widgets/premium_feature_modal.dart';
import 'package:tourify_flutter/services/guide_tutorial_service.dart';
import 'package:tourify_flutter/widgets/guide_tutorial_overlay.dart';
import 'package:tourify_flutter/services/api_service.dart';
import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:tourify_flutter/utils/dialog_utils.dart';
import 'package:tourify_flutter/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:tourify_flutter/services/my_maps_service.dart';
import 'package:tourify_flutter/utils/google_maps_utils.dart';
import 'package:tourify_flutter/services/google_maps_export_service.dart';
import 'package:tourify_flutter/widgets/guide_detail/guide_header.dart';
import 'package:tourify_flutter/widgets/guide_detail/day_card.dart';
import 'package:tourify_flutter/widgets/guide_detail/activity_tile.dart';
import 'package:tourify_flutter/widgets/guide_detail/floating_action_menu.dart';
import 'package:tourify_flutter/services/activity_service.dart';
import 'package:tourify_flutter/widgets/guide_detail/tickets_modal.dart';
// import 'package:tourify_flutter/services/navigation_service.dart';

// Clase para representar lugares cercanos obtenidos de Google Places API
class NearbyPlace {
  final String placeId;
  final String name;
  final double? rating;
  final List<String> types;
  final String? vicinity;
  final int? priceLevel;

  NearbyPlace({
    required this.placeId,
    required this.name,
    this.rating,
    required this.types,
    this.vicinity,
    this.priceLevel,
  });
}

class GuideDetailScreen extends StatefulWidget {
  final String guideId;
  final String guideTitle;

  const GuideDetailScreen({
    super.key,
    required this.guideId,
    required this.guideTitle,
  });

  @override
  State<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GuideService _guideService = GuideService();
  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isOwner = false;
  Map<String, dynamic>? _guide;
  String? _error;
  bool _isMenuExpanded = false;

  // Autenticación y control de navegación
  bool _isAuthenticated = false;
  StreamSubscription<User?>? _authSubscription;

  // Controlador de scroll para la guía
  final ScrollController _guideScrollController = ScrollController();

  // Estado para controlar qué días están expandidos
  Set<int> _expandedDays = {1}; // Por defecto, día 1 expandido

  // Variable para trackear la actividad seleccionada
  String? _selectedActivityId;

  // NUEVO: Permiso de edición
  bool _canEdit = false;
  String? _userRole;

  // Variables para el gesto de swipe
  bool _isSwipeActive = false;

  // Variables para el mapa integrado
  bool _isMapVisible = false;
  double _mapHeightFraction = 0.4; // 40% del alto inicial
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _centerLocation;
  bool _isMapLoading = false;
  Set<Polyline> _polylines = {};
  List<Activity> _allActivities = [];
  Set<int> _selectedDays = {}; // NUEVO: días seleccionados para el mapa

  // Vista previa: reactivada sin mostrar badge ni CTA
  bool _isPreview = false;
  String? _previewToken;

  // Estilo gris para las carreteras del mapa
  final String _greyRoadsMapStyle = '''
  [
    {"featureType": "road","elementType": "geometry","stylers": [{"color": "#b0b0b0"}]},
    {"featureType": "road.arterial","elementType": "geometry","stylers": [{"color": "#cccccc"}]},
    {"featureType": "road.highway","elementType": "geometry","stylers": [{"color": "#a0a0a0"}]},
    {"featureType": "road.local","elementType": "geometry","stylers": [{"color": "#e0e0e0"}]},
    {"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#888888"}]},
    {"featureType": "road","elementType": "labels.text.stroke","stylers": [{"color": "#ffffff"},{"weight": 2}]}
  ]
  ''';

  // Guardar el mapping de actividad a MarkerId y su posición
  Map<String, LatLng> _activityIdToLatLng = {};
  Map<String, int> _activityIdToPinNumber = {};

  // Variables para el tutorial de guías
  bool _showGuideTutorial = false;

  // Variables para la ubicación del usuario
  final LocationService _locationService = LocationService();
  LatLng? _userLocation;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();

    // Verificar modo invitado inmediatamente después de initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInitializeGuide();
    });

    _initializeUserLocation();

    // Estado inicial de autenticación y escucha de cambios
    _isAuthenticated = _auth.currentUser != null;
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _isAuthenticated = user != null;
        });
      }
    });
  }

  /// Verifica el modo y inicializa la guía apropiadamente
  Future<void> _checkAndInitializeGuide() async {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;

    // Detectar vista previa por token
    if (routeArgs is Map<String, dynamic> && routeArgs['isPreview'] == true) {
      _isPreview = true;
      _previewToken = routeArgs['previewToken'] as String?;
      await _loadPreviewGuide();
      return;
    }

    // Si hay configuración de invitado, crear guía de invitado
    if (routeArgs is Map<String, dynamic> &&
        routeArgs.containsKey('guestConfig')) {
      print('🎯 Modo invitado detectado - creando guía temporal');
      await _createGuestGuide();
    } else {
      // Modo normal - cargar guía existente
      print('📖 Modo normal - cargando guía existente: ${widget.guideId}');
      await _loadGuideDetails();
      await _checkEditPermission();
      await _checkGuideTutorial();
    }
  }

  /// Carga una guía en modo previsualización (sin autenticación)
  Future<void> _loadPreviewGuide() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _canEdit = false;
        _isOwner = false;
      });

      // DEBUG: modo mock sin backend (token = "debug" o "mock")
      if (kDebugMode &&
          (_previewToken == 'debug' ||
              _previewToken?.toLowerCase() == 'mock')) {
        final mockPreview = {
          'id': widget.guideId.isNotEmpty ? widget.guideId : 'debug_guide',
          'title': widget.guideTitle.isNotEmpty
              ? widget.guideTitle
              : 'Guía compartida',
          'city': 'Roma',
          'startDate': DateTime.now().toIso8601String(),
          'endDate':
              DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'days': [
            {
              'dayNumber': 1,
              'activities': [
                {
                  'id': 'a1',
                  'title': 'Coliseo Romano',
                  'description': 'El anfiteatro más grande del mundo',
                  'category': 'monument',
                  'duration': 120,
                  'coordinates': {
                    'latitude': 41.8902,
                    'longitude': 12.4922,
                  },
                  'address': 'Piazza del Colosseo, 1, 00184 Roma',
                  // sin startTime/endTime para evitar .toDate() en mock
                },
                {
                  'id': 'a2',
                  'title': 'Fontana di Trevi',
                  'description': 'Famosa fuente barroca',
                  'category': 'sightseeing',
                  'duration': 45,
                  'coordinates': {
                    'latitude': 41.9009,
                    'longitude': 12.4833,
                  },
                  'address': 'Piazza di Trevi, 00187 Roma',
                },
              ],
            },
            {
              'dayNumber': 2,
              'activities': [
                {
                  'id': 'a3',
                  'title': 'Museos Vaticanos',
                  'description': 'Incluye Capilla Sixtina',
                  'category': 'museum',
                  'duration': 180,
                  'coordinates': {
                    'latitude': 41.9065,
                    'longitude': 12.4536,
                  },
                  'address': 'Viale Vaticano, 00165 Roma',
                },
              ],
            },
          ],
        };

        setState(() {
          _guide = {
            'id': mockPreview['id'],
            'title': mockPreview['title'],
            'city': mockPreview['city'],
            'startDate': mockPreview['startDate'],
            'endDate': mockPreview['endDate'],
            'isGuestMode': false,
            'isGenerating': false,
            'days': mockPreview['days'],
          };
          _isLoading = false;
        });
        _rebuildActivitiesFromGuide();
        return;
      }

      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'https://api.tourifyapp.es';
      final uri = Uri.parse('$baseUrl/collaborators/preview/${_previewToken!}');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final preview = data['preview'] as Map<String, dynamic>;
        setState(() {
          _guide = {
            'id': preview['id'],
            'title': preview['title'],
            'city': preview['city'],
            'startDate': preview['startDate'],
            'endDate': preview['endDate'],
            'isGuestMode': false,
            'isGenerating': false,
            'days': preview['days'] ?? [],
          };
          _isLoading = false;
        });
        _rebuildActivitiesFromGuide();
      } else if (response.statusCode == 404 || response.statusCode == 410) {
        setState(() {
          _isLoading = false;
          _error = response.statusCode == 404
              ? 'El enlace ya no es válido'
              : 'El enlace ha expirado';
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Error cargando la guía (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar la previsualización';
        _isLoading = false;
      });
    }
  }

  /// Inicializa la ubicación del usuario
  Future<void> _initializeUserLocation() async {
    try {
      print('🗺️ Solicitando permisos de ubicación...');
      bool hasPermission = await _locationService.requestLocationPermission();
      setState(() {
        _hasLocationPermission = hasPermission;
      });

      if (hasPermission) {
        // Obtener ubicación actual
        Position? position = await _locationService.getCurrentPosition();
        if (position != null) {
          setState(() {
            _userLocation = LatLng(position.latitude, position.longitude);
          });
          print('📍 Ubicación del usuario obtenida: $_userLocation');
        }
      } else {
        print('❌ Permisos de ubicación denegados');
      }
    } catch (e) {
      print('❌ Error obteniendo ubicación del usuario: $e');
    }
  }

  /// Centra el mapa en la ubicación del usuario
  Future<void> _centerOnUserLocation() async {
    if (_mapController == null) return;

    try {
      // Solicitar nueva ubicación si no la tenemos o está desactualizada
      Position? position = await _locationService.getCurrentPosition();
      if (position != null) {
        final userLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _userLocation = userLocation;
        });

        // Animar la cámara hacia la ubicación del usuario
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(userLocation, 16.0),
        );

        // Mostrar un mensaje de confirmación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.my_location, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Centrado en tu ubicación',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0062FF),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        // Mostrar error si no se puede obtener la ubicación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'No se pudo obtener tu ubicación',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error centrando en ubicación del usuario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.15,
              left: 10,
              right: 10,
            ),
          ),
        );
      }
    }
  }

  Future<void> _checkEditPermission() async {
    // Si es una guía predefinida, no permitir edición
    if (widget.guideId.startsWith('predefined_')) {
      setState(() {
        _canEdit = false;
        _isOwner = false;
        _userRole = null;
      });
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      print('DEBUG: Usuario no autenticado');
      return;
    }

    try {
      print('DEBUG: Verificando permisos para guía: ${widget.guideId}');
      print('DEBUG: Usuario ID: ${user.uid}');
      print('DEBUG: Usuario email: ${user.email}');

      final collaboratorsService = CollaboratorsService();
      final roleResponse =
          await collaboratorsService.getUserRole(widget.guideId);

      print('DEBUG: Respuesta del servicio: $roleResponse');

      setState(() {
        _userRole = roleResponse['role'] as String?;
        _isOwner = roleResponse['isOwner'] == true;
        // Tanto el creador (owner) como organizador (editor) pueden editar
        // Acoplado (viewer) solo puede ver
        _canEdit = _isOwner || roleResponse['role'] == 'editor';
      });

      print(
          'DEBUG: Rol final - _userRole: $_userRole, _isOwner: $_isOwner, _canEdit: $_canEdit');
    } catch (e) {
      print('DEBUG: Error al verificar permisos: $e');
      setState(() {
        _canEdit = false;
        _isOwner = false;
      });
    }
  }

  /// Verifica si debe mostrar el tutorial de guías
  Future<void> _checkGuideTutorial() async {
    final shouldShowTutorial = await GuideTutorialService.isFirstGuideOpen();
    if (shouldShowTutorial && mounted) {
      setState(() {
        _showGuideTutorial = true;
      });
    }
  }

  /// Comprueba si es una guía de invitado mediante los argumentos de la ruta

  /// Crea una guía de invitado temporal y comienza la generación de actividades
  Future<void> _createGuestGuide() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final routeArgs =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
      final guestConfig = routeArgs['guestConfig'] as Map<String, dynamic>;

      // Crear estructura de guía vacía inicial
      _guide = {
        'id': widget.guideId,
        'title': widget.guideTitle,
        'city': guestConfig['destination'],
        'startDate': guestConfig['startDate'] is String
            ? DateTime.parse(guestConfig['startDate'] as String)
            : guestConfig['startDate'],
        'endDate': guestConfig['endDate'] is String
            ? DateTime.parse(guestConfig['endDate'] as String)
            : guestConfig['endDate'],
        'travelers': guestConfig['travelers'],
        'travelModes': guestConfig['travelModes'],
        'days': _createEmptyDays(_calculateDaysFromDates(
            guestConfig['startDate'], guestConfig['endDate'])),
        'isGuestMode': true,
        'isGenerating': true,
      };

      setState(() {
        _isLoading = false;
        _canEdit = true; // En modo invitado, permitir edición
        _isOwner = true;
      });

      // Iniciar generación de actividades con IA
      _startActivityGeneration(guestConfig);
    } catch (e) {
      print('ERROR creando guía de invitado: $e');
      setState(() {
        _isLoading = false;
        _error = 'Error creando la guía: $e';
      });
    }
  }

  /// Calcula el número de días entre dos fechas
  int _calculateDaysFromDates(dynamic startDate, dynamic endDate) {
    final start =
        startDate is String ? DateTime.parse(startDate) : startDate as DateTime;
    final end =
        endDate is String ? DateTime.parse(endDate) : endDate as DateTime;
    return end.difference(start).inDays + 1;
  }

  /// Crea días vacíos para la guía
  List<Map<String, dynamic>> _createEmptyDays(int totalDays) {
    return List.generate(
        totalDays,
        (index) => {
              'dayNumber': index + 1,
              'activities':
                  <Map<String, dynamic>>[], // Lista vacía de actividades
            });
  }

  /// Inicia la generación de actividades mediante IA del backend
  Future<void> _startActivityGeneration(Map<String, dynamic> config) async {
    try {
      print(
          '🤖 Iniciando generación REAL de actividades para ${config['destination']}');

      // Convertir las fechas de String a DateTime si es necesario
      final startDate = config['startDate'] is String
          ? DateTime.parse(config['startDate'] as String)
          : config['startDate'] as DateTime;
      final endDate = config['endDate'] is String
          ? DateTime.parse(config['endDate'] as String)
          : config['endDate'] as DateTime;
      final destination = config['destination'] as String;
      final travelers = config['travelers'] as int;
      final travelModes = (config['travelModes'] as List<String>);

      print('📤 Enviando datos al backend:');
      print('   - Destino: $destination');
      print(
          '   - Fechas: ${startDate.toIso8601String()} - ${endDate.toIso8601String()}');
      print('   - Viajeros: $travelers');
      print('   - Modos: $travelModes');

      // Usar directamente ApiService para obtener las actividades con IA
      final apiService = ApiService();

      // Crear lista para almacenar actividades mientras se van cargando
      final streamActivities = <Map<String, dynamic>>[];

      // Obtener stream de actividades y actualizar progresivamente
      await for (final activityBatch in apiService.fetchActivitiesStream(
        location: destination,
        startDate: startDate,
        endDate: endDate,
        travelers: travelers,
        travelModes: travelModes,
        travelIntensity: config['travelIntensity'] as String?,
      )) {
        // Solo añadir las actividades nuevas (las que no teníamos antes)
        final newActivitiesCount =
            activityBatch.length - streamActivities.length;

        if (newActivitiesCount > 0) {
          // Añadir solo las actividades nuevas
          for (int i = streamActivities.length; i < activityBatch.length; i++) {
            final activity = activityBatch[i] as Map<String, dynamic>;
            // Limpiar datos de la actividad para evitar errores de tipo
            final cleanActivity = _cleanActivityData(activity);
            streamActivities.add(cleanActivity);

            print(
                '📥 Actividad ${streamActivities.length} recibida: ${cleanActivity['title']}');
          }

          // Actualizar la UI progresivamente solo si hay actividades nuevas
          setState(() {
            final days = _organizarActividadesPorDias(
                streamActivities, startDate, endDate);
            _guide!['days'] = days;
          });

          // Pequeña pausa para permitir que la UI se actualice
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      if (streamActivities.isNotEmpty) {
        print(
            '✅ Actividades generadas exitosamente: ${streamActivities.length}');

        // Actualización final con todas las actividades
        setState(() {
          _guide!['isGenerating'] = false;
          final days = _organizarActividadesPorDias(
              streamActivities, startDate, endDate);
          _guide!['days'] = days;
        });

        // Reconstruir actividades para el mapa
        _rebuildActivitiesFromGuide();

        // Guardar la guía temporal con las actividades generadas
        await _saveTemporaryGuideWithActivities(
            streamActivities, startDate, endDate);

        print('🎉 Guía cargada completamente desde el backend');
      } else {
        throw Exception('No se generaron actividades');
      }
    } catch (e) {
      print('❌ Error en generación de actividades: $e');

      if (mounted) {
        setState(() {
          _guide!['isGenerating'] = false;
        });

        // Mostrar error al usuario pero permitir añadir actividades manualmente
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error generando actividades: $e\n\nPuedes añadir actividades manualmente usando el botón +'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Entendido',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  /// Limpia los datos de una actividad para evitar errores de tipo
  Map<String, dynamic> _cleanActivityData(Map<String, dynamic> activity) {
    return {
      'id': activity['id']?.toString() ?? '',
      'title':
          activity['title']?.toString() ?? activity['name']?.toString() ?? '',
      'description': activity['description']?.toString() ?? '',
      'duration': _parseNumber(activity['duration']) ?? 60,
      'category': activity['category']?.toString() ?? 'general',
      'city': activity['city']?.toString() ?? '',
      'price': _parseNumber(activity['price']),
      'rating': _parseNumber(activity['rating']),
      'likes': _parseNumber(activity['likes']) ?? 0,
      'images': activity['images'] is List ? activity['images'] : [],
      'imageUrl': activity['imageUrl']?.toString(),
      'location': activity['location'],
      'coordinates': activity['coordinates'],
      'startTime': activity['startTime']?.toString(),
      'endTime': activity['endTime']?.toString(),
      // Campos que se asignarán después
      'day': 1,
      'order': 1,
    };
  }

  /// Guarda la guía temporal con las actividades generadas
  Future<void> _saveTemporaryGuideWithActivities(
      List<Map<String, dynamic>> activities,
      DateTime startDate,
      DateTime endDate) async {
    try {
      final temporaryGuide = await GuestGuideService.getTemporaryGuide();
      if (temporaryGuide != null) {
        // Actualizar la guía temporal con las actividades generadas
        temporaryGuide['activities'] = activities;
        temporaryGuide['startDate'] = startDate.toIso8601String();
        temporaryGuide['endDate'] = endDate.toIso8601String();
        temporaryGuide['isGenerated'] = true;

        await GuestGuideService.saveTemporaryGuide(temporaryGuide);
        print(
            '✅ Guía temporal actualizada con ${activities.length} actividades');
      }
    } catch (e) {
      print('❌ Error guardando guía temporal con actividades: $e');
    }
  }

  /// Convierte un valor a número de forma segura
  num? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  /// Organiza las actividades generadas por días
  List<Map<String, dynamic>> _organizarActividadesPorDias(
      List<dynamic> activities, DateTime startDate, DateTime endDate) {
    final totalDays = endDate.difference(startDate).inDays + 1;
    final days = <Map<String, dynamic>>[];

    // Crear días vacíos
    for (int i = 0; i < totalDays; i++) {
      days.add({
        'dayNumber': i + 1,
        'activities': <Map<String, dynamic>>[],
      });
    }

    // Distribuir actividades por días
    for (int i = 0; i < activities.length; i++) {
      final activity = activities[i] as Map<String, dynamic>;
      final dayIndex = i % totalDays; // Distribuir de forma equitativa

      // Asegurar que la actividad tenga el día correcto
      activity['day'] = dayIndex + 1;
      activity['order'] = (days[dayIndex]['activities'] as List).length + 1;

      (days[dayIndex]['activities'] as List).add(activity);
    }

    return days;
  }

  Future<void> _loadGuideDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final guideData = await _guideService.getGuideDetails(widget.guideId);

      if (guideData == null) {
        setState(() {
          _error = 'No se pudo cargar la guía';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _guide = guideData;
        _isLoading = false;
      });

      // CRÍTICO: Cargar actividades desde la guía para el mapa (DESPUÉS del setState)
      _rebuildActivitiesFromGuide();

      // Registrar vista si es una guía pública
      if (guideData['isPublic'] == true) {
        await PublicGuidesService.registerPublicGuideView(widget.guideId);
      }
    } catch (e) {
      print('ERROR en _loadGuideDetails: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verificar si arguments es null antes del cast
    final routeArgs = ModalRoute.of(context)?.settings.arguments;

    String guideId;
    String guideTitle;
    bool isPublic;
    if (routeArgs == null) {
      guideId = widget.guideId;
      guideTitle = widget.guideTitle;
      isPublic = false;
    } else if (routeArgs is! Map<String, dynamic>) {
      guideId = widget.guideId;
      guideTitle = widget.guideTitle;
      isPublic = false;
    } else {
      guideId = routeArgs['guideId'] ?? widget.guideId;
      guideTitle = routeArgs['guideTitle'] ?? widget.guideTitle;
      isPublic = routeArgs['isPublic'] ?? false;
    }

    // Determinar si es modo invitado y si debe mostrarse el botón atrás
    final bool isGuestMode = (_guide?['isGuestMode'] == true) ||
        (routeArgs is Map<String, dynamic> &&
            routeArgs.containsKey('guestConfig'));
    final bool showBackButton =
        !((isGuestMode && !_isAuthenticated) || _isPreview);

    return GestureDetector(
      onPanEnd: (details) {
        _handleSwipeEnd(details);
      },
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            if (_isMapVisible) {
              _closeMap();
            } else {
              // En modo invitado no autenticado o previsualización, bloquear navegación
              if ((isGuestMode && !_isAuthenticated) || _isPreview) {
                return;
              } else {
                _navigateToHome();
              }
            }
          }
        },
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFFF5F5F5),
              appBar: AppBar(
                title: Text(guideTitle),
                automaticallyImplyLeading: false,
                leading: showBackButton
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _isMapVisible ? _closeMap : _navigateToHome,
                        tooltip:
                            _isMapVisible ? 'Cerrar mapa' : 'Volver al inicio',
                      )
                    : null,
                actions: [
                  if (!isGuestMode && !_isPreview)
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: _downloadGuide,
                      tooltip: 'Descargar guía',
                    ),
                ],
              ),
              body: Stack(
                children: [
                  // Banner de vista previa eliminado
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                            key: ValueKey('loading'))
                        : _guide == null
                            ? const Center(
                                child: Text('No se encontró la guía',
                                    key: ValueKey('notfound')))
                            : _isMapVisible
                                ? _buildMapAndGuideLayout(
                                    key: const ValueKey('map'))
                                : Stack(
                                    key: const ValueKey('guide'),
                                    children: [
                                      SingleChildScrollView(
                                        controller: _guideScrollController,
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Espacio para banner eliminado
                                            _buildGuideHeader(),
                                            const SizedBox(height: 16),
                                            _buildDaysSection(),
                                            const SizedBox(height: 100),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                  ),
                  if (_isPreview && _previewToken != null && !_isMapVisible)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 88,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '¿Quieres guardar esta guía?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        NavigationService.setPendingJoin(
                                          guideId: widget.guideId,
                                          token: _previewToken!,
                                        );
                                        await NavigationService
                                            .navigateToWelcome();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF0062FF),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        'Unirme',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              floatingActionButton: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  if (!_isMapVisible && _canEdit) // dial sólo si puede editar
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _buildFloatingActionMenu(),
                    ),
                  // Botón flotante de mapa
                  if (!_isMenuExpanded) _buildFloatingMapButton(),
                ],
              ),
            ),
            // Guest registration banner overlayed ABOVE map and dial
            if (isGuestMode && !_isPreview)
              Positioned(
                left: 12,
                right: 12,
                bottom: _canEdit ? 152 : 96,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_open, color: Color(0xFF0062FF)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Regístrate gratis para desbloquear todos los días de tu guía',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await AnalyticsService.trackEvent(
                              'guest_banner_register_clicked',
                              parameters: {'guide_id': widget.guideId},
                            );
                            Navigator.of(context).pushNamed('/onboarding');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0062FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Crear cuenta',
                            style:
                                TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Tutorial overlay
            if (_showGuideTutorial)
              Positioned.fill(
                child: GuideTutorialOverlay(
                  canEdit: _canEdit,
                  onTutorialCompleted: () {
                    setState(() {
                      _showGuideTutorial = false;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideHeader() {
    if (_guide == null) {
      return const SizedBox.shrink();
    }

    // Manejar tanto DateTime (modo invitado) como Timestamp (Firebase)
    DateTime? startDate;
    DateTime? endDate;

    if (_guide!['startDate'] is DateTime) {
      startDate = _guide!['startDate'] as DateTime;
    } else if (_guide!['startDate'] is Timestamp) {
      startDate = (_guide!['startDate'] as Timestamp).toDate();
    }

    if (_guide!['endDate'] is DateTime) {
      endDate = _guide!['endDate'] as DateTime;
    } else if (_guide!['endDate'] is Timestamp) {
      endDate = (_guide!['endDate'] as Timestamp).toDate();
    }
    final city = _guide!['city'] ?? 'Ciudad desconocida';

    int totalDays = 0;
    if (_guide!['days'] is List) {
      totalDays = (_guide!['days'] as List).length;
    }
    if (startDate != null && endDate != null) {
      totalDays = endDate.difference(startDate).inDays + 1;
    }

    int totalPlaces = 0;
    if (_guide!['days'] is List) {
      totalPlaces = (_guide!['days'] as List).fold(
          0,
          (sum, day) =>
              sum +
              ((day is Map && day['activities'] is List)
                  ? (day['activities'] as List).length
                  : 0));
    }

    return GuideHeader(
      city: city,
      totalDays: totalDays,
      totalPlaces: totalPlaces,
      showCollaboratorsButton: !widget.guideId.startsWith('predefined_') &&
          (_isOwner || _userRole == 'editor'),
      onCollaboratorsTap: _openCollaborators,
      onExportGoogleMaps: _exportAllToGoogleMaps,
      onExportGoogleCalendar: _exportAllToGoogleCalendar,
    );
  }

  Widget _buildDaysSection() {
    if (_guide!['days'].isEmpty) {
      return Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(
                Icons.event_busy,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No hay actividades en esta guía',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isGenerating = _guide!['isGenerating'] == true;
    final isGuestMode = _guide!['isGuestMode'] == true;

    return Column(
      children: (_guide!['days'] as List).map<Widget>((dayData) {
        final dayNumber = dayData['dayNumber'] as int;
        final isExpanded = _expandedDays.contains(dayNumber);
        final dayActivities = dayData['activities'] as List;

        // En modo invitado, solo el primer día es accesible
        final isAccessible = !isGuestMode || dayNumber == 1;
        List<Widget> activities;

        // Si está generando y no hay actividades, mostrar indicador de carga
        if (isGenerating && dayActivities.isEmpty) {
          activities = [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF0062FF)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Generando actividades para el día $dayNumber...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ];
        } else if (!isAccessible) {
          // Día bloqueado en modo invitado
          activities = [
            _buildLockedDayContent(dayNumber, dayActivities.length),
          ];
        } else {
          // Actividades normales
          activities = dayActivities.map<Widget>((activity) {
            final activityObj =
                Activity.fromMap(activity, activity['id'].toString());
            int? pinNum =
                _isMapVisible ? _activityIdToPinNumber[activityObj.id] : null;
            final bool isSelected = _selectedActivityId == activityObj.id;
            return ActivityTile(
              activity: activityObj,
              isSelected: isSelected,
              pinNum: pinNum,
              canEdit: _canEdit,
              onEdit: () => _editActivity(activity),
              onDelete: () => _deleteActivity(activity),
              onExportMaps: () => _exportToGoogleMaps(activity),
              onExportCalendar: () => _addToGoogleCalendar(activity),
              onReserve: () => _openInCivitatis(activityObj),
              startTime: (activity['startTime'] is Timestamp)
                  ? (activity['startTime'] as Timestamp).toDate()
                  : (activity['startTime'] is DateTime)
                      ? activity['startTime'] as DateTime
                      : null,
              endTime: (activity['endTime'] is Timestamp)
                  ? (activity['endTime'] as Timestamp).toDate()
                  : (activity['endTime'] is DateTime)
                      ? activity['endTime'] as DateTime
                      : null,
            );
          }).toList();

          // Si está generando y ya hay algunas actividades, añadir indicador al final
          if (isGenerating) {
            activities.add(
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF0062FF)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Generando más actividades...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        return Stack(
          children: [
            DayCard(
              dayNumber: dayNumber,
              activityCount: dayActivities.length,
              isExpanded: isExpanded && isAccessible,
              onExpansionChanged: isAccessible
                  ? () {
                      setState(() {
                        if (isExpanded) {
                          _expandedDays.remove(dayNumber);
                        } else {
                          _expandedDays.add(dayNumber);
                        }
                      });
                    }
                  : () {}, // Función vacía para días bloqueados
              activityTiles: activities,
            ),
            // Overlay borroso para días bloqueados - solo si tiene actividades que ocultar
            if (!isAccessible && dayActivities.isNotEmpty)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        color: Colors.white.withOpacity(0.2),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 22,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Contenido bloqueado',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _navigateToOnboardingFromGuest(),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF0062FF),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 6),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            minimumSize: const Size(120, 26),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Registrarse para ver',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  /// Construye el contenido para días bloqueados en modo invitado
  Widget _buildLockedDayContent(int dayNumber, int activityCount) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.lock_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '¡Completa tu registro para ver el día $dayNumber!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Este día contiene $activityCount actividades increíbles esperándote',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _navigateToOnboardingFromGuest(),
            icon: const Icon(Icons.person_add, size: 20),
            label: const Text('Completar registro'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0062FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Navega al onboarding para completar el registro
  void _navigateToOnboardingFromGuest() {
    Navigator.of(context).pushNamed('/onboarding');
  }

  Widget _buildFloatingActionMenu() {
    return FloatingActionMenu(
      isMenuExpanded: _isMenuExpanded,
      onToggleMenu: _toggleMenu,
      onAddActivity: _addNewActivity,
      onOrganizeActivities: _showOrganizeModal,
      onOpenAgent: _openTravelAgent,
      onOpenTickets: _openTicketsModal,
    );
  }

  void _openTicketsModal() {
    setState(() => _isMenuExpanded = false);
    final days = (_guide?['days'] as List?)
            ?.map<int>((d) => d['dayNumber'] as int)
            .toList() ??
        const <int>[];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => TicketsModal(
        guideId: widget.guideId,
        canEdit: _canEdit || _isOwner,
        days: days,
        onReopenModal: () => _openTicketsModal(),
      ),
    );
  }

  Widget _buildFloatingMapButton() {
    if (_isMapVisible) {
      // Cuando el mapa está visible, no mostrar ningún botón flotante
      return const SizedBox.shrink();
    } else {
      // Cuando el mapa no está visible, el botón de abrir va en posición secundaria
      return Positioned(
        bottom: _canEdit
            ? 62.0
            : 16.0, // Encima del dial si hay permisos de edición
        right: 0,
        child: Tooltip(
          message: 'Abrir Mapa',
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(27),
                onTap: _openGuideMap,
                child: Center(
                  child: Icon(
                    Icons.map_rounded,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildMapAndGuideLayout({Key? key}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        // Si la guía ocupa el 100%, ocultar el mapa
        final bool guiaFullScreen = _mapHeightFraction >= 0.99;
        final mapHeight =
            guiaFullScreen ? 0.0 : totalHeight * _mapHeightFraction;
        return Stack(
          children: [
            // Mapa de fondo, altura dinámica (oculto si la guía ocupa el 100%)
            if (!guiaFullScreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: mapHeight,
                child: _centerLocation != null
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _centerLocation!,
                          zoom: 12.0,
                        ),
                        markers: _markers,
                        polylines: _polylines,
                        myLocationEnabled: _hasLocationPermission,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: true,
                        zoomControlsEnabled: true,
                        compassEnabled: true,
                        mapType: MapType.normal,
                        onMapCreated: _onMapCreated,
                        onTap: (LatLng position) {
                          print('🖱️ TAP en mapa: $position');
                          _onMapTapped(position);
                        },
                        onCameraMove: (CameraPosition position) {
                          print(
                              '📹 CÁMARA MOVIDA: ${position.target}, zoom: ${position.zoom}');
                        },
                        // Configuración específica para iOS
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        // Configurar gesture recognizers para mejorar la respuesta táctil
                        gestureRecognizers: <Factory<
                            OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                      )
                    : Container(color: Colors.grey[200]),
              ),
            if (_isMapLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: mapHeight,
                child: Container(
                  color: Colors.white.withOpacity(0.8),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Cargando mapa...'),
                      ],
                    ),
                  ),
                ),
              ),
            // Botón de capas (layers)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _onLayersButtonPressed,
                  icon: const Icon(Icons.layers, color: Colors.black),
                  tooltip: 'Capas: elegir días',
                ),
              ),
            ),
            // Botón de ubicación del usuario
            if (_hasLocationPermission)
              Positioned(
                top: 80, // Debajo del botón de capas
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _centerOnUserLocation,
                    icon: const Icon(Icons.my_location, color: Colors.black),
                    tooltip: 'Mi ubicación',
                  ),
                ),
              ),
            // Hoja superpuesta con slider y contenido, sin bloquear gestos del mapa
            Positioned(
              top: mapHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x26000000), // 15% opacity black
                      blurRadius: 12,
                      offset: Offset(0, -4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Color(0x14000000), // 8% opacity black
                      blurRadius: 6,
                      offset: Offset(0, -2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Handle minimalista que NO intercepta gestos del mapa
                    Container(
                      height: 30,
                      width: double.infinity,
                      color: Colors.transparent,
                      child: Stack(
                        children: [
                          // Área del handle - SOLO el centro es arrastrable
                          Center(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (details) {
                                setState(() {
                                  final min = 0.0;
                                  final max = 1.0;
                                  final newFraction =
                                      (_mapHeightFraction * totalHeight +
                                              details.delta.dy) /
                                          totalHeight;
                                  _mapHeightFraction =
                                      newFraction.clamp(min, max);
                                  if (_mapHeightFraction <= 0.01) {
                                    _closeMap();
                                    _mapHeightFraction = 0.4;
                                  }
                                });
                              },
                              child: Container(
                                width: 150, // Área táctil más grande
                                height: 30,
                                color: Colors.transparent,
                                child: Center(
                                  child: Container(
                                    width: 200, // Handle visual más grande
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Contenido de la guía
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _guideScrollController,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_isMapVisible) _buildGuideHeader(),
                            if (!_isMapVisible) const SizedBox(height: 16),
                            _buildDaysSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onLayersButtonPressed() async {
    if (_guide == null || _guide!['days'].isEmpty) return;
    final allDays =
        _guide!['days'].map<int>((d) => d['dayNumber'] as int).toSet();
    final selected = Set<int>.from(_selectedDays);
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mostrar días en el mapa',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ..._guide!['days'].map<Widget>((day) {
                    final dayNumber = day['dayNumber'] as int;
                    return CheckboxListTile(
                      value: selected.contains(dayNumber),
                      title: Text('Día $dayNumber'),
                      onChanged: (checked) {
                        setModalState(() {
                          if (checked == true) {
                            selected.add(dayNumber);
                          } else {
                            selected.remove(dayNumber);
                          }
                        });
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Aplicar'),
                          onPressed: () {
                            Navigator.pop(context, selected);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((result) async {
      if (result is Set<int>) {
        setState(() {
          _selectedDays = result;
          _isMapLoading = true;
        });
        await _createMarkersFromActivities();
        setState(() {
          _isMapLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _guideScrollController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  // Métodos para gestionar actividades
  void _editActivity(Map<String, dynamic> activity) async {
    final safeActivity = {
      'id': activity['id'] ?? '',
      'title': activity['title'] ?? activity['name'] ?? '',
      'description': activity['description'] ?? '',
      'duration': activity['duration'] ?? 60,
      'day': activity['day'] ?? 1,
      'order': activity['order'],
      'images': activity['images'],
      'imageUrl': activity['imageUrl'],
      'city': activity['city'],
      'category': activity['category'],
      'likes': activity['likes'] ?? 0,
      'startTime': activity['startTime'],
      'endTime': activity['endTime'],
      'price': activity['price'],
    };

    await AnalyticsService.trackEvent('edit_activity_opened', parameters: {
      'guide_id': widget.guideId,
      'activity_id': activity['id'] ?? 'unknown',
    });

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditActivityDialog(
        activity: Activity.fromMap(safeActivity, safeActivity['id']),
        onSave: (updatedActivity) async {
          dynamic targetDay = _guide!['days'].firstWhere((day) =>
              (day['activities'] as List).any(
                  (a) => (a as Map<String, dynamic>)['id'] == activity['id']));

          if (targetDay == null) {
            throw Exception('No se pudo encontrar el día de la actividad');
          }

          final updatedActivities = (targetDay['activities'] as List)
              .map((a) {
                return (a as Map<String, dynamic>)['id'] == activity['id']
                    ? updatedActivity.toMap()
                    : a as Map<String, dynamic>;
              })
              .toList()
              .cast<Map<String, dynamic>>();

          final success = await ActivityService.updateDayActivities(
            guideId: widget.guideId,
            dayNumber: targetDay['dayNumber'],
            activities: updatedActivities,
          );

          if (!success) {
            throw Exception('Error al actualizar la actividad en el servidor');
          }

          setState(() {
            final dayIndex = _guide!['days']
                .indexWhere((d) => d['dayNumber'] == targetDay['dayNumber']);
            if (dayIndex != -1) {
              _guide!['days'][dayIndex]['activities'] = updatedActivities;
            }
          });
        },
      ),
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Actividad actualizada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<bool> _updateDayActivities(
      int dayNumber, List<Map<String, dynamic>> activities) async {
    return await ActivityService.updateDayActivities(
      guideId: widget.guideId,
      dayNumber: dayNumber,
      activities: activities,
    );
  }

  void _deleteActivity(Map<String, dynamic> activity) {
    DialogUtils.showCupertinoConfirmation(
      context: context,
      title: 'Eliminar actividad',
      content:
          '¿Estás seguro de que quieres eliminar "${activity['title']}"?\n\nEsta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmColor: Colors.red,
    ).then((confirmed) async {
      if (confirmed == true) {
        await _performDeleteActivity(activity);
      }
    });
  }

  Future<void> _performDeleteActivity(Map<String, dynamic> activity) async {
    try {
      await AnalyticsService.trackEvent('delete_activity_confirmed',
          parameters: {
            'guide_id': widget.guideId,
            'activity_id': activity['id'] ?? 'unknown',
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Eliminando actividad...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      dynamic targetDay = _guide!['days'].firstWhere((day) =>
          (day['activities'] as List)
              .any((a) => (a as Map<String, dynamic>)['id'] == activity['id']));

      if (targetDay == null) {
        throw Exception('No se pudo encontrar el día de la actividad');
      }

      final updatedActivities = (targetDay['activities'] as List)
          .where((a) => (a as Map<String, dynamic>)['id'] != activity['id'])
          .toList()
          .cast<Map<String, dynamic>>();

      final success = await ActivityService.updateDayActivities(
        guideId: widget.guideId,
        dayNumber: targetDay['dayNumber'],
        activities: updatedActivities,
      );

      if (!success) {
        throw Exception('Error al eliminar la actividad en el servidor');
      }

      setState(() {
        final dayIndex = _guide!['days']
            .indexWhere((d) => d['dayNumber'] == targetDay['dayNumber']);
        if (dayIndex != -1) {
          _guide!['days'][dayIndex]['activities'] = updatedActivities;
        }
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Actividad "${activity['title']}" eliminada correctamente'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Deshacer',
            textColor: Colors.white,
            onPressed: () {
              _undoDeleteActivity(activity, targetDay['dayNumber']);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar actividad: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _undoDeleteActivity(Map<String, dynamic> activity, int dayNumber) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Restaurando actividad...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      dynamic targetDay = _guide!['days'].firstWhere(
          (day) => day['dayNumber'] == dayNumber,
          orElse: () => null);

      List<Map<String, dynamic>> updatedActivities;

      if (targetDay != null) {
        updatedActivities = [
          ...targetDay['activities'],
          activity,
        ];
      } else {
        updatedActivities = [activity];
      }

      final success = await ActivityService.updateDayActivities(
        guideId: widget.guideId,
        dayNumber: dayNumber,
        activities: updatedActivities,
      );

      if (!success) {
        throw Exception('Error al restaurar la actividad en el servidor');
      }

      setState(() {
        if (targetDay != null) {
          final dayIndex =
              _guide!['days'].indexWhere((d) => d['dayNumber'] == dayNumber);
          if (dayIndex != -1) {
            _guide!['days'][dayIndex]['activities'] = updatedActivities;
          }
        } else {
          _guide!['days'].add({
            'dayNumber': dayNumber,
            'activities': updatedActivities,
          });
          _guide!['days']
              .sort((a, b) => a['dayNumber'].compareTo(b['dayNumber']));
        }
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Actividad "${activity['title']}" restaurada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al restaurar actividad: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openInCivitatis(Activity activity) async {
    // Construir la URL de Civitatis con el parámetro de afiliado
    final city = _guide?['city'] ?? '';
    final searchQuery = Uri.encodeComponent('${activity.title} $city');
    final civitatiasUrl =
        'https://www.civitatis.com/es/buscar?q=$searchQuery&aid=108172';

    try {
      final uri = Uri.parse(civitatiasUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('No se pudo abrir Civitatis para "${activity.title}"'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir Civitatis: $e'),
          ),
        );
      }
    }
  }

  void _addNewActivity() async {
    AnalyticsService.trackEvent('add_activity_started', parameters: {
      'guide_id': widget.guideId,
    });

    final city =
        _guide?['city'] ?? _guide?['destination'] ?? 'Ciudad desconocida';

    if (_guide!['days'].isEmpty) {
      _showAddActivityDialog(1, city);
      return;
    }

    if (_guide!['days'].length > 1) {
      _showDaySelector(city);
      return;
    }

    _showAddActivityDialog(_guide!['days'][0]['dayNumber'], city);
  }

  void _showDaySelector(String city) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar día'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _guide!['days'].map<Widget>((day) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  '${day['dayNumber']}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text('Día ${day['dayNumber']}'),
              subtitle: Text('${day['activities'].length} actividades'),
              onTap: () {
                Navigator.pop(context);
                _showAddActivityDialog(day['dayNumber'], city);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showAddActivityDialog(int dayNumber, String city) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddActivityDialog(
        dayNumber: dayNumber,
        guideId: widget.guideId,
        city: city,
        onSave: (newActivity) async {
          dynamic targetDay = _guide!['days']
              .firstWhere((day) => day['dayNumber'] == dayNumber);

          List<Map<String, dynamic>> updatedActivities;

          if (targetDay != null) {
            updatedActivities = [
              ...targetDay['activities'],
              newActivity.toMap()
            ];
          } else {
            updatedActivities = [newActivity.toMap()];
          }

          final success = await _updateDayActivities(
            dayNumber,
            updatedActivities,
          );

          if (!success) {
            throw Exception('Error al añadir la actividad en el servidor');
          }

          setState(() {
            if (targetDay != null) {
              final dayIndex = _guide!['days']
                  .indexWhere((d) => d['dayNumber'] == dayNumber);
              if (dayIndex != -1) {
                _guide!['days'][dayIndex]['activities'] = updatedActivities;
              }
            } else {
              _guide!['days'].add({
                'dayNumber': dayNumber,
                'activities': updatedActivities,
              });
              _guide!['days']
                  .sort((a, b) => a['dayNumber'].compareTo(b['dayNumber']));
            }
          });
        },
        initialSearchText: city, // <-- Añadido para forzar la ciudad
      ),
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Actividad "${result['title']}" añadida correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showOrganizeModal() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrganizeActivitiesScreen(
          dayActivities: (_guide!['days'] as List)
              .map((day) => DayActivities(
                    dayNumber: day['dayNumber'] as int,
                    activities: (day['activities'] as List)
                        .map((activity) => Activity.fromMap(
                            activity as Map<String, dynamic>,
                            (activity as Map<String, dynamic>)['id']
                                .toString()))
                        .toList(),
                  ))
              .toList(),
          guideId: widget.guideId,
          onReorganize: (reorganizedDays) async {
            // Mostrar indicador de carga
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 16),
                    Text('Guardando cambios...'),
                  ],
                ),
                duration: Duration(seconds: 30),
              ),
            );

            bool allUpdatesSuccessful = true;

            try {
              // Actualizar cada día que tenga cambios
              for (final day in reorganizedDays) {
                final success = await _updateDayActivities(
                  day.dayNumber,
                  day.activities.map((activity) => activity.toMap()).toList(),
                );

                if (!success) {
                  allUpdatesSuccessful = false;
                  break;
                }
              }

              if (allUpdatesSuccessful) {
                // Actualizar el estado local
                setState(() {
                  _guide!['days'] = reorganizedDays
                      .map((day) => {
                            'dayNumber': day.dayNumber,
                            'activities': day.activities
                                .map((activity) => activity.toMap())
                                .toList(),
                          })
                      .toList();
                });

                // Ocultar indicador de carga y mostrar éxito
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Actividades reorganizadas correctamente'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              } else {
                throw Exception('Error al guardar algunos cambios');
              }
            } catch (e) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al guardar cambios: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _toggleMenu() {
    setState(() {
      _isMenuExpanded = !_isMenuExpanded;
    });
  }

  void _openCollaborators() {
    // Tracking: abre modal de colaboradores
    AnalyticsService.trackEvent('open_collaborators', parameters: {
      'guide_id': widget.guideId,
    });
    print(
        'DEBUG: Abriendo modal de colaboradores para guía: ${widget.guideId}');
    showCollaboratorsModal(context, widget.guideId, widget.guideTitle);
  }

  // Métodos para manejar el gesto de swipe desde la izquierda

  void _handleSwipeEnd(details) {
    if (_isSwipeActive) {
      // Calcular la velocidad del gesto
      final velocity = details.velocity.pixelsPerSecond.dx;

      // Si la velocidad es suficiente hacia la derecha (>= 500)
      if (velocity >= 500) {
        _navigateToHome();
      }

      _isSwipeActive = false;
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }

  // Método para construir imagen placeholder con fallback local

  void _openTravelAgent() {
    // Tracking: abre agente IA
    AnalyticsService.trackEvent('open_travel_agent', parameters: {
      'guide_id': widget.guideId,
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TravelAgentChatWidget(
          guideId: widget.guideId,
          guideTitle: widget.guideTitle,
        ),
      ),
    );
  }

  // Funciones para Google Maps y Calendar (restauradas)
  void _exportToGoogleMaps(Map<String, dynamic> activity) async {
    // Exporta una única actividad a Google Maps.
    try {
      final LatLng? coords = _extractCoordinates(activity);
      String url;

      if (coords != null) {
        // Abrir Maps con coordenadas exactas
        url =
            'https://www.google.com/maps/search/?api=1&query=${coords.latitude},${coords.longitude}';
      } else {
        // Fallback: usar búsqueda por texto (nombre + ciudad)
        final city = _guide?['city'] ?? '';
        final query = Uri.encodeComponent('${activity['title'] ?? ''} $city');
        url = 'https://www.google.com/maps/search/?api=1&query=$query';
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir Google Maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportAllToGoogleMaps() async {
    // Mostrar modal premium fake en lugar de exportar realmente
    _showComingSoonModal();
  }

  /// Obtiene lugares de todas las actividades de la guía
  Future<List<Map<String, dynamic>>> _getPlacesFromActivities() async {
    final List<Map<String, dynamic>> places = [];
    final city = _guide?['city'] ?? '';

    if (_guide?['days'] == null) return places;

    print('🔍 Buscando lugares para ${_guide!['days'].length} días...');

    for (final day in _guide!['days']) {
      if (day['activities'] is List) {
        for (final activity in day['activities']) {
          final title = activity['title'] ?? '';
          if (title.isNotEmpty) {
            print('🔍 Procesando: $title en $city');

            // Extraer coordenadas si están disponibles
            final coords = _extractCoordinates(activity);

            final place = {
              'name': title,
              'address': '$title, $city',
              if (coords != null)
                'coordinates': {
                  'lat': coords.latitude,
                  'lng': coords.longitude,
                },
            };

            places.add(place);
            print('✅ Añadido lugar: $title');
          }
        }
      }
    }

    print('📊 Total de lugares encontrados: ${places.length}');
    return places;
  }

  /// Obtiene el placeId de una actividad usando Google Places API
  Future<String?> _getPlaceId(String activityName, String city) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        print('❌ GOOGLE_MAPS_API_KEY no configurada');
        return null;
      }

      // Buscar el lugar por nombre y ciudad
      final query = Uri.encodeComponent('$activityName $city');
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&key=$apiKey&language=es');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;

        if (results != null && results.isNotEmpty) {
          return results[0]['place_id'] as String;
        }
      }

      print('❌ No se encontró placeId para: $activityName en $city');
      return null;
    } catch (e) {
      print('❌ Error obteniendo placeId: $e');
      return null;
    }
  }

  /// Realiza la exportación a Google My Maps usando el backend
  Future<void> _performMyMapsExport(
      String mapName, List<Map<String, dynamic>> places) async {
    try {
      // Mostrar indicador de progreso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Creando mapa en Google My Maps...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Llamar al servicio de Google My Maps
      final result = await GoogleMapsExportService.exportToMyMaps(
        mapName: mapName,
        places: places,
      );

      // Ocultar indicador de progreso
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (result['success'] == true) {
        // Mostrar mensaje de éxito
        if (mounted) {
          GoogleMapsUtils.showSuccessSnackBar(
            context,
            'Mapa de Google My Maps creado exitosamente',
            placesAdded: result['added'],
          );

          // Mostrar enlaces para crear y gestionar el mapa
          if (result['sharedLink'] != null) {
            _showMyMapsDialog(
              result['sharedLink'],
              result['editLink'],
              result['searchLink'],
              result['coordinatesLink'],
            );
          }
        }

        // Tracking de éxito
        await AnalyticsService.trackEvent('my_maps_export_success',
            parameters: {
              'guide_id': widget.guideId,
              'places_added': result['added'],
            });
      } else {
        // Mostrar error
        if (mounted) {
          GoogleMapsUtils.showErrorSnackBar(context, result['error']);
        }

        // Tracking de error
        await AnalyticsService.trackEvent('my_maps_export_error', parameters: {
          'guide_id': widget.guideId,
          'error': result['error'],
        });
      }
    } catch (e) {
      // Ocultar indicador de progreso y mostrar error
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        GoogleMapsUtils.showErrorSnackBar(context, e.toString());
      }
    }
  }

  void _showMyMapsDialog(String sharedLink, String? editLink,
      String? searchLink, String? coordinatesLink) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.map, color: Colors.green),
            SizedBox(width: 8),
            Text('Mapa creado en Google My Maps'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Tu mapa ha sido creado! Puedes acceder y compartirlo con este enlace:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(sharedLink);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: Icon(Icons.open_in_new),
              label: Text('Abrir mapa en Google My Maps'),
            ),
            SizedBox(height: 8),
            SelectableText(
              sharedLink,
              style: TextStyle(fontSize: 14, color: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // Helper: extrae LatLng de una actividad en diferentes formatos
  LatLng? _extractCoordinates(Map<String, dynamic> activity) {
    Map<String, dynamic>? coords;
    if (activity['coordinates'] != null && activity['coordinates'] is Map) {
      coords = activity['coordinates'] as Map<String, dynamic>;
    } else if (activity['location'] != null && activity['location'] is Map) {
      coords = activity['location'] as Map<String, dynamic>;
    }

    if (coords != null) {
      final lat = (coords['latitude'] ?? coords['lat'])?.toDouble();
      final lng = (coords['longitude'] ?? coords['lng'])?.toDouble();
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  void _addToGoogleCalendar(Map<String, dynamic> activity) {
    _showComingSoonModal();
  }

  void _exportAllToGoogleCalendar() {
    _showComingSoonModal();
  }

  void _showComingSoonModal() {
    // Tracking: apertura de modal premium (funcionalidad próximamente/disponible solo premium)
    AnalyticsService.trackEvent('premium_modal_opened', parameters: {
      'guide_id': widget.guideId,
      'source': 'guide_detail',
    });

    showDialog(
      context: context,
      builder: (context) => const PremiumFeatureModal(source: 'guide_export'),
    );
  }

  void _openGuideMap() async {
    // Tracking: usuario abre mapa de guía
    await AnalyticsService.trackEvent('guide_map_opened', parameters: {
      'guide_id': widget.guideId,
    });
    try {
      if (_guide == null || _guide!['days'].isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay actividades para mostrar en el mapa'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Recopilar todas las actividades de todos los días
      List<Activity> allActivities = [];
      Set<int> allDays = {};
      for (final day in _guide!['days']) {
        if (day['activities'] != null && day['activities'] is List) {
          final dayNumber = day['dayNumber'] ?? 1; // Obtener el número de día
          allDays.add(dayNumber);
          for (final activity in day['activities']) {
            final activityWithDay = Map<String, dynamic>.from(activity);
            activityWithDay['day'] = dayNumber;
            final activityObj =
                Activity.fromMap(activityWithDay, activity['id'].toString());
            allActivities.add(activityObj);
          }
        }
      }
      if (allActivities.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay actividades para mostrar en el mapa'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_isMenuExpanded) {
        setState(() {
          _isMenuExpanded = false;
        });
      }
      // Expandir todos los días al abrir el mapa
      final expandedDays = <int>{};
      for (final day in _guide!['days']) {
        if (day['dayNumber'] != null) {
          expandedDays.add(day['dayNumber'] as int);
        }
      }
      setState(() {
        _allActivities = allActivities;
        _isMapVisible = true;
        _isMapLoading = true;
        _selectedDays = allDays; // Seleccionar todos los días por defecto
        _expandedDays = expandedDays; // Expandir todos los días
      });
      await _initializeIntegratedMap();
    } catch (e) {
      print('Error al abrir el mapa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el mapa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeIntegratedMap() async {
    try {
      await _getCityLocation();
      await _createMarkersFromActivities();
      if (mounted) {
        setState(() {
          _isMapLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error inicializando mapa integrado: $e');
      if (mounted) {
        setState(() {
          _isMapLoading = false;
          _isMapVisible = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el mapa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getCityLocation() async {
    try {
      final city = _guide?['city'] ?? '';
      final LatLng? cityLatLng =
          await GeocodingService.getLatLngFromAddress(city);
      if (cityLatLng != null) {
        _centerLocation = cityLatLng;
        print('🎯 Ciudad: $city -> $_centerLocation');
      } else {
        print('No se pudo geocodificar la ciudad: $city');
        _centerLocation = const LatLng(40.4168, -3.7038); // fallback Madrid
      }
    } catch (e) {
      print('Error obteniendo ubicación de la ciudad: $e');
      _centerLocation = const LatLng(40.4168, -3.7038); // fallback Madrid
    }
  }

  Future<void> _createMarkersFromActivities() async {
    print(
        '🎯 _createMarkersFromActivities() LLAMADA - _allActivities.length: ${_allActivities.length}');
    final Set<Marker> markers = {};
    final city = _guide?['city'] ?? '';
    bool hasUpdatedActivities = false;
    List<Activity> updatedActivities = [];
    _activityIdToLatLng.clear();
    _activityIdToPinNumber.clear();

    // Definir radio máximo desde el centro de la ciudad (en kilómetros)
    const double maxDistanceFromCityKm = 50.0; // 50km máximo desde el centro

    // Definir colores para los días
    final List<Color> dayColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.brown,
      Colors.cyan,
      Colors.indigo,
    ];
    // NUEVO: Primero asignar números de pin a TODAS las actividades según su orden en la guía
    int pinCounter = 1;
    for (final activity in _allActivities) {
      _activityIdToPinNumber[activity.id] = pinCounter;
      pinCounter++;
    }

    // Luego filtrar solo las actividades de los días seleccionados manteniendo sus números originales
    List<Activity> orderedActivities = [];
    for (final activity in _allActivities) {
      // Solo incluir si está en los días seleccionados
      if (_selectedDays.contains(activity.day)) {
        orderedActivities.add(activity);
      }
    }
    // Ahora crear los marcadores en el mismo orden
    // Map para contar cuántas actividades hay en cada localización
    Map<String, int> locationCount = {};
    Map<String, int> locationIndex = {};
    int geocodingRequests = 0;
    int activitiesFilteredByDistance = 0;
    for (final activity in orderedActivities) {
      LatLng? activityLocation = activity.location;

      // ✅ OPTIMIZACIÓN: Solo geocodificar si no tiene coordenadas guardadas
      if (activityLocation == null) {
        geocodingRequests++;
        print(
            '🔍 Geocodificando "${activity.title}" (no tiene coordenadas guardadas)');
        final nombreLimpio = limpiarNombreActividad(activity.title);
        final address = '$nombreLimpio, $city';
        activityLocation = await GeocodingService.getLatLngFromAddress(address);

        if (activityLocation != null) {
          print(
              '✅ Coordenadas obtenidas para "${activity.title}": $activityLocation');
          final updatedActivity = Activity(
            id: activity.id,
            title: activity.title,
            description: activity.description,
            duration: activity.duration,
            day: activity.day,
            order: activity.order,
            images: activity.images,
            city: activity.city,
            category: activity.category,
            likes: activity.likes,
            startTime: activity.startTime,
            endTime: activity.endTime,
            price: activity.price,
            location: activityLocation,
            googleRating: activity.googleRating,
            googleReview: activity.googleReview,
          );
          updatedActivities.add(updatedActivity);
          final idx = _allActivities.indexWhere((a) => a.id == activity.id);
          if (idx != -1) _allActivities[idx] = updatedActivity;
          hasUpdatedActivities = true;
        } else {
          print(
              '❌ No se pudieron obtener coordenadas para "${activity.title}"');
          updatedActivities.add(activity);
        }
      } else {
        // ✅ Actividad ya tiene coordenadas guardadas, no necesita geocodificación
        print('✅ "${activity.title}" ya tiene coordenadas: $activityLocation');
        updatedActivities.add(activity);
      }
      if (activityLocation != null) {
        // Validar que la actividad no esté demasiado lejos del centro de la ciudad
        if (_centerLocation != null) {
          final distanceKm =
              _calculateDistanceKm(_centerLocation!, activityLocation);
          if (distanceKm > maxDistanceFromCityKm) {
            print(
                '❌ "${activity.title}" está demasiado lejos del centro ($distanceKm km > $maxDistanceFromCityKm km). No se añadirá al mapa.');
            activitiesFilteredByDistance++;
            // Añadir a la lista de actividades actualizadas pero sin crear marcador
            updatedActivities.add(activity);
            continue; // Saltar esta actividad
          } else {
            print(
                '✅ "${activity.title}" está a $distanceKm km del centro (dentro del rango permitido)');
          }
        }

        // Generar clave única para la localización
        final locKey =
            '${activityLocation.latitude.toStringAsFixed(6)},${activityLocation.longitude.toStringAsFixed(6)}';
        locationCount[locKey] = (locationCount[locKey] ?? 0) + 1;
        final idx = locationIndex[locKey] ?? 0;
        locationIndex[locKey] = idx + 1;
        // Si hay más de una actividad en la misma localización, aplicar offset
        LatLng markerPosition = activityLocation;
        if (locationCount[locKey]! > 1) {
          // Offset en círculo
          final double offsetMeters = 25.0 * idx; // 18m de separación
          final double earthRadius = 6378137.0;
          final double angle = (2 * pi / locationCount[locKey]!) * idx;
          final double dLat =
              (offsetMeters * cos(angle)) / earthRadius * (180 / pi);
          final double dLng = (offsetMeters * sin(angle)) /
              (earthRadius * cos(activityLocation.latitude * pi / 180)) *
              (180 / pi);
          markerPosition = LatLng(
            activityLocation.latitude + dLat,
            activityLocation.longitude + dLng,
          );
        }
        final color = dayColors[(activity.day - 1) % dayColors.length];
        final BitmapDescriptor customIcon = await createCategoryMarker(
          activity,
          _activityIdToPinNumber[activity.id]!,
          selected: true,
          baseColor: color,
        );
        final markerId = MarkerId('activity_${activity.title}');
        _activityIdToLatLng[activity.id] = markerPosition;
        markers.add(
          Marker(
            markerId: markerId,
            position: markerPosition,
            infoWindow: InfoWindow(
              title:
                  '📍 ${_activityIdToPinNumber[activity.id]}. ${activity.title}',
              snippet: activity.googleRating != null
                  ? '⭐ ${activity.googleRating!.toStringAsFixed(1)}'
                  : '',
            ),
            icon: customIcon,
            onTap: () => _onMarkerTapped(activity, city, markerId,
                pinNumber: _activityIdToPinNumber[activity.id]),
          ),
        );
      }
    }
    if (hasUpdatedActivities) {
      await _saveUpdatedActivitiesWithLocations(updatedActivities);
    }

    // Resumen de optimización
    print('🎯 Marcadores creados: ${markers.length}');
    print('🔍 Peticiones de geocodificación realizadas: $geocodingRequests');
    print(
        '✅ Actividades con coordenadas reutilizadas: ${orderedActivities.length - geocodingRequests}');
    if (activitiesFilteredByDistance > 0) {
      print(
          '⚠️ Actividades filtradas por distancia (muy lejas): $activitiesFilteredByDistance');
    }

    setState(() {
      _markers = markers;
    });
  }

  // NUEVO: Al hacer tap en el marcador, navegar a la actividad en la guía
  void _onMarkerTapped(Activity activity, String city, MarkerId markerId,
      {int? pinNumber}) async {
    setState(() {
      _selectedActivityId = activity.id;
    });

    // Expandir el día correspondiente a la actividad
    setState(() {
      _expandedDays.add(activity.day);
    });

    // Esperar un momento para que se actualice la UI
    await Future.delayed(const Duration(milliseconds: 300));

    // Scroll hasta la actividad (calculando posición aproximada)
    _scrollToActivity(activity);

    // Limpiar la selección después de 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _selectedActivityId = null;
        });
      }
    });

    // Cargar información adicional en segundo plano sin mostrar modal
    final placeInfoFuture = PlacesService.getPlaceInfo(activity.title, city);
    placeInfoFuture.then((placeInfo) {
      if (placeInfo != null &&
          (placeInfo.rating != null || placeInfo.review != null)) {
        final bool needsUpdate = (activity.googleRating != placeInfo.rating) ||
            (activity.googleReview != placeInfo.review);
        if (needsUpdate) {
          _saveGoogleInfoToFirestore(
              activity, placeInfo.rating, placeInfo.review);
        }
      }
    });
  }

  // Método para hacer scroll hasta una actividad específica
  void _scrollToActivity(Activity activity) {
    if (!_guideScrollController.hasClients) return;

    // En lugar de calcular posiciones estimadas, buscar directamente la actividad
    // y hacer scroll hasta el final menos un offset para centrarla mejor

    // Primero expandir el día de la actividad si no está expandido
    if (!_expandedDays.contains(activity.day)) {
      setState(() {
        _expandedDays.add(activity.day);
      });
      // Esperar un momento a que se actualice la UI
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToActivity(activity);
      });
      return;
    }

    // Hacer scroll hasta una posición que asegure que la actividad sea visible
    // Usar un porcentaje del scroll máximo basado en la posición relativa de la actividad
    final maxScrollExtent = _guideScrollController.position.maxScrollExtent;

    // Calcular qué porcentaje de la guía representa esta actividad
    int totalActivities = 0;
    int activitiesBeforeTarget = 0;

    for (final day in _guide!['days']) {
      final dayNumber = day['dayNumber'] as int;
      final activities = day['activities'] as List;

      if (dayNumber < activity.day) {
        // Todas las actividades de días anteriores
        activitiesBeforeTarget += activities.length;
        totalActivities += activities.length;
      } else if (dayNumber == activity.day) {
        // Actividades antes de la target en el mismo día
        final activityIndex =
            activities.indexWhere((a) => a['id'] == activity.id);
        if (activityIndex != -1) {
          activitiesBeforeTarget += activityIndex;
        }
        totalActivities += activities.length;
      } else {
        // Actividades de días posteriores
        totalActivities += activities.length;
      }
    }

    if (totalActivities == 0) return;

    // Calcular posición como porcentaje y añadir un offset proporcional
    final activityRatio = activitiesBeforeTarget / totalActivities;
    final basePosition = maxScrollExtent * activityRatio;

    // Offset proporcional: menos para las primeras actividades, más para las últimas
    // Para las primeras (ratio cercano a 0): offset pequeño
    // Para las últimas (ratio cercano a 1): offset mayor
    final proportionalOffset = maxScrollExtent *
        0.1 *
        activityRatio; // 10% del scroll máximo como base
    final minOffset = 50.0; // Offset mínimo
    final dynamicOffset = minOffset + proportionalOffset;

    final targetPosition =
        (basePosition + dynamicOffset).clamp(0.0, maxScrollExtent);

    _guideScrollController.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  // NUEVO: Al pulsar una actividad en la lista con el mapa abierto, centrar en el pin (sin abrir modal)
  void _focusOnActivityFromList(Activity activity) async {
    final latLng = _activityIdToLatLng[activity.id];
    if (latLng != null && _mapController != null) {
      await _mapController!
          .animateCamera(CameraUpdate.newLatLngZoom(latLng, 15.5));
    }
  }

  // NUEVO: Guardar rating y review de Google Maps en Firestore
  Future<void> _saveGoogleInfoToFirestore(
      Activity activity, double? rating, String? review) async {
    try {
      // Buscar el día y la actividad
      final day = _guide!['days'].firstWhere((d) => (d['activities'] as List)
          .any((a) => (a as Map<String, dynamic>)['id'] == activity.id));
      final dayNumber = day['dayNumber'];
      final activities = (day['activities'] as List).map((a) {
        if ((a as Map<String, dynamic>)['id'] == activity.id) {
          final updated = Map<String, dynamic>.from(a);
          updated['googleRating'] = rating;
          updated['googleReview'] = review;
          return updated;
        }
        return a;
      }).toList();
      await _updateDayActivities(dayNumber, activities);
      // Actualizar el estado local
      setState(() {
        final dayIndex =
            _guide!['days'].indexWhere((d) => d['dayNumber'] == dayNumber);
        if (dayIndex != -1) {
          _guide!['days'][dayIndex]['activities'] = activities;
        }
      });
    } catch (e) {
      print('Error guardando rating/review de Google Maps: $e');
    }
  }

  Future<void> _saveUpdatedActivitiesWithLocations(
      List<Activity> activities) async {
    try {
      // Solo actualizar las coordenadas de las actividades existentes sin cambiar su estructura de días
      for (final activity in activities) {
        if (activity.location != null) {
          // Buscar la actividad en la estructura original de la guía
          bool found = false;
          for (final day in _guide!['days']) {
            if (day['activities'] != null && day['activities'] is List) {
              final dayActivities = day['activities'] as List;
              for (int i = 0; i < dayActivities.length; i++) {
                final existingActivity =
                    dayActivities[i] as Map<String, dynamic>;
                if (existingActivity['id'] == activity.id) {
                  // Solo actualizar las coordenadas sin cambiar otros campos
                  existingActivity['coordinates'] = {
                    'latitude': activity.location!.latitude,
                    'longitude': activity.location!.longitude,
                  };
                  // También actualizar rating y review si están disponibles
                  if (activity.googleRating != null) {
                    existingActivity['googleRating'] = activity.googleRating;
                  }
                  if (activity.googleReview != null) {
                    existingActivity['googleReview'] = activity.googleReview;
                  }
                  found = true;
                  break;
                }
              }
              if (found) break;
            }
          }
        }
      }

      // Actualizar cada día en Firestore manteniendo la estructura original
      for (final day in _guide!['days']) {
        final dayNumber = day['dayNumber'] as int;
        final dayActivitiesList = day['activities'] as List;
        final dayActivities = dayActivitiesList
            .map((activity) => activity as Map<String, dynamic>)
            .toList();

        final success = await _updateDayActivities(dayNumber, dayActivities);

        if (success) {
          print('✅ Día $dayNumber actualizado con coordenadas');
        } else {
          print('❌ Error actualizando día $dayNumber');
        }
      }

      // El estado local ya está actualizado arriba
      setState(() {
        // Trigger rebuild para mostrar los cambios
      });
    } catch (e) {
      print('❌ Error guardando coordenadas: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    print('🗺️ Mapa integrado creado exitosamente');
    _mapController = controller;
    _mapController!.setMapStyle(_greyRoadsMapStyle);

    // Centrar el mapa después de un breve delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_centerLocation != null && _mapController != null) {
        print('📍 Centrando mapa integrado en: $_centerLocation');
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_centerLocation!, 12.0),
        );
      }
    });
  }

  void _closeMap() {
    setState(() {
      _isMapVisible = false;
      _markers.clear();
      _polylines.clear();
      _allActivities.clear();
    });

    // Tracking: usuario cierra mapa de guía
    AnalyticsService.trackEvent('guide_map_closed', parameters: {
      'guide_id': widget.guideId,
    });
  }

  /// Calcula la distancia en kilómetros entre dos coordenadas usando la fórmula de Haversine
  double _calculateDistanceKm(LatLng point1, LatLng point2) {
    const double earthRadiusKm = 6371.0;

    final double lat1Rad = point1.latitude * (pi / 180);
    final double lat2Rad = point2.latitude * (pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * (pi / 180);

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  // Descarga la guía como PDF desde el backend
  /// Guarda la guía de invitado y navega al onboarding para crear cuenta
  Future<void> _saveGuestGuide() async {
    if (_guide == null) return;

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Guardar datos de la guía como temporal usando GuestGuideService
      final guestGuideData = {
        'destination': _guide!['city'],
        'startDate': _guide!['startDate'] is DateTime
            ? (_guide!['startDate'] as DateTime).toIso8601String()
            : (_guide!['startDate'] as Timestamp).toDate().toIso8601String(),
        'endDate': _guide!['endDate'] is DateTime
            ? (_guide!['endDate'] as DateTime).toIso8601String()
            : (_guide!['endDate'] as Timestamp).toDate().toIso8601String(),
        'adults': _guide!['travelers'] ?? 1,
        'children': 0,
        'travelModes': _guide!['travelModes'] ?? ['Cultural'],
        'generatedGuideId': widget.guideId, // Guardar ID de la guía generada
        'activities':
            _guide!['days'], // Guardar todas las actividades generadas
      };

      await GuestGuideService.saveTemporaryGuide(guestGuideData);

      // Cerrar loading
      if (mounted) Navigator.of(context).pop();

      // Trackear evento
      await AnalyticsService.trackEvent('guest_guide_save_started',
          parameters: {
            'guide_id': widget.guideId,
            'destination': _guide!['city'],
            'days': (_guide!['days'] as List).length,
          });

      // Mostrar mensaje explicativo
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¡Genial! 💖'),
            content: const Text(
              'Para guardar tu guía personalizada necesitamos crear tu cuenta.\n\n'
              'Solo te tomará 2 minutos y podrás acceder a todas tus guías desde cualquier dispositivo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToOnboarding();
                },
                child: const Text('¡Crear cuenta!'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Cerrar loading si hay error
      if (mounted) Navigator.of(context).pop();

      print('Error guardando guía de invitado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando la guía: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Navega al onboarding flow
  void _navigateToOnboarding() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/onboarding',
      (route) => false,
    );
  }

  Future<void> _downloadGuide() async {
    try {
      if (_guide == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No se pudo cargar la información de la guía')),
          );
        }
        return;
      }

      // Tracking: usuario pulsa descargar guía
      await AnalyticsService.trackEvent('download_guide_clicked', parameters: {
        'guide_id': widget.guideId,
      });

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Generando PDF...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Llamada al backend para generar PDF (versión directa sin Puppeteer)
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final response = await http.post(
        Uri.parse('$baseUrl/guides/${widget.guideId}/export-pdf-direct'),
        headers: {
          'Content-Type': 'application/json',
          if (_auth.currentUser != null)
            'Authorization': 'Bearer ${await _auth.currentUser!.getIdToken()}',
        },
      );

      if (response.statusCode == 200) {
        // Guardar el PDF temporal para compartir
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/guia_tourify.pdf');
        await file.writeAsBytes(response.bodyBytes);

        // Compartir el PDF
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Guía de viaje: ${widget.guideTitle}',
          subject: 'Guía de viaje generada con Tourify',
        );

        if (mounted) _showDownloadSuccessMessage();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al descargar la guía como PDF: $e');
      if (mounted) _showDownloadErrorMessage();
    }
  }

  // Mostrar mensaje de éxito de descarga
  void _showDownloadSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                  '¡Guía preparada para descargar!\nElige dónde guardarla desde el menú de compartir.'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 100, left: 16, right: 16),
      ),
    );
  }

  // Mostrar mensaje de error de descarga
  void _showDownloadErrorMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Error al descargar la guía'),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 100, left: 16, right: 16),
      ),
    );
  }

  // NUEVO: Limitar la review a un párrafo/corto
  String _shortenReview(String review) {
    if (review.length > 900) {
      return review.substring(0, 897) + '...';
    }
    return review;
  }

  // NUEVO: Al hacer tap en el mapa (no en un marcador), buscar lugares cercanos
  void _onMapTapped(LatLng position) async {
    print('🗺️ Tap en mapa en posición: $position');

    // Buscar lugares cercanos en esta posición
    final nearbyPlaces = await _searchNearbyPlaces(position);

    if (nearbyPlaces.isNotEmpty) {
      _showAddPlaceModal(position, nearbyPlaces);
    } else {
      // No se encontraron lugares, mostrar opción de añadir lugar personalizado
      _showAddCustomPlaceModal(position);
    }
  }

  // Buscar lugares cercanos usando Places API
  Future<List<NearbyPlace>> _searchNearbyPlaces(LatLng position) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) return [];

      // Buscar lugares cercanos en un radio de 50 metros
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
          'location=${position.latitude},${position.longitude}&'
          'radius=50&'
          'type=point_of_interest|restaurant|tourist_attraction|museum|park&'
          'language=es&'
          'key=$apiKey');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .take(3)
            .map((place) => NearbyPlace(
                  placeId: place['place_id'],
                  name: place['name'],
                  rating: place['rating']?.toDouble(),
                  types: List<String>.from(place['types'] ?? []),
                  vicinity: place['vicinity'],
                  priceLevel: place['price_level'],
                ))
            .toList();
      }
    } catch (e) {
      print('Error buscando lugares cercanos: $e');
    }
    return [];
  }

  // Modal para añadir un lugar de la lista de lugares cercanos
  void _showAddPlaceModal(LatLng position, List<NearbyPlace> places) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_location, color: Colors.green, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Añadir lugar a la guía',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Lugares encontrados cerca:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 16),
              ...places
                  .map((place) => Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            _getIconForPlaceType(place.types),
                            color: Colors.blue,
                            size: 24,
                          ),
                          title: Text(
                            place.name,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (place.vicinity != null) Text(place.vicinity!),
                              if (place.rating != null)
                                Row(
                                  children: [
                                    Icon(Icons.star,
                                        color: Colors.amber, size: 16),
                                    SizedBox(width: 4),
                                    Text('${place.rating!.toStringAsFixed(1)}'),
                                  ],
                                ),
                            ],
                          ),
                          trailing: Icon(Icons.add, color: Colors.green),
                          onTap: () {
                            Navigator.pop(context);
                            _showAddToGuideDialog(place, position);
                          },
                        ),
                      ))
                  .toList(),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Añadir lugar personalizado'),
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddCustomPlaceModal(position);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Modal para añadir un lugar personalizado
  void _showAddCustomPlaceModal(LatLng position) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'cultural';
    int selectedDay = _selectedDays.isNotEmpty ? _selectedDays.first : 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.add_location, color: Colors.green),
                SizedBox(width: 8),
                Text('Nuevo lugar'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del lugar',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'cultural', child: Text('Cultural')),
                      DropdownMenuItem(
                          value: 'gastronomia', child: Text('Gastronomía')),
                      DropdownMenuItem(
                          value: 'entretenimiento',
                          child: Text('Entretenimiento')),
                      DropdownMenuItem(
                          value: 'compras', child: Text('Compras')),
                      DropdownMenuItem(
                          value: 'naturaleza', child: Text('Naturaleza')),
                      DropdownMenuItem(
                          value: 'alojamiento', child: Text('Alojamiento')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedDay,
                    decoration: InputDecoration(
                      labelText: 'Añadir al día',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: _getAvailableDays()
                        .map((day) => DropdownMenuItem(
                              value: day,
                              child: Text('Día $day'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedDay = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    Navigator.pop(context);
                    _addCustomPlaceToGuide(
                      nameController.text.trim(),
                      descriptionController.text.trim(),
                      selectedCategory,
                      selectedDay,
                      position,
                    );
                  }
                },
                child: Text('Añadir'),
              ),
            ],
          );
        });
      },
    );
  }

  // Dialog para añadir lugar de Google Places a la guía
  void _showAddToGuideDialog(NearbyPlace place, LatLng position) {
    String selectedCategory = _getCategoryFromPlaceTypes(place.types);
    int selectedDay = _selectedDays.isNotEmpty ? _selectedDays.first : 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Añadir "${place.name}" a la guía'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (place.rating != null)
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      SizedBox(width: 4),
                      Text('${place.rating!.toStringAsFixed(1)} / 5.0'),
                    ],
                  ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'cultural', child: Text('Cultural')),
                    DropdownMenuItem(
                        value: 'gastronomia', child: Text('Gastronomía')),
                    DropdownMenuItem(
                        value: 'entretenimiento',
                        child: Text('Entretenimiento')),
                    DropdownMenuItem(value: 'compras', child: Text('Compras')),
                    DropdownMenuItem(
                        value: 'naturaleza', child: Text('Naturaleza')),
                    DropdownMenuItem(
                        value: 'alojamiento', child: Text('Alojamiento')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedCategory = value;
                      });
                    }
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedDay,
                  decoration: InputDecoration(
                    labelText: 'Añadir al día',
                    border: OutlineInputBorder(),
                  ),
                  items: _getAvailableDays()
                      .map((day) => DropdownMenuItem(
                            value: day,
                            child: Text('Día $day'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedDay = value;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _addGooglePlaceToGuide(
                      place, selectedCategory, selectedDay, position);
                },
                child: Text('Añadir'),
              ),
            ],
          );
        });
      },
    );
  }

  // Obtener días disponibles en la guía
  List<int> _getAvailableDays() {
    final days = <int>[];
    if (_guide != null && _guide!['days'] != null) {
      for (final day in _guide!['days']) {
        days.add(day['dayNumber'] as int);
      }
    }
    return days..sort();
  }

  // Reconstituir la lista de actividades desde la guía actual
  void _rebuildActivitiesFromGuide() {
    print('🚀 _rebuildActivitiesFromGuide() LLAMADA');
    if (_guide == null || _guide!['days'] == null) {
      print('❌ _rebuildActivitiesFromGuide() - Guía o días son null');
      return;
    }

    final List<Activity> allActivities = [];
    int activitiesWithCoordinates = 0;
    int activitiesWithoutCoordinates = 0;

    for (final day in _guide!['days']) {
      final dayNumber = day['dayNumber'] as int;
      final activities = day['activities'] as List?;

      if (activities != null) {
        for (int i = 0; i < activities.length; i++) {
          final activityData = activities[i] as Map<String, dynamic>;

          // Debug: Imprimir estructura de la actividad
          print(
              '🔍 Actividad ${i + 1} del día $dayNumber: "${activityData['title']}"');
          print(
              '   - Tiene coordinates: ${activityData['coordinates'] != null}');
          print('   - Tiene location: ${activityData['location'] != null}');
          if (activityData['coordinates'] != null) {
            print('   - coordinates: ${activityData['coordinates']}');
          }
          if (activityData['location'] != null) {
            print('   - location: ${activityData['location']}');
          }

          // Convertir coordenadas a LatLng si existen
          LatLng? location;
          Map<String, dynamic>? coords;

          // Verificar primero en 'coordinates', luego en 'location' (compatibilidad)
          if (activityData['coordinates'] != null) {
            coords = activityData['coordinates'] as Map<String, dynamic>;
          } else if (activityData['location'] != null) {
            coords = activityData['location'] as Map<String, dynamic>;
          }

          if (coords != null) {
            final lat = coords['latitude']?.toDouble();
            final lng = coords['longitude']?.toDouble();

            if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
              location = LatLng(lat, lng);
              activitiesWithCoordinates++;

              // Si las coordenadas estaban en 'location', migrarlas a 'coordinates'
              if (activityData['location'] != null &&
                  activityData['coordinates'] == null) {
                print(
                    '🔄 Migrando coordenadas de "location" a "coordinates" para "${activityData['title']}"');
                activityData['coordinates'] = coords;
                activityData.remove('location'); // Limpiar el campo viejo
              }
            } else {
              activitiesWithoutCoordinates++;
            }
          } else {
            activitiesWithoutCoordinates++;
          }

          final activity = Activity(
            id: activityData['id'] ?? 'activity_${dayNumber}_$i',
            title: activityData['title'] ?? '',
            description: activityData['description'] ?? '',
            duration: (activityData['duration'] as num?)?.toInt() ?? 60,
            day: dayNumber,
            order: i,
            images: List<String>.from(activityData['images'] ?? []),
            city: activityData['city'] ?? _guide?['city'] ?? '',
            category: activityData['category'] ?? 'cultural',
            likes: (activityData['likes'] as num?)?.toInt() ?? 0,
            location: location,
            googleRating: (activityData['googleRating'] as num?)?.toDouble(),
            price: activityData['price'] != null
                ? activityData['price'].toString()
                : null,
          );

          allActivities.add(activity);
        }
      }
    }

    _allActivities = allActivities;

    // Log del estado de coordenadas
    print('📍 Actividades cargadas: ${allActivities.length} total');
    print('✅ Con coordenadas guardadas: $activitiesWithCoordinates');
    print(
        '🔍 Sin coordenadas (requieren geocodificación): $activitiesWithoutCoordinates');
  }

  // Añadir lugar personalizado a la guía
  Future<void> _addCustomPlaceToGuide(
    String name,
    String description,
    String category,
    int day,
    LatLng position,
  ) async {
    try {
      // Crear nueva actividad
      final newActivity = {
        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
        'title': name,
        'description': description,
        'category': category,
        'day': day,
        'duration': 60, // duración por defecto
        'likes': 0,
        'images': <String>[],
        'coordinates': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'city': _guide?['city'] ?? '',
      };

      // Añadir a la estructura local
      final dayIndex = _guide!['days'].indexWhere((d) => d['dayNumber'] == day);
      if (dayIndex != -1) {
        final activities = List.from(_guide!['days'][dayIndex]['activities']);
        activities.add(newActivity);
        _guide!['days'][dayIndex]['activities'] = activities;

        // Guardar en Firestore
        await _updateDayActivities(
            day, activities.cast<Map<String, dynamic>>());

        // Actualizar la lista de actividades para el mapa
        _rebuildActivitiesFromGuide();

        // Asegurar que el día esté seleccionado para mostrar el nuevo marcador
        if (!_selectedDays.contains(day)) {
          setState(() {
            _selectedDays.add(day);
          });
        }

        // Actualizar marcadores en el mapa
        await _createMarkersFromActivities();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$name" añadido al día $day'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error añadiendo lugar personalizado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al añadir el lugar'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Añadir lugar de Google Places a la guía
  Future<void> _addGooglePlaceToGuide(
    NearbyPlace place,
    String category,
    int day,
    LatLng position,
  ) async {
    try {
      // Llamar al backend para generar descripción y foto
      final apiService = ApiService();
      final city = _guide?['city'] ?? '';
      final generated = await apiService.createActivityFromPlace(
        activityName: place.name,
        cityName: city,
      );

      if (generated == null) {
        throw Exception('No se pudo generar la actividad automáticamente');
      }

      // Construir la nueva actividad usando los datos generados y los datos locales
      final newActivity = {
        'id':
            'google_${place.placeId}_${DateTime.now().millisecondsSinceEpoch}',
        'title': generated['title'] ?? place.name,
        'description': generated['description'] ?? place.vicinity ?? '',
        'category': generated['categoria'] ?? category,
        'day': day,
        'duration': _parseDurationToMinutes(generated['duration']) ?? 60,
        'likes': 0,
        'images': generated['images'] is List
            ? List<String>.from(generated['images'])
            : <String>[],
        'coordinates': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'city': city,
        'googleRating': place.rating,
        'googlePlaceId': place.placeId,
        // Otros campos opcionales
        'location': generated['location'],
      };

      // Añadir a la estructura local
      final dayIndex = _guide!['days'].indexWhere((d) => d['dayNumber'] == day);
      if (dayIndex != -1) {
        final activities = List.from(_guide!['days'][dayIndex]['activities']);
        activities.add(newActivity);
        _guide!['days'][dayIndex]['activities'] = activities;

        // Guardar en Firestore
        await _updateDayActivities(
            day, activities.cast<Map<String, dynamic>>());

        // Actualizar la lista de actividades para el mapa
        _rebuildActivitiesFromGuide();

        // Asegurar que el día esté seleccionado para mostrar el nuevo marcador
        if (!_selectedDays.contains(day)) {
          setState(() {
            _selectedDays.add(day);
          });
        }

        // Actualizar marcadores en el mapa
        await _createMarkersFromActivities();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${place.name}" añadido al día $day'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error añadiendo lugar de Google: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al añadir el lugar'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Helper para convertir duración tipo "HH:MM" a minutos
  int? _parseDurationToMinutes(dynamic duration) {
    if (duration == null) return null;
    if (duration is int) return duration;
    if (duration is String) {
      final parts = duration.split(":");
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return h * 60 + m;
      }
      return int.tryParse(duration);
    }
    return null;
  }

  // Obtener icono basado en el tipo de lugar
  IconData _getIconForPlaceType(List<String> types) {
    if (types.contains('restaurant') || types.contains('food'))
      return Icons.restaurant;
    if (types.contains('tourist_attraction')) return Icons.attractions;
    if (types.contains('museum')) return Icons.museum;
    if (types.contains('park')) return Icons.park;
    if (types.contains('shopping_mall') || types.contains('store'))
      return Icons.shopping_bag;
    if (types.contains('lodging')) return Icons.hotel;
    return Icons.place;
  }

  // Obtener categoría basada en los tipos de lugar de Google
  String _getCategoryFromPlaceTypes(List<String> types) {
    if (types.contains('restaurant') ||
        types.contains('food') ||
        types.contains('meal_takeaway')) {
      return 'gastronomia';
    }
    if (types.contains('shopping_mall') ||
        types.contains('store') ||
        types.contains('clothing_store')) {
      return 'compras';
    }
    if (types.contains('park') || types.contains('natural_feature')) {
      return 'naturaleza';
    }
    if (types.contains('lodging') || types.contains('hotel')) {
      return 'alojamiento';
    }
    if (types.contains('night_club') || types.contains('amusement_park')) {
      return 'entretenimiento';
    }
    return 'cultural'; // Por defecto
  }
}
