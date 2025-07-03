import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../data/activity.dart';
import '../config/app_colors.dart';
import '../services/map/geocoding_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../services/map/places_service.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/map/day_selector_header.dart';
import '../widgets/map/activity_list.dart';
import '../widgets/map/map_loading_overlay.dart';
import '../widgets/map/activity_marker_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class _GuideMapScreenState extends State<GuideMapScreen> {
  // =================== VARIABLES Y CONTROLADORES ===================
  // (Variables de estado, controladores, listas, etc.)
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
  int _selectedDay = 1;
  Set<Polyline> _polylines = {};
  final ValueNotifier<double> _sheetFraction = ValueNotifier(0.5);
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

  // =================== MÉTODOS DE LÓGICA DE DATOS ===================
  // (Carga de datos, geocodificación, places, creación de marcadores, etc.)
  @override
  void initState() {
    super.initState();
    _initializeMapWithTimeout();
    _loadMarkers();
    _loadPlacesInfo();
    _initSelectedDay();
  }

  void _initSelectedDay() {
    if (widget.activities.isNotEmpty) {
      setState(() {
        _selectedDay = widget.activities.map((a) => a.day).reduce((a, b) => a < b ? a : b);
      });
    }
  }

  List<int> get _availableDays {
    final days = widget.activities.map((a) => a.day).toSet().toList();
    days.sort();
    return days;
  }

  List<Activity> get _activitiesOfSelectedDay {
    final acts = widget.activities.where((a) => a.day == _selectedDay).toList();
    acts.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
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
      final LatLng? cityLatLng = await GeocodingService.getLatLngFromAddress(widget.city);
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
    for (int i = 0; i < widget.activities.length; i++) {
      final activity = widget.activities[i];
      final nombreLimpio = limpiarNombreActividad(activity.title);
      final address = '$nombreLimpio, ${widget.city}';
      final LatLng? activityLocation = await GeocodingService.getLatLngFromAddress(address);
      if (activityLocation != null) {
        final isSelectedDay = activity.day == _selectedDay;
        final BitmapDescriptor customIcon = await createNumberedMarker(i + 1, selected: isSelectedDay);
        markers.add(
          Marker(
            markerId: MarkerId('${widget.guideTitle} - ${activity.title}'),
            position: activityLocation,
            infoWindow: InfoWindow(
              title: '${widget.guideTitle} - ${activity.title}',
              snippet: activity.description.length > 50
                  ? '${activity.description.substring(0, 50)}...'
                  : activity.description,
            ),
            icon: customIcon,
            onTap: () {
              setState(() {
                _selectedActivityIndex = i;
              });
            },
          ),
        );
      }
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

  void _centerOnActivity(int index) {
    if (_mapController != null && index < _markers.length) {
      final marker = _markers.elementAt(index);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(marker.position, 15.0),
      );
      setState(() {
        _selectedActivityIndex = index;
      });
    }
  }

  @override
  void didUpdateWidget(covariant GuideMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _createPolylineForSelectedDay();
  }

  // =================== MÉTODOS DE UI ===================
  // (Métodos build, widgets auxiliares, loading, error, etc.)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;
          return Stack(
            children: [
              _buildHeader(context),
              ValueListenableBuilder<double>(
                valueListenable: _sheetFraction,
                builder: (context, fraction, _) {
                  final mapHeight = totalHeight * (1 - fraction) + 90;
                  return Container(
                    margin: const EdgeInsets.only(top: 90),
                    height: mapHeight > 90 ? mapHeight : 90,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(0),
                        topRight: Radius.circular(0),
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildMapScreen(),
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
                  minChildSize: 0.10,
                  maxChildSize: 0.7,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, -2),
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
                              width: 48,
                              height: 4,
                              margin: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: Color(0xFFB0B0B0),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Header de selección de día y botón
                          DaySelectorHeader(
                            availableDays: _availableDays,
                            selectedDay: _selectedDay,
                            onDaySelected: (day) async {
                              setState(() {
                                _selectedDay = day;
                              });
                              await _createPolylineForSelectedDay();
                              await _createMarkersFromActivities();
                            },
                          ),
                          const SizedBox(height: 8),
                          // Lista de actividades filtrada por día
                          Expanded(
                            child: ActivityList(
                              activities: _activitiesOfSelectedDay,
                              selectedIndex: _selectedActivityIndex >= 0 && _selectedActivityIndex < _activitiesOfSelectedDay.length ? _selectedActivityIndex : -1,
                              onActivityTap: (index) => _centerOnActivity(index),
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
              if (_isLoading)
                const MapLoadingOverlay(),
            ],
          );
        },
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
        // Mapa principal
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _centerLocation!,
            zoom: 12.0,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: true,
          zoomControlsEnabled: true,
          compassEnabled: true,
          mapType: _currentMapType,
          onMapCreated: (GoogleMapController controller) {
            print('🗺️ Google Map widget creado exitosamente');
            _onMapCreated(controller);
            _createPolylineForSelectedDay();
          },
        ),
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
      final info = await PlacesService.getPlaceInfo(activity.title, widget.city);
      infos.add(info);
    }
    setState(() {
      _placesInfo = infos;
    });
  }

  // Header fijo con degradado azul y botones
  Widget _buildHeader(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 90,
        padding: EdgeInsets.only(top: topPadding, left: 0, right: 0),
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
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Volver',
            ),
            Expanded(
              child: Center(
                child: Text(
                  widget.guideTitle.isNotEmpty ? widget.guideTitle : widget.city,
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
            ),
            IconButton(
              icon: const Icon(Icons.my_location, color: Colors.black, size: 26),
              onPressed: _centerOnCity,
              tooltip: 'Centrar mapa',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPolylineForSelectedDay() async {
    final List<LatLng> points = [];
    for (final activity in _activitiesOfSelectedDay) {
      final nombreLimpio = limpiarNombreActividad(activity.title);
      final address = '$nombreLimpio, ${widget.city}';
      final LatLng? activityLocation = await GeocodingService.getLatLngFromAddress(address);
      if (activityLocation != null) {
        points.add(activityLocation);
      }
    }
    if (points.length > 1) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: PolylineId('ruta-dia-$_selectedDay'),
            color: const Color(0xFF0062FF),
            width: 5,
            points: points,
          ),
        };
      });
    } else {
      setState(() {
        _polylines = {};
      });
    }
  }

  @override
  void dispose() {
    _sheetFraction.dispose();
    super.dispose();
  }
}
