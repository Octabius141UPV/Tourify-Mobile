import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_colors.dart';
import '../services/location_service.dart';
import '../widgets/tourify_map_widget.dart';
import '../widgets/location_permission_widget.dart';

/// Pantalla principal del mapa de Tourify
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _hasLocationPermission = false;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  /// Verifica si ya tenemos permisos de ubicación
  Future<void> _checkLocationPermission() async {
    bool hasPermission = await _locationService.hasLocationPermission();
    setState(() {
      _hasLocationPermission = hasPermission;
      _isCheckingPermission = false;
    });
  }

  /// Maneja cuando se conceden los permisos
  void _onPermissionGranted() {
    setState(() {
      _hasLocationPermission = true;
    });
  }

  /// Maneja cuando se niegan los permisos
  void _onPermissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Los permisos de ubicación son necesarios para usar el mapa'),
        backgroundColor: AppColors.error,
        action: SnackBarAction(
          label: 'Reintentar',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _isCheckingPermission = true;
            });
            _checkLocationPermission();
          },
        ),
      ),
    );
  }

  /// Maneja los toques en el mapa
  void _onMapTap(LatLng position) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(
              'tapped_location_${DateTime.now().millisecondsSinceEpoch}'),
          position: position,
          infoWindow: InfoWindow(
            title: 'Ubicación seleccionada',
            snippet:
                'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  /// Maneja la creación del controlador del mapa
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Limpia todos los marcadores
  void _clearMarkers() {
    setState(() {
      _markers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar loading mientras verificamos permisos
    if (_isCheckingPermission) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    // Mostrar pantalla de permisos si no los tenemos
    if (!_hasLocationPermission) {
      return LocationPermissionWidget(
        onPermissionGranted: _onPermissionGranted,
        onPermissionDenied: _onPermissionDenied,
      );
    }

    // Mostrar el mapa principal
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mapa',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Botón para limpiar marcadores
          if (_markers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearMarkers,
              tooltip: 'Limpiar marcadores',
            ),

          // Botón de menú adicional
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'satellite',
                child: Row(
                  children: [
                    Icon(Icons.satellite_alt, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Vista satélite'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'terrain',
                child: Row(
                  children: [
                    Icon(Icons.terrain, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Vista terreno'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Configuración'),
                  ],
                ),
              ),
            ],
            onSelected: _handleMenuSelection,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Widget del mapa
          TourifyMapWidget(
            markers: _markers,
            onMapTap: _onMapTap,
            onMapCreated: _onMapCreated,
            showUserLocation: true,
            showCompass: true,
          ),

          // Panel de información (cuando hay marcadores)
          if (_markers.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildInfoPanel(),
            ),
        ],
      ),

      // Botón flotante para agregar ubicaciones de interés
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLocationDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location),
        label: const Text('Agregar lugar'),
      ),
    );
  }

  /// Maneja la selección del menú
  void _handleMenuSelection(String value) {
    switch (value) {
      case 'satellite':
        // Cambiar a vista satélite
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vista satélite activada'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'terrain':
        // Cambiar a vista terreno
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vista terreno activada'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'settings':
        // Abrir configuración
        _showSettingsDialog();
        break;
    }
  }

  /// Construye el panel de información
  Widget _buildInfoPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                      'Ubicaciones marcadas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      '${_markers.length} ${_markers.length == 1 ? 'lugar' : 'lugares'} seleccionado${_markers.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _clearMarkers,
                child: const Text(
                  'Limpiar',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo para agregar una nueva ubicación
  void _showAddLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar lugar de interés'),
        content: const Text(
          'Toca en el mapa para marcar un lugar de interés o usa el buscador para encontrar ubicaciones específicas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo de configuración
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuración del mapa'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.location_on, color: AppColors.primary),
              title: Text('Mostrar mi ubicación'),
              trailing: Icon(Icons.check, color: AppColors.success),
            ),
            ListTile(
              leading: Icon(Icons.explore, color: AppColors.primary),
              title: Text('Brújula'),
              trailing: Icon(Icons.check, color: AppColors.success),
            ),
          ],
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
}
