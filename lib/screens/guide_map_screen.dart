import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../data/activity.dart';
import '../config/app_colors.dart';

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
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  LatLng? _centerLocation;
  int _selectedActivityIndex = -1;
  double _loadingProgress = 0.0;
  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _initializeMapWithTimeout();
  }

  /// Inicializa el mapa con un timeout para evitar carga infinita
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
      _getCityLocation(); // Hacer síncrono
      print('📍 Ubicación encontrada: $_centerLocation');

      if (mounted) {
        setState(() {
          _loadingProgress = 0.6;
        });
      }

      // Paso 2: Crear marcadores (simplificado)
      print(
          '📌 Creando marcadores para ${widget.activities.length} actividades...');
      _createMarkersFromActivities(); // Hacer síncrono
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

  /// Obtiene las coordenadas aproximadas de la ciudad
  void _getCityLocation() {
    try {
      // Coordenadas por defecto para ciudades principales
      final cityCoordinates = {
        'madrid': const LatLng(40.4168, -3.7038),
        'barcelona': const LatLng(41.3851, 2.1734),
        'sevilla': const LatLng(37.3891, -5.9845),
        'valencia': const LatLng(39.4699, -0.3763),
        'bilbao': const LatLng(43.2627, -2.9253),
        'paris': const LatLng(48.8566, 2.3522),
        'londres': const LatLng(51.5074, -0.1278),
        'london': const LatLng(51.5074, -0.1278),
        'roma': const LatLng(41.9028, 12.4964),
        'rome': const LatLng(41.9028, 12.4964),
        'milan': const LatLng(45.4642, 9.1900),
        'milán': const LatLng(45.4642, 9.1900),
        'amsterdam': const LatLng(52.3676, 4.9041),
        'berlin': const LatLng(52.5200, 13.4050),
        'berlín': const LatLng(52.5200, 13.4050),
        'viena': const LatLng(48.2082, 16.3738),
        'vienna': const LatLng(48.2082, 16.3738),
        'praga': const LatLng(50.0755, 14.4378),
        'prague': const LatLng(50.0755, 14.4378),
        'lisboa': const LatLng(38.7223, -9.1393),
        'lisbon': const LatLng(38.7223, -9.1393),
        'oporto': const LatLng(41.1579, -8.6291),
        'porto': const LatLng(41.1579, -8.6291),
        'altea': const LatLng(38.5991, 0.0404), // Añadido Altea
      };

      final cityKey = widget.city.toLowerCase().trim();
      _centerLocation = cityCoordinates[cityKey] ??
          const LatLng(40.4168, -3.7038); // Madrid por defecto

      print('🎯 Ciudad: $cityKey -> $_centerLocation');
    } catch (e) {
      print('Error obteniendo ubicación de la ciudad: $e');
      _centerLocation = const LatLng(40.4168, -3.7038); // Madrid por defecto
    }
  }

  /// Crea marcadores para todas las actividades
  void _createMarkersFromActivities() {
    final Set<Marker> markers = {};

    for (int i = 0; i < widget.activities.length; i++) {
      final activity = widget.activities[i];

      // Generar posiciones aproximadas alrededor del centro de la ciudad
      final randomOffset = _generateRandomOffset(i);
      final activityLocation = LatLng(
        _centerLocation!.latitude + randomOffset.latitude,
        _centerLocation!.longitude + randomOffset.longitude,
      );

      markers.add(
        Marker(
          markerId: MarkerId('activity_$i'),
          position: activityLocation,
          infoWindow: InfoWindow(
            title: activity.title,
            snippet: activity.description.length > 50
                ? '${activity.description.substring(0, 50)}...'
                : activity.description,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerColor(activity.category ?? '')),
          onTap: () {
            setState(() {
              _selectedActivityIndex = i;
            });
          },
        ),
      );
    }

    _markers = markers;
    print('🏷️ Marcadores finales: ${_markers.length}');
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

  /// Obtiene el color del marcador según la categoría
  double _getMarkerColor(String category) {
    switch (category.toLowerCase()) {
      case 'cultural':
      case 'museum':
      case 'monument':
        return BitmapDescriptor.hueViolet;
      case 'food':
      case 'restaurant':
      case 'comida':
        return BitmapDescriptor.hueOrange;
      case 'nightlife':
      case 'fiesta':
      case 'bar':
        return BitmapDescriptor.hueMagenta;
      case 'tour':
      case 'sightseeing':
        return BitmapDescriptor.hueGreen;
      case 'shopping':
        return BitmapDescriptor.hueRose;
      case 'outdoor':
      case 'nature':
        return BitmapDescriptor.hueYellow;
      default:
        return BitmapDescriptor.hueBlue;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    print('🗺️ Google Map creado exitosamente');
    _mapController = controller;

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mapa: ${widget.guideTitle}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _changeMapType,
            tooltip: 'Cambiar tipo de mapa',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnCity,
            tooltip: 'Centrar en ${widget.city}',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Convierte el color del marcador a un Color widget
  Color _getMarkerColorWidget(String category) {
    switch (category.toLowerCase()) {
      case 'cultural':
      case 'museum':
      case 'monument':
        return Colors.purple;
      case 'food':
      case 'restaurant':
      case 'comida':
        return Colors.orange;
      case 'nightlife':
      case 'fiesta':
      case 'bar':
        return Colors.pink;
      case 'tour':
      case 'sightseeing':
        return Colors.green;
      case 'shopping':
        return Colors.red;
      case 'outdoor':
      case 'nature':
        return Colors.yellow[700]!;
      default:
        return Colors.blue;
    }
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

  void _changeMapType() {
    setState(() {
      switch (_currentMapType) {
        case MapType.normal:
          _currentMapType = MapType.satellite;
          break;
        case MapType.satellite:
          _currentMapType = MapType.hybrid;
          break;
        case MapType.hybrid:
          _currentMapType = MapType.terrain;
          break;
        case MapType.terrain:
        default:
          _currentMapType = MapType.normal;
          break;
      }
    });

    // Mostrar el tipo de mapa actual
    String mapTypeName;
    switch (_currentMapType) {
      case MapType.normal:
        mapTypeName = 'Normal';
        break;
      case MapType.satellite:
        mapTypeName = 'Satélite';
        break;
      case MapType.hybrid:
        mapTypeName = 'Híbrido';
        break;
      case MapType.terrain:
        mapTypeName = 'Terreno';
        break;
      default:
        mapTypeName = 'Normal';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mapa: $mapTypeName'),
        duration: const Duration(seconds: 1),
      ),
    );
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
                        color: _getMarkerColorWidget(activity.category ?? ''),
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
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: true,
          zoomControlsEnabled: true,
          compassEnabled: true,
          mapType: _currentMapType,
          onCameraMove: (CameraPosition position) {
            print('📷 Cámara movida a: ${position.target}');
          },
          onMapCreated: (GoogleMapController controller) {
            print('🗺️ Google Map widget creado exitosamente');
            _onMapCreated(controller);
          },
        ),

        // Panel de información en la parte superior
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.city,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${widget.activities.length} actividades en el mapa',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Lista de actividades en la parte inferior
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 140,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
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
                // Indicador de arrastre
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Lista horizontal de actividades
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: widget.activities.length,
                    itemBuilder: (context, index) {
                      final activity = widget.activities[index];
                      final isSelected = index == _selectedActivityIndex;

                      return GestureDetector(
                        onTap: () => _centerOnActivity(index),
                        child: Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getMarkerColorWidget(
                                          activity.category ?? ''),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      activity.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activity.description.length > 60
                                    ? '${activity.description.substring(0, 60)}...'
                                    : activity.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${activity.duration} min',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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
}
