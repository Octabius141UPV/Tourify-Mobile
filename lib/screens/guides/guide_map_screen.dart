import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:tourify_flutter/data/activity.dart';
import 'package:tourify_flutter/config/app_colors.dart';
import 'package:tourify_flutter/services/map/geocoding_service.dart';
import 'package:tourify_flutter/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:tourify_flutter/services/map/places_service.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:tourify_flutter/widgets/map/day_selector_header.dart';
import 'package:tourify_flutter/widgets/map/activity_list.dart';
import 'package:tourify_flutter/widgets/map/map_loading_overlay.dart';
import 'package:tourify_flutter/widgets/map/activity_marker_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourify_flutter/widgets/common/custom_bottom_navigation_bar.dart';
import 'package:tourify_flutter/utils/activity_utils.dart';

/// Pantalla de mapa específica para mostrar las actividades de una guía
class GuideMapScreen extends StatefulWidget {
  final String guideTitle;
  final String city;
  final List<Activity> activities;

  const GuideMapScreen({
    super.key,
    required this.guideTitle,
    required this.city,
    required this.activities,
  });

  @override
  State<GuideMapScreen> createState() => _GuideMapScreenState();
}

class _GuideMapScreenState extends State<GuideMapScreen>
    with TickerProviderStateMixin {
  // =================== VARIABLES Y CONTROLADORES ===================
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  LatLng? _centerLocation;
  int _selectedActivityIndex = -1;
  double _loadingProgress = 0.0;
  final MapType _currentMapType = MapType.normal;
  List<PlaceInfo?> _placesInfo = [];
  Set<int> _selectedDays = {};
  Set<Polyline> _polylines = {};
  final ValueNotifier<double> _sheetFraction = ValueNotifier(0.5);

  // Variables para la ubicación del usuario
  final LocationService _locationService = LocationService();
  LatLng? _userLocation;
  bool _hasLocationPermission = false;

  // =================== CONTROLADORES DE ANIMACIÓN ===================
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Estilo gris para las carreteras (string JSON embebido)
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

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeUserLocation();
    _initializeMapWithTimeout();
    _loadMarkers();
    _loadPlacesInfo();
    _initSelectedDays();
    _startEntranceAnimation();
  }

  /// Inicializa las animaciones de entrada
  void _initAnimations() {
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
    ));
  }

  /// Inicia la animación de entrada
  void _startEntranceAnimation() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _entranceController.forward();
      }
    });
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

  void _initSelectedDays() {
    if (widget.activities.isNotEmpty) {
      setState(() {
        // Inicializar con todos los días disponibles seleccionados
        _selectedDays = widget.activities.map((a) => a.day).toSet();
      });
    }
  }

  List<int> get _availableDays {
    final days = widget.activities.map((a) => a.day).toSet().toList();
    days.sort();
    return days;
  }

  List<Activity> get _activitiesOfSelectedDays {
    final acts =
        widget.activities.where((a) => _selectedDays.contains(a.day)).toList();
    // Ordenar primero por día, luego por orden dentro del día
    acts.sort((a, b) {
      final dayComparison = a.day.compareTo(b.day);
      if (dayComparison != 0) return dayComparison;
      return (a.order ?? 0).compareTo(b.order ?? 0);
    });
    return acts;
  }

  Future<void> _initializeMapWithTimeout() async {
    try {
      print('⏱️ Iniciando carga con timeout de 10 segundos');
      await Future.any([
        _initializeMap(),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException('Timeout al cargar el mapa');
        }),
      ]);
      print('✅ Inicialización completada exitosamente');
    } catch (e) {
      print('❌ Error en inicialización: $e');
      if (e is TimeoutException) {
        print('⏰ Timeout al cargar el mapa');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'El mapa tardó demasiado en cargar. Verifica tu conexión a internet.';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Error al cargar el mapa: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _initializeMap() async {
    try {
      print('🗺️ Iniciando carga del mapa...');

      // Establecer progreso inicial inmediatamente
      if (mounted) {
        setState(() {
          _loadingProgress = 0.2;
          _hasError = false;
          _errorMessage = '';
        });
      }

      // Paso 1: Obtener ubicación de la ciudad (sin delay)
      print('📍 Obteniendo ubicación de la ciudad: ${widget.city}');
      await _getCityLocation();
      print('📍 Ubicación encontrada: $_centerLocation');

      if (mounted) {
        setState(() {
          _loadingProgress = 0.6;
        });
      }

      // Paso 2: Crear marcadores (simplificado)
      print(
          '📌 Creando marcadores para ${widget.activities.length} actividades...');
      await _createMarkersFromActivities(); // Hacer síncrono
      print('📌 Marcadores creados: ${_markers.length}');

      if (mounted) {
        setState(() {
          _loadingProgress = 0.9;
        });
      }

      // Verificar que todo esté listo
      if (_centerLocation == null) {
        throw Exception('No se pudo obtener la ubicación de ${widget.city}');
      }

      // Finalizar
      print('✅ Mapa listo para mostrar');
      if (mounted) {
        setState(() {
          _loadingProgress = 1.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error inicializando mapa: $e');
      String errorMsg =
          'Error inesperado al cargar el mapa. Inténtalo de nuevo.';

      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  /// Obtiene las coordenadas reales de la ciudad usando GeocodingService
  Future<void> _getCityLocation() async {
    try {
      final LatLng? cityLatLng =
          await GeocodingService.getLatLngFromAddress(widget.city);
      if (cityLatLng != null) {
        _centerLocation = cityLatLng;
        print('🎯 Ciudad: ${widget.city} -> $_centerLocation');
      } else {
        print('No se pudo geocodificar la ciudad: ${widget.city}');
        _centerLocation = const LatLng(40.4168, -3.7038); // fallback Madrid
      }
    } catch (e) {
      print('Error obteniendo ubicación de la ciudad: $e');
      _centerLocation = const LatLng(40.4168, -3.7038); // fallback Madrid
    }
  }

  /// Crea marcadores para todas las actividades usando geocoding real y marcador personalizado
  Future<void> _createMarkersFromActivities() async {
    final Set<Marker> markers = {};
    List<Activity> activitiesNeedingUpdate = [];
    bool hasUpdatedActivities = false;

    for (int i = 0; i < widget.activities.length; i++) {
      final activity = widget.activities[i];
      LatLng? activityLocation = activity.location;

      // Si la actividad no tiene coordenadas guardadas, hacer geocodificación
      if (activityLocation == null) {
        print('🔍 Geocodificando actividad: ${activity.title}');
        final nombreLimpio = limpiarNombreActividad(activity.title);
        final address = '$nombreLimpio, ${widget.city}';
        activityLocation = await GeocodingService.getLatLngFromAddress(address);

        // Si se obtuvo la ubicación, marcar para actualizar
        if (activityLocation != null) {
          print(
              '📍 Coordenadas obtenidas para ${activity.title}: $activityLocation');
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
          );

          activitiesNeedingUpdate.add(updatedActivity);
          hasUpdatedActivities = true;
        } else {
          print('❌ No se pudo obtener ubicación para: ${activity.title}');
        }
      } else {
        print('✅ Usando coordenadas guardadas para: ${activity.title}');
      }

      // Crear marcador si tenemos ubicación
      final isSelectedDay = _selectedDays.contains(activity.day);
      if (activityLocation != null && isSelectedDay) {
        // Usar marcador especial si esta actividad está seleccionada
        final bool isThisActivitySelected = i == _selectedActivityIndex;

        final BitmapDescriptor customIcon = isThisActivitySelected
            ? await createPulsingMarker(activity, i + 1)
            : await createCategoryMarker(
                activity,
                i + 1,
                selected: true,
              );

        markers.add(
          Marker(
            markerId: MarkerId('${widget.guideTitle} - ${activity.title}'),
            position: activityLocation,
            infoWindow: InfoWindow(
              title: '${activity.title}',
              snippet:
                  '${activity.duration}min • ${activity.description.length > 40 ? '${activity.description.substring(0, 40)}...' : activity.description}',
            ),
            icon: customIcon,
            onTap: () {
              setState(() {
                _selectedActivityIndex = i;
              });
              // Recrear marcadores para actualizar el seleccionado
              _createMarkersFromActivities();
            },
          ),
        );
      }
    }

    // Notificar sobre nuevas coordenadas obtenidas (pero no actualizar aquí)
    if (hasUpdatedActivities) {
      print(
          '💡 Se obtuvieron ${activitiesNeedingUpdate.length} nuevas coordenadas');
      // Aquí podrías implementar una función callback para notificar al GuideDetailScreen
      // sobre las nuevas coordenadas obtenidas
    }

    setState(() {
      _markers = markers;
    });
  }

  /// Genera un offset aleatorio pero consistente para cada actividad
  LatLng _generateRandomOffset(int index) {
    // Usar el índice para generar posiciones consistentes pero distribuidas
    final double baseOffset = 0.01; // ~1km aproximadamente
    final double latOffset =
        ((index % 5) - 2) * baseOffset + ((index % 13) - 6) * (baseOffset / 3);
    final double lngOffset = (((index * 3) % 5) - 2) * baseOffset +
        (((index * 7) % 11) - 5) * (baseOffset / 3);

    return LatLng(latOffset, lngOffset);
  }

  void _onMapCreated(GoogleMapController controller) {
    print('🗺️ Google Map creado exitosamente');
    _mapController = controller;
    _mapController!.setMapStyle(_greyRoadsMapStyle);
    // Verificar que el mapa esté completamente cargado
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_centerLocation != null && _mapController != null) {
        print('📍 Centrando mapa en: $_centerLocation');
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_centerLocation!, 12.0),
        );
      }
    });
  }

  void _centerOnActivity(int index) async {
    if (_mapController != null &&
        index >= 0 &&
        index < _activitiesOfSelectedDays.length) {
      final activity = _activitiesOfSelectedDays[index];

      // Buscar la ubicación de esta actividad
      LatLng? activityLocation = activity.location;

      if (activityLocation == null) {
        // Si no tiene coordenadas guardadas, usar geocodificación
        final nombreLimpio = limpiarNombreActividad(activity.title);
        final address = '$nombreLimpio, ${widget.city}';
        activityLocation = await GeocodingService.getLatLngFromAddress(address);
      }

      if (activityLocation != null) {
        // Animar la cámara hacia la actividad
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(activityLocation, 16.0),
        );

        // Actualizar el índice seleccionado
        setState(() {
          _selectedActivityIndex = index;
        });

        // Recrear marcadores para mostrar el seleccionado
        await _updateMarkersWithTransition();

        // Mostrar un mensaje de confirmación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Centrado en: ${activity.title}',
                      style: const TextStyle(color: Colors.white),
                    ),
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
        // Mostrar error si no se pudo encontrar la ubicación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No se pudo encontrar la ubicación de ${activity.title}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant GuideMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _createPolylinesForSelectedDays();
  }

  // =================== MÉTODOS DE UI ===================
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                // Header fijo arriba con SafeArea
                SafeArea(
                  bottom: false,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.black, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Volver',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.guideTitle.isNotEmpty
                                ? widget.guideTitle
                                : widget.city,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.my_location,
                              color: Colors.black, size: 26),
                          onPressed: _centerOnCity,
                          tooltip: 'Centrar mapa',
                        ),
                        IconButton(
                          icon: const Icon(Icons.fit_screen,
                              color: Colors.black, size: 26),
                          onPressed: _fitMarkersInView,
                          tooltip: 'Ajustar vista',
                        ),
                      ],
                    ),
                  ),
                ),
                // Resto del contenido (mapa + overlays)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalHeight = constraints.maxHeight;
                      return Stack(
                        children: [
                          // Container que limita el área visible del mapa
                          ValueListenableBuilder<double>(
                            valueListenable: _sheetFraction,
                            builder: (context, fraction, _) {
                              // Calcular la altura disponible para el mapa basándose en la fracción del sheet
                              final mapHeight = totalHeight *
                                  (1 -
                                      fraction *
                                          0.8); // 0.8 para dejar espacio mínimo
                              return Container(
                                height: mapHeight,
                                child: _centerLocation != null
                                    ? GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: _centerLocation!,
                                          zoom: 12.0,
                                        ),
                                        markers: _markers,
                                        polylines: _polylines,
                                        myLocationEnabled:
                                            _hasLocationPermission,
                                        myLocationButtonEnabled: false,
                                        mapToolbarEnabled: true,
                                        zoomControlsEnabled: true,
                                        compassEnabled: true,
                                        mapType: _currentMapType,
                                        onMapCreated:
                                            (GoogleMapController controller) {
                                          print(
                                              '🗺️ Google Map widget creado exitosamente');
                                          _onMapCreated(controller);
                                          _createPolylinesForSelectedDays();
                                        },
                                      )
                                    : Container(),
                              );
                            },
                          ),
                          NotificationListener<DraggableScrollableNotification>(
                            onNotification: (notification) {
                              _sheetFraction.value = notification.extent;
                              return false;
                            },
                            child: DraggableScrollableSheet(
                              initialChildSize: 0.5,
                              minChildSize: 0.15,
                              maxChildSize: 0.8,
                              snap: true,
                              snapSizes: const [0.15, 0.5, 0.8],
                              builder: (context, scrollController) {
                                return Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 12,
                                        offset: Offset(0, -4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Indicador gris, más fino y arrastrable
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onVerticalDragUpdate: (details) {},
                                        child: Container(
                                          width: 60,
                                          height: 5,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF999999),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                      // Header de selección de días y botón
                                      DaySelectorHeader(
                                        availableDays: _availableDays,
                                        selectedDays: _selectedDays,
                                        onDaysSelected: (days) async {
                                          setState(() {
                                            _selectedDays = days;
                                          });
                                          await _createPolylinesForSelectedDays();
                                          await _updateMarkersWithTransition();
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      // Lista de actividades filtrada por días
                                      Expanded(
                                        child: ActivityList(
                                          activities: _activitiesOfSelectedDays,
                                          selectedIndex: _selectedActivityIndex >=
                                                      0 &&
                                                  _selectedActivityIndex <
                                                      _activitiesOfSelectedDays
                                                          .length
                                              ? _selectedActivityIndex
                                              : -1,
                                          onActivityTap: (index) =>
                                              _centerOnActivity(index),
                                          placesInfo: _placesInfo,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // Overlay de carga
                          if (_isLoading) const MapLoadingOverlay(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _centerOnCity() {
    if (_mapController != null && _centerLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_centerLocation!, 12.0),
      );
      setState(() {
        _selectedActivityIndex = -1;
      });
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingScreen();
    } else if (_hasError) {
      return _buildErrorScreen();
    } else {
      return _buildMapScreen();
    }
  }

  /// Widget de fallback para mostrar información básica si el mapa no funciona
  Widget _buildFallbackInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El mapa no está disponible actualmente. Se muestran las actividades en formato de lista.',
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.activities.length,
              itemBuilder: (context, index) {
                final activity = widget.activities[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(activity.title),
                    subtitle: Text(
                      activity.description.length > 80
                          ? '${activity.description.substring(0, 80)}...'
                          : activity.description,
                    ),
                    trailing: Text('${activity.duration} min'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withOpacity(0.1),
            Colors.white,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono animado
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.map,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Barra de progreso
            Container(
              width: 200,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200 * _loadingProgress,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Texto de carga
            Text(
              _getLoadingMessage(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preparando ${widget.activities.length} actividades...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            // Indicador circular adicional
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error al cargar el mapa',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'No se pudo cargar el mapa de actividades',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _retryLoading,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Botón de debug (temporal)
            TextButton(
              onPressed: _showDebugInfo,
              child: const Text(
                'Ver información de debug',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapScreen() {
    print('🖼️ Construyendo pantalla del mapa');
    print('📍 Centro: $_centerLocation');
    print('📌 Marcadores: ${_markers.length}');

    if (_centerLocation == null) {
      print('❌ Error: _centerLocation es null');
      return Container(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error: Ubicación del centro no disponible'),
              ElevatedButton(
                onPressed: _retryLoading,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // El mapa debe ir primero (fondo)
        GoogleMap(
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
          mapType: _currentMapType,
          onMapCreated: (GoogleMapController controller) {
            print('🗺️ Google Map widget creado exitosamente');
            _onMapCreated(controller);
            _createPolylinesForSelectedDays();
          },
        ),
        // Botón de ubicación del usuario
        _buildUserLocationButton(),
      ],
    );
  }

  String _getLoadingMessage() {
    if (_loadingProgress < 0.3) {
      return 'Localizando ${widget.city}...';
    } else if (_loadingProgress < 0.7) {
      return 'Creando marcadores...';
    } else if (_loadingProgress < 0.9) {
      return 'Configurando mapa...';
    } else {
      return 'Finalizando...';
    }
  }

  void _retryLoading() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _loadingProgress = 0.0;
    });
    _initializeMapWithTimeout();
  }

  /// Muestra información de debug para diagnosticar problemas
  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de Debug'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDebugItem('Ciudad', widget.city),
              _buildDebugItem('Actividades', '${widget.activities.length}'),
              _buildDebugItem(
                  'Ubicación centro', _centerLocation?.toString() ?? 'null'),
              _buildDebugItem('Marcadores', '${_markers.length}'),
              _buildDebugItem('Cargando', _isLoading.toString()),
              _buildDebugItem('Error', _hasError.toString()),
              if (_errorMessage.isNotEmpty)
                _buildDebugItem('Mensaje error', _errorMessage),
              _buildDebugItem('Progreso',
                  '${(_loadingProgress * 100).toStringAsFixed(1)}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMarkers() async {
    setState(() {
      _isLoading = true;
    });
    await _createMarkersFromActivities();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadPlacesInfo() async {
    final List<PlaceInfo?> infos = [];
    for (final activity in widget.activities) {
      final info =
          await PlacesService.getPlaceInfo(activity.title, widget.city);
      infos.add(info);
    }
    setState(() {
      _placesInfo = infos;
    });
  }

  Future<void> _createPolylinesForSelectedDays() async {
    final Set<Polyline> polylines = {};

    // Crear una polilínea para cada día seleccionado
    for (final day in _selectedDays) {
      final dayActivities =
          _activitiesOfSelectedDays.where((a) => a.day == day).toList();
      if (dayActivities.isEmpty) continue;

      final List<LatLng> points = [];
      for (final activity in dayActivities) {
        LatLng? activityLocation = activity.location;

        // Si la actividad no tiene coordenadas guardadas, hacer geocodificación
        if (activityLocation == null) {
          print('🔍 Geocodificando para polilínea: ${activity.title}');
          final nombreLimpio = limpiarNombreActividad(activity.title);
          final address = '$nombreLimpio, ${widget.city}';
          activityLocation =
              await GeocodingService.getLatLngFromAddress(address);
        } else {
          print(
              '✅ Usando coordenadas guardadas para polilínea: ${activity.title}');
        }

        if (activityLocation != null) {
          points.add(activityLocation);
        }
      }

      if (points.length > 1) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('ruta-dia-$day'),
            color: const Color(0xFF0062FF), // Azul para las rutas seleccionadas
            width: 5,
            points: points,
          ),
        );
      }
    }

    setState(() {
      _polylines = polylines;
    });
  }

  /// Actualiza los marcadores con transición suave
  Future<void> _updateMarkersWithTransition() async {
    // Limpiar marcadores actuales
    setState(() {
      _markers.clear();
    });

    // Pequeña pausa para el efecto visual
    await Future.delayed(const Duration(milliseconds: 100));

    // Recrear marcadores
    await _createMarkersFromActivities();
  }

  /// Centra el mapa para mostrar todos los marcadores visibles
  void _fitMarkersInView() {
    if (_markers.isEmpty || _mapController == null) return;

    final bounds = _calculateBounds(_markers.map((m) => m.position).toList());

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        100.0, // Padding
      ),
    );
  }

  /// Calcula los límites para un conjunto de coordenadas
  LatLngBounds _calculateBounds(List<LatLng> coordinates) {
    if (coordinates.isEmpty) {
      return LatLngBounds(
        southwest: _centerLocation ?? const LatLng(40.4168, -3.7038),
        northeast: _centerLocation ?? const LatLng(40.4168, -3.7038),
      );
    }

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (final coord in coordinates) {
      minLat = math.min(minLat, coord.latitude);
      maxLat = math.max(maxLat, coord.latitude);
      minLng = math.min(minLng, coord.longitude);
      maxLng = math.max(maxLng, coord.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
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
              backgroundColor: AppColors.primary,
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
          ),
        );
      }
    }
  }

  /// Construye el botón de ubicación del usuario
  Widget _buildUserLocationButton() {
    if (!_hasLocationPermission) return const SizedBox.shrink();

    return Positioned(
      top: 16, // Posicionado en la esquina superior derecha
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
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _sheetFraction.dispose();
    super.dispose();
  }
}
