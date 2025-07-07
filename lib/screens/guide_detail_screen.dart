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
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_colors.dart';
import '../data/activity.dart';
import '../services/guide_service.dart';
import '../services/map/geocoding_service.dart';
import '../services/map/places_service.dart';
import '../utils/activity_utils.dart';
import '../widgets/map/activity_marker_utils.dart';
import '../widgets/edit_activity_dialog.dart';
import '../widgets/add_activity_dialog.dart';
import '../widgets/collaborators_modal.dart';
import '../widgets/organize_activities_modal.dart';
import '../services/collaborators_service.dart';
import '../services/public_guides_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'collaborators_screen.dart';
import 'premium_subscription_screen.dart';
import 'guide_map_screen.dart';
import '../widgets/travel_agent_chat_widget.dart';
import '../widgets/premium_feature_modal.dart';

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
  Set<String> _expandedActivities = Set<String>();

  // NUEVO: Permiso de edición
  bool _canEdit = false;
  String? _userRole;

  // Variables para el gesto de swipe
  double _swipeStartX = 0.0;
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

  // NUEVO: Para saber qué marcador está seleccionado
  MarkerId? _selectedMarkerId;

  // Guardar el mapping de actividad a MarkerId y su posición
  Map<String, LatLng> _activityIdToLatLng = {};
  Map<String, int> _activityIdToPinNumber = {};

  @override
  void initState() {
    super.initState();
    _loadGuideDetails().then((_) {
      // Cargar permisos DESPUÉS de cargar los detalles de la guía
      _checkEditPermission();
    });
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

  Future<void> _saveChanges() async {
    // TODO: Implementar guardado de cambios
    setState(() {
      _isEditMode = false;
    });
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

    return GestureDetector(
      onPanEnd: (details) {
        _handleSwipeEnd(details);
      },
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            _navigateToHome();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: Text(guideTitle),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigateToHome,
              tooltip: 'Volver al inicio',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _downloadGuide,
                tooltip: 'Descargar guía',
              ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              // Fade + Slide desde abajo
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
                        ? _buildMapAndGuideLayout(key: const ValueKey('map'))
                        : SingleChildScrollView(
                            key: const ValueKey('guide'),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGuideHeader(),
                                const SizedBox(height: 16),
                                _buildDaysSection(),
                              ],
                            ),
                          ),
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
      ),
    );
  }

  Widget _buildGuideHeader() {
    if (_guide == null) {
      return const SizedBox.shrink();
    }
    final startDate = (_guide!['startDate'] as Timestamp?)?.toDate();
    final endDate = (_guide!['endDate'] as Timestamp?)?.toDate();
    final city = _guide!['city'] ?? 'Ciudad desconocida';

    // Calcular días total
    int totalDays = 0;
    if (_guide!['days'] is List) {
      totalDays = (_guide!['days'] as List).length;
    }
    if (startDate != null && endDate != null) {
      totalDays = endDate.difference(startDate).inDays + 1;
    }

    // Calcular total de lugares/actividades
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(20),
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
          // Título principal
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Itinerario completo • $totalDays días',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contador de lugares
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$totalPlaces lugares',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Botón gestionar colaboradores - solo mostrar para owners y organizadores
          if (!widget.guideId.startsWith('predefined_') &&
              (_isOwner || _userRole == 'editor')) ...[
            Builder(
              builder: (context) {
                print('DEBUG: Evaluando botón colaboradores');
                print('DEBUG: guideId: ${widget.guideId}');
                print(
                    'DEBUG: !predefined: \\${!widget.guideId.startsWith('predefined_')}');
                print('DEBUG: _isOwner: $_isOwner');
                print('DEBUG: _userRole: $_userRole');
                print('DEBUG: _userRole == editor: \\${_userRole == 'editor'}');
                print(
                    'DEBUG: Condición final: \\${!widget.guideId.startsWith('predefined_') && (_isOwner || _userRole == 'editor')}');
                return SizedBox.shrink();
              },
            ),

            // Fila con botón de colaboradores (eliminar botón de mapa de aquí)
            Row(
              children: [
                // Botón gestionar colaboradores
                Expanded(
                  child: GestureDetector(
                    onTap: _openCollaborators,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2196F3), // Azul claro
                            Color(0xFF0D47A1), // Azul profundo
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.people, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Colaboradores',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            // Eliminar botón de mapa de aquí
            const SizedBox(height: 12),
          ],

          // Botones de exportación Google Maps y Calendar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exportar a:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _exportAllToGoogleMaps,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.green, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Maps',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _exportAllToGoogleCalendar,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.blue, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.blue, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Calendar',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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

    // Solo fix de tipo, sin tocar el diseño
    return Column(
      children: (_guide!['days'] as List)
          .map<Widget>(
              (dayData) => _buildDayCard(dayData as Map<String, dynamic>))
          .toList(),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> dayData) {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: dayData['dayNumber'] == 1,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Día ${dayData['dayNumber']}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${dayData['activities'].length} actividades',
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
        children: [
          if (dayData['activities'].isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay actividades para este día'),
            )
          else
            ...dayData['activities']
                .map((activity) => _buildActivityTile(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity) {
    final activityObj = Activity.fromMap(activity, activity['id'].toString());
    final bool descripcionLarga = activityObj.description.length > 80;
    bool verMas = false;
    // Obtener el número del pin si el mapa está visible
    int? pinNum = _isMapVisible ? _activityIdToPinNumber[activityObj.id] : null;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: _isMapVisible
              ? () => _focusOnActivityFromList(activityObj)
              : null,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen con overlay de duración
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                      child: activityObj.images.isNotEmpty
                          ? Image.network(
                              activityObj.images.first,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/images/no-image.png',
                                  width: double.infinity,
                                  height: 160,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/no-image.png',
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                    ),
                    // Duración arriba izquierda
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${activityObj.duration} min',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título con menú de 3 puntitos
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 18, color: Color(0xFF2196F3)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              pinNum != null
                                  ? '$pinNum. ${activityObj.title}'
                                  : activityObj.title.isNotEmpty
                                      ? activityObj.title
                                      : 'Sin título',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Solo mostrar el menú si el usuario tiene permisos de edición
                          if (_canEdit)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.black87),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editActivity(activity);
                                } else if (value == 'delete') {
                                  _deleteActivity(activity);
                                } else if (value == 'maps') {
                                  _exportToGoogleMaps(activity);
                                } else if (value == 'calendar') {
                                  _addToGoogleCalendar(activity);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Editar'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Eliminar'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'maps',
                                  child: Row(
                                    children: [
                                      Icon(Icons.map,
                                          size: 18, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Abrir en Maps'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'calendar',
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 18, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Añadir a calendario'),
                                    ],
                                  ),
                                ),
                              ],
                              color: Colors.white,
                              elevation: 8,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        !descripcionLarga || verMas
                            ? activityObj.description
                            : activityObj.description.substring(0, 80) + '...',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                        maxLines: verMas ? null : 2,
                        overflow: verMas
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                      if (descripcionLarga && !verMas)
                        GestureDetector(
                          onTap: () => setState(() => verMas = true),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              'Ver más',
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Solo mostrar botón de Civitatis para actividades culturales
                      if (activityObj.category?.toLowerCase() == 'cultural' ||
                          activityObj.category?.toLowerCase() == 'cultura')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2196F3),
                              side: const BorderSide(
                                  color: Color(0xFF2196F3), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            icon:
                                const Icon(Icons.confirmation_number, size: 18),
                            label: const Text('Reservar actividad'),
                            onPressed: () => _openInCivitatis(activityObj),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Función auxiliar para extraer URL de imagen
  String? _getImageUrl(Map<String, dynamic> activity) {
    if (activity['images'] != null &&
        activity['images'] is List &&
        (activity['images'] as List).isNotEmpty) {
      return activity['images'][0] as String;
    } else if (activity['imageUrl'] != null &&
        activity['imageUrl'].toString().isNotEmpty) {
      return activity['imageUrl'] as String;
    }
    return null;
  }

  // Descarga la guía como PDF desde el backend
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

  // Métodos para gestionar actividades
  void _editActivity(Map<String, dynamic> activity) async {
    // Asegurar que todos los campos críticos no sean null
    final safeActivity = {
      'id': activity['id'] ?? '',
      'title': activity['title'] ?? activity['name'] ?? '',
      'description': activity['description'] ?? '',
      'duration': activity['duration'] ?? 60,
      'day': activity['day'] ?? 1,
      'order': activity['order'],
      'images': activity[
          'images'], // ⚠️ PRESERVAR IMÁGENES ORIGINALES - NO REEMPLAZAR
      'imageUrl':
          activity['imageUrl'], // ⚠️ TAMBIÉN PRESERVAR imageUrl SI EXISTE
      'city': activity['city'],
      'category': activity['category'],
      'likes': activity['likes'] ?? 0,
      'startTime': activity['startTime'],
      'endTime': activity['endTime'],
      'price': activity['price'],
    };

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditActivityDialog(
        activity: Activity.fromMap(safeActivity, safeActivity['id']),
        onSave: (updatedActivity) async {
          // Encontrar el día al que pertenece esta actividad
          dynamic targetDay = _guide!['days'].firstWhere((day) =>
              (day['activities'] as List).any(
                  (a) => (a as Map<String, dynamic>)['id'] == activity['id']));

          if (targetDay == null) {
            throw Exception('No se pudo encontrar el día de la actividad');
          }

          // Actualizar la actividad en la lista del día
          final updatedActivities = (targetDay['activities'] as List)
              .map((a) {
                return (a as Map<String, dynamic>)['id'] == activity['id']
                    ? updatedActivity.toMap()
                    : a as Map<String, dynamic>;
              })
              .toList()
              .cast<Map<String, dynamic>>();

          // Guardar en Firestore
          final success = await _updateDayActivities(
            targetDay['dayNumber'],
            updatedActivities,
          );

          if (!success) {
            throw Exception('Error al actualizar la actividad en el servidor');
          }

          // Actualizar el estado local
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
    try {
      final activitiesData = activities.map((activity) => activity).toList();
      await _firestore
          .collection('guides')
          .doc(widget.guideId)
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

  void _deleteActivity(Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Eliminar actividad'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${activity['title']}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteActivity(activity);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteActivity(Map<String, dynamic> activity) async {
    try {
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
              Text('Eliminando actividad...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      // Encontrar el día al que pertenece esta actividad
      dynamic targetDay = _guide!['days'].firstWhere((day) =>
          (day['activities'] as List)
              .any((a) => (a as Map<String, dynamic>)['id'] == activity['id']));

      if (targetDay == null) {
        throw Exception('No se pudo encontrar el día de la actividad');
      }

      // Filtrar la actividad a eliminar
      final updatedActivities = (targetDay['activities'] as List)
          .where((a) => (a as Map<String, dynamic>)['id'] != activity['id'])
          .toList()
          .cast<Map<String, dynamic>>();

      // Guardar en Firestore
      final success = await _updateDayActivities(
        targetDay['dayNumber'],
        updatedActivities,
      );

      if (!success) {
        throw Exception('Error al eliminar la actividad en el servidor');
      }

      // Actualizar el estado local
      setState(() {
        final dayIndex = _guide!['days']
            .indexWhere((d) => d['dayNumber'] == targetDay['dayNumber']);
        if (dayIndex != -1) {
          _guide!['days'][dayIndex]['activities'] = updatedActivities;
        }
      });

      // Ocultar indicador de carga y mostrar éxito
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
      // Ocultar indicador de carga y mostrar error
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
              Text('Restaurando actividad...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      // Encontrar el día al que pertenece esta actividad
      dynamic targetDay = _guide!['days'].firstWhere(
          (day) => day['dayNumber'] == dayNumber,
          orElse: () => null);

      List<Map<String, dynamic>> updatedActivities;

      if (targetDay != null) {
        // Añadir la actividad de vuelta al día existente
        updatedActivities = [
          ...targetDay['activities'],
          activity,
        ];
      } else {
        // Crear nuevo día con esta actividad si el día no existe
        updatedActivities = [activity];
      }

      // Guardar en Firestore
      final success = await _updateDayActivities(
        dayNumber,
        updatedActivities,
      );

      if (!success) {
        throw Exception('Error al restaurar la actividad en el servidor');
      }

      // Actualizar el estado local
      setState(() {
        if (targetDay != null) {
          // Actualizar día existente
          final dayIndex =
              _guide!['days'].indexWhere((d) => d['dayNumber'] == dayNumber);
          if (dayIndex != -1) {
            _guide!['days'][dayIndex]['activities'] = updatedActivities;
          }
        } else {
          // Añadir nuevo día
          _guide!['days'].add({
            'dayNumber': dayNumber,
            'activities': updatedActivities,
          });
          // Reordenar por número de día
          _guide!['days']
              .sort((a, b) => a['dayNumber'].compareTo(b['dayNumber']));
        }
      });

      // Ocultar indicador de carga y mostrar éxito
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Actividad "${activity['title']}" restaurada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Ocultar indicador de carga y mostrar error
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
    // Determinar a qué día añadir la actividad
    // Si tenemos días, mostrar diálogo para seleccionar día
    // Si no hay días, crear el primer día

    if (_guide!['days'].isEmpty) {
      // Si no hay días, crear actividad para el día 1
      _showAddActivityDialog(1);
      return;
    }

    // Si hay múltiples días, mostrar selector de día
    if (_guide!['days'].length > 1) {
      _showDaySelector();
      return;
    }

    // Si solo hay un día, añadir a ese día
    _showAddActivityDialog(_guide!['days'][0]['dayNumber']);
  }

  void _showDaySelector() {
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
                _showAddActivityDialog(day['dayNumber']);
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

  void _showAddActivityDialog(int dayNumber) async {
    final city =
        _guide?['city'] ?? _guide?['destination'] ?? 'Ciudad desconocida';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddActivityDialog(
        dayNumber: dayNumber,
        guideId: widget.guideId,
        city: city,
        onSave: (newActivity) async {
          // Encontrar el día al que añadir la actividad
          dynamic targetDay = _guide!['days']
              .firstWhere((day) => day['dayNumber'] == dayNumber);

          List<Map<String, dynamic>> updatedActivities;

          if (targetDay != null) {
            // Añadir a un día existente
            updatedActivities = [
              ...targetDay['activities'],
              newActivity.toMap()
            ];
          } else {
            // Crear nuevo día con esta actividad
            updatedActivities = [newActivity.toMap()];
          }

          // Guardar en Firestore
          final success = await _updateDayActivities(
            dayNumber,
            updatedActivities,
          );

          if (!success) {
            throw Exception('Error al añadir la actividad en el servidor');
          }

          // Actualizar el estado local
          setState(() {
            if (targetDay != null) {
              // Actualizar día existente
              final dayIndex = _guide!['days']
                  .indexWhere((d) => d['dayNumber'] == dayNumber);
              if (dayIndex != -1) {
                _guide!['days'][dayIndex]['activities'] = updatedActivities;
              }
            } else {
              // Añadir nuevo día
              _guide!['days'].add({
                'dayNumber': dayNumber,
                'activities': updatedActivities,
              });
              // Reordenar por número de día
              _guide!['days']
                  .sort((a, b) => a['dayNumber'].compareTo(b['dayNumber']));
            }
          });
        },
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

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      // Cuando activamos el modo edición, colapsamos el menú
      if (_isEditMode) {
        _isMenuExpanded = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _isEditMode ? 'Modo edición activado' : 'Modo edición desactivado'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleMenu() {
    setState(() {
      _isMenuExpanded = !_isMenuExpanded;
    });
  }

  void _openCollaborators() {
    print(
        'DEBUG: Abriendo modal de colaboradores para guía: ${widget.guideId}');
    showCollaboratorsModal(context, widget.guideId, widget.guideTitle);
  }

  // Métodos para manejar el gesto de swipe desde la izquierda
  void _handleSwipeFromLeft(details) {
    if (!_isSwipeActive && details.globalPosition.dx < 50) {
      _isSwipeActive = true;
      _swipeStartX = details.globalPosition.dx;
    }
  }

  void _handleSwipeEnd(details) {
    if (_isSwipeActive) {
      // Calcular la velocidad del gesto
      final velocity = details.velocity.pixelsPerSecond.dx;

      // Si la velocidad es suficiente hacia la derecha (>= 500)
      if (velocity >= 500) {
        _navigateToHome();
      }

      _isSwipeActive = false;
      _swipeStartX = 0.0;
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }

  Widget _buildFloatingActionMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Opciones del menú - solo se muestran si el menú está expandido
        AnimatedOpacity(
          opacity: !_isMenuExpanded ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: !_isMenuExpanded ? 0 : null,
            child: _isMenuExpanded
                ? Column(
                    children: [
                      // Botón Agente de Viaje IA
                      AnimatedSlide(
                        offset: _isMenuExpanded ? Offset(0, 0) : Offset(0, 0.9),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        child: AnimatedScale(
                          scale: _isMenuExpanded ? 1.0 : 0.7,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: _isMenuExpanded ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 600),
                            child: Tooltip(
                              message: 'Agente de viaje',
                              child: _buildCircularButton(
                                onTap: _openTravelAgent,
                                size: 46,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF42A5F5), // Azul claro
                                    Color(0xFF1565C0), // Azul oscuro
                                  ],
                                ),
                                shadowColor: Colors.blue,
                                customChild: ClipOval(
                                  child: Image.asset(
                                    'assets/images/agent_avatar.png',
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Botón Ordenar Actividades
                      AnimatedSlide(
                        offset: _isMenuExpanded ? Offset(0, 0) : Offset(0, 0.6),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        child: AnimatedScale(
                          scale: _isMenuExpanded ? 1.0 : 0.7,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: _isMenuExpanded ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 600),
                            child: Tooltip(
                              message: 'Organizar actividades',
                              child: _buildCircularButton(
                                onTap: _showOrganizeModal,
                                size: 46,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF42A5F5), // Azul claro
                                    Color(0xFF1565C0), // Azul oscuro
                                  ],
                                ),
                                shadowColor: Colors.blue,
                                icon: Icons.swap_vert_rounded,
                                iconSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Botón Añadir Actividad
                      AnimatedSlide(
                        offset: _isMenuExpanded ? Offset(0, 0) : Offset(0, 0.3),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        child: AnimatedScale(
                          scale: _isMenuExpanded ? 1.0 : 0.7,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: _isMenuExpanded ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 600),
                            child: Tooltip(
                              message: 'Añadir actividad',
                              child: _buildCircularButton(
                                onTap: _addNewActivity,
                                size: 46,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF42A5F5), // Azul claro
                                    Color(0xFF1565C0), // Azul oscuro
                                  ],
                                ),
                                shadowColor: Colors.blue,
                                icon: Icons.add,
                                iconSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        // Botón Principal
        Tooltip(
          message: _isMenuExpanded ? 'Cerrar menú' : 'Abrir menú',
          child: _buildCircularButton(
            onTap: _toggleMenu,
            size: 54,
            gradient: _isMenuExpanded
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE53935), // Rojo claro
                      Color(0xFFB71C1C), // Rojo oscuro
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2196F3), // Azul claro
                      Color(0xFF0D47A1), // Azul profundo
                    ],
                  ),
            shadowColor: _isMenuExpanded ? Colors.red : Colors.blue,
            icon: _isMenuExpanded ? Icons.close : Icons.more_vert,
            iconSize: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildCircularButton({
    required VoidCallback onTap,
    required double size,
    required LinearGradient gradient,
    required Color shadowColor,
    IconData? icon,
    double? iconSize,
    Widget? customChild,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: customChild ??
                  (icon != null
                      ? Icon(
                          icon,
                          color: Colors.white,
                          size: iconSize,
                          key: ValueKey(icon),
                        )
                      : const SizedBox()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularButtonWithBorder({
    required VoidCallback onTap,
    required double size,
    required IconData icon,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onTap,
          splashColor: Colors.black.withOpacity(0.1),
          highlightColor: Colors.black.withOpacity(0.05),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icon,
                color: Colors.black,
                size: iconSize,
                key: ValueKey(icon),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Método para construir imagen placeholder con fallback local
  Widget _buildPlaceholderImage(String category) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getCategoryColors(category),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(category),
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            _getCategoryName(category),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Obtener colores por categoría
  List<Color> _getCategoryColors(String category) {
    switch (category.toLowerCase()) {
      case 'cultural':
      case 'museum':
      case 'monument':
        return [Colors.purple[400]!, Colors.purple[600]!];
      case 'food':
      case 'restaurant':
      case 'comida':
        return [Colors.orange[400]!, Colors.red[600]!];
      case 'nightlife':
      case 'fiesta':
      case 'bar':
        return [Colors.deepPurple[400]!, Colors.indigo[600]!];
      case 'tour':
      case 'sightseeing':
        return [Colors.green[400]!, Colors.teal[600]!];
      case 'shopping':
        return [Colors.pink[400]!, Colors.pink[600]!];
      case 'outdoor':
      case 'nature':
        return [Colors.green[400]!, Colors.green[700]!];
      default:
        return [Colors.blue[400]!, Colors.blue[600]!];
    }
  }

  // Obtener icono por categoría
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cultural':
      case 'museum':
      case 'monument':
        return Icons.museum;
      case 'food':
      case 'restaurant':
      case 'comida':
        return Icons.restaurant;
      case 'nightlife':
      case 'fiesta':
      case 'bar':
        return Icons.nightlife;
      case 'tour':
      case 'sightseeing':
        return Icons.tour;
      case 'shopping':
        return Icons.shopping_bag;
      case 'outdoor':
      case 'nature':
        return Icons.nature;
      default:
        return Icons.place;
    }
  }

  // Obtener nombre de categoría
  String _getCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'cultural':
      case 'museum':
      case 'monument':
        return 'Cultural';
      case 'food':
      case 'restaurant':
      case 'comida':
        return 'Gastronomía';
      case 'nightlife':
      case 'fiesta':
      case 'bar':
        return 'Vida Nocturna';
      case 'tour':
      case 'sightseeing':
        return 'Tour';
      case 'shopping':
        return 'Compras';
      case 'outdoor':
      case 'nature':
        return 'Naturaleza';
      default:
        return 'Actividad';
    }
  }

  // Método para obtener imagen placeholder basada en la categoría
  String _getPlaceholderImage(String category) {
    switch (category.toLowerCase()) {
      case 'cultural':
      case 'museum':
      case 'monument':
        return 'https://images.unsplash.com/photo-1529260830199-42c24126f198?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1476&q=80';
      case 'food':
      case 'restaurant':
      case 'comida':
        return 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1287&q=80';
      case 'nightlife':
      case 'fiesta':
      case 'bar':
        return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1374&q=80';
      case 'tour':
      case 'sightseeing':
        return 'https://images.unsplash.com/photo-1539650116574-75c0c6d73d0e?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80';
      case 'shopping':
        return 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80';
      case 'outdoor':
      case 'nature':
        return 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80';
      default:
        return 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80';
    }
  }

  Future<void> _publishGuide() async {
    try {
      await _firestore.collection('guides').doc(widget.guideId).update({
        'status': 'published',
        'isPublic': true,
      });
      await _loadGuideDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guía publicada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar la guía: $e')),
        );
      }
    }
  }

  void _openTravelAgent() {
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
  void _exportToGoogleMaps(Map<String, dynamic> activity) {
    _showComingSoonModal();
  }

  void _addToGoogleCalendar(Map<String, dynamic> activity) {
    _showComingSoonModal();
  }

  void _exportAllToGoogleMaps() {
    _showComingSoonModal();
  }

  void _exportAllToGoogleCalendar() {
    _showComingSoonModal();
  }

  void _showComingSoonModal() {
    showDialog(
      context: context,
      builder: (context) => const PremiumFeatureModal(),
    );
  }

  void _openGuideMap() async {
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
      setState(() {
        _allActivities = allActivities;
        _isMapVisible = true;
        _isMapLoading = true;
        _selectedDays = allDays; // Seleccionar todos los días por defecto
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
              snippet: '',
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

    setState(() {
      _markers = markers;
    });
  }

  // NUEVO: Al hacer tap en el marcador, pedir info y mostrar modal
  void _onMarkerTapped(Activity activity, String city, MarkerId markerId,
      {int? pinNumber}) async {
    setState(() {
      _selectedMarkerId = markerId;
    });
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder(
          future: PlacesService.getPlaceInfo(activity.title, city),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final placeInfo = snapshot.data;
            if (placeInfo != null &&
                (placeInfo.rating != null || placeInfo.review != null)) {
              final bool needsUpdate =
                  (activity.googleRating != placeInfo.rating) ||
                      (activity.googleReview != placeInfo.review);
              if (needsUpdate) {
                _saveGoogleInfoToFirestore(
                    activity, placeInfo.rating, placeInfo.review);
              }
            }
            final pinNum =
                pinNumber ?? _activityIdToPinNumber[activity.id] ?? '';
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título del lugar
                  Row(
                    children: [
                      const Icon(Icons.place, color: Colors.blue, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$pinNum. ${activity.title}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Solo 3 opciones principales
                  Column(
                    children: [
                      // 1. Ver en Google Maps
                      if (placeInfo != null && placeInfo.address != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.map),
                            label: const Text('Ver en Google Maps'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final query =
                                  Uri.encodeComponent(placeInfo.address!);
                              final url =
                                  'https://www.google.com/maps/search/?api=1&query=$query';
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(Uri.parse(url),
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ),

                      const SizedBox(height: 12),

                      // 2. Editar actividad (solo si puede editar)
                      if (_canEdit)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar actividad'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              // Buscar la actividad en la estructura de la guía
                              Map<String, dynamic>? activityData;
                              for (final day in _guide!['days']) {
                                final activities = day['activities'] as List;
                                for (final act in activities) {
                                  if (act['id'] == activity.id) {
                                    activityData =
                                        Map<String, dynamic>.from(act);
                                    break;
                                  }
                                }
                                if (activityData != null) break;
                              }
                              if (activityData != null) {
                                _editActivity(activityData);
                              }
                            },
                          ),
                        ),

                      if (_canEdit) const SizedBox(height: 12),

                      // 3. Cerrar
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('Cerrar'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
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
                        myLocationEnabled: false,
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
                      height: 20,
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
                                width: 60, // Solo 60px de ancho para arrastrar
                                height: 20,
                                color: Colors.transparent,
                                child: Center(
                                  child: Container(
                                    width: 50,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(2),
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
    super.dispose();
  }

  // Nuevo: Botón flotante de mapa
  Widget _buildFloatingMapButton() {
    if (_isMapVisible) {
      // Cuando el mapa está visible, el botón de cerrar va en la posición principal del dial
      return Tooltip(
        message: 'Cerrar Mapa',
        child: _buildCircularButton(
          onTap: _closeMap,
          size: 54,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE53935), // Rojo claro
              Color(0xFFB71C1C), // Rojo oscuro
            ],
          ),
          shadowColor: Colors.red,
          icon: Icons.close,
          iconSize: 28,
        ),
      );
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
                    Icons.map,
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
            price: activityData['price'] as String?,
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
      // Obtener información adicional del lugar
      final placeInfo =
          await PlacesService.getPlaceInfo(place.name, _guide?['city'] ?? '');

      // Crear nueva actividad
      final newActivity = {
        'id':
            'google_${place.placeId}_${DateTime.now().millisecondsSinceEpoch}',
        'title': place.name,
        'description': placeInfo?.address ?? place.vicinity ?? '',
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
        'googleRating': place.rating,
        'googlePlaceId': place.placeId,
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
