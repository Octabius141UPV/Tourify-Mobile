import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_colors.dart';
import '../services/location_service.dart';

/// Widget personalizado para mostrar un mapa con la estética de Tourify
class TourifyMapWidget extends StatefulWidget {
  final LatLng? initialPosition;
  final double zoom;
  final Set<Marker>? markers;
  final Function(LatLng)? onMapTap;
  final Function(GoogleMapController)? onMapCreated;
  final bool showUserLocation;
  final bool showCompass;
  final bool showMapTypeButton = false;

  const TourifyMapWidget({
    super.key,
    this.initialPosition,
    this.zoom = 14.0,
    this.markers,
    this.onMapTap,
    this.onMapCreated,
    this.showUserLocation = true,
    this.showCompass = true,
  });

  @override
  State<TourifyMapWidget> createState() => _TourifyMapWidgetState();
}

class _TourifyMapWidgetState extends State<TourifyMapWidget> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  String? _errorMessage;
  final MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  /// Inicializa la ubicación del usuario
  Future<void> _initializeLocation() async {
    try {
      print('🗺️ Inicializando ubicación...');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Verificar permisos
      bool hasPermission = await _locationService.requestLocationPermission();
      setState(() {
        _hasLocationPermission = hasPermission;
      });

      if (hasPermission && widget.showUserLocation) {
        // Obtener ubicación actual
        Position? position = await _locationService.getCurrentPosition();
        if (position != null) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
          });
        }
      }
    } catch (e) {
      print('❌ Error en inicialización: $e');
      setState(() {
        _errorMessage = 'Error al obtener la ubicación: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Obtiene la posición inicial para el mapa
  LatLng get _getInitialPosition {
    if (widget.initialPosition != null) {
      return widget.initialPosition!;
    }
    if (_currentPosition != null) {
      return _currentPosition!;
    }
    // Posición por defecto (Madrid, España)
    return const LatLng(40.4168, -3.7038);
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
    });
    
    if (widget.onMapCreated != null) {
      widget.onMapCreated!(controller);
    }

    // Aplicar tema personalizado al mapa
    _applyMapStyle();
  }

  Future<void> _applyMapStyle() async {
    if (_mapController == null) return;

    try {
      String style = '''
      [
        {
          "featureType": "poi",
          "elementType": "labels",
          "stylers": [
            {
              "visibility": "off"
            }
          ]
        }
      ]
      ''';
      
      await _mapController!.setMapStyle(style);
    } catch (e) {
      print('Error aplicando estilo al mapa: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _getInitialPosition,
            zoom: widget.zoom,
          ),
          onMapCreated: _onMapCreated,
          onTap: widget.onMapTap,
          markers: widget.markers ?? {},
          myLocationEnabled: widget.showUserLocation && _hasLocationPermission,
          myLocationButtonEnabled: false,
          compassEnabled: widget.showCompass,
          mapType: _currentMapType,
          zoomControlsEnabled: true,
          mapToolbarEnabled: true,
        ),

        // Botón de ubicación personalizado
        if (widget.showUserLocation && _hasLocationPermission)
          Positioned(
            bottom: 20,
            right: 20,
            child: _buildLocationButton(),
          ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Cargando mapa...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Error al cargar el mapa',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeLocation,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return FloatingActionButton(
      onPressed: () async {
        if (_mapController != null && _currentPosition != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentPosition!, 16.0),
          );
        }
      },
      backgroundColor: Colors.white,
      foregroundColor: AppColors.primary,
      elevation: 4,
      mini: true,
      child: const Icon(Icons.my_location),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
