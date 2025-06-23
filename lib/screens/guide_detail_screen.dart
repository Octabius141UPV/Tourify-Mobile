import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tourify_flutter/data/activity.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/collaborators_modal.dart';
import '../widgets/edit_activity_dialog.dart';
import '../widgets/add_activity_dialog.dart';
import '../widgets/civitatis_logo.dart';
import '../widgets/organize_activities_modal.dart';
import '../utils/activity_utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../services/collaborators_service.dart';
import '../services/guide_service.dart';
import '../services/public_guides_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadGuideDetails();
    _checkEditPermission();
  }

  Future<void> _checkEditPermission() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final collaboratorsService = CollaboratorsService();
      final roleResponse =
          await collaboratorsService.getUserRole(widget.guideId);
      setState(() {
        _userRole = roleResponse['role'] as String?;
        _canEdit =
            roleResponse['canEdit'] == true || roleResponse['isOwner'] == true;
        _isOwner = roleResponse['isOwner'] == true;
      });
    } catch (e) {
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
        _isOwner = guideData['isOwner'] ?? false;
        _isLoading = false;
      });

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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(guideTitle),
        actions: [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _guide == null
              ? const Center(child: Text('No se encontró la guía'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGuideHeader(),
                      const SizedBox(height: 16),
                      _buildDaysSection(),
                    ],
                  ),
                ),
      floatingActionButton: _canEdit ? _buildFloatingActionMenu() : null,
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
      margin: const EdgeInsets.all(16),
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
          // Botón de retroceso y título principal
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

          // Botón gestionar colaboradores
          SizedBox(
            width: double.infinity,
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
                      'Gestionar colaboradores',
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
    );
  }

  Widget _buildDaysSection() {
    if (_guide!['days'].isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
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
                          )
                        : Image.network(
                            _getPlaceholderImage(activityObj.category ?? ''),
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
                            activityObj.title.isNotEmpty
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
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
                      maxLines: verMas ? null : 2,
                      overflow:
                          verMas ? TextOverflow.visible : TextOverflow.ellipsis,
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
                        label: const Text('Ver en Civitatis'),
                        onPressed: () => _openInCivitatis(activityObj),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<File> generateGuidePdf({
    required String title,
    required String city,
    required String author,
    required List<dynamic> dayActivities,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(title,
                style:
                    pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text('Ciudad: $city', style: pw.TextStyle(fontSize: 18)),
          pw.Text('Autor: $author', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 16),
          ...dayActivities.map((day) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Día ${day['dayNumber']}',
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  ...day['activities'].map((activity) => pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(activity['title'],
                                style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold)),
                            if (activity['city'] != null &&
                                activity['city'].isNotEmpty)
                              pw.Text('Ciudad: ${activity['city']}',
                                  style: pw.TextStyle(fontSize: 12)),
                            if (activity['duration'] != null)
                              pw.Text('Duración: ${activity['duration']} min',
                                  style: pw.TextStyle(fontSize: 12)),
                            if (activity['description'] != null &&
                                activity['description'].isNotEmpty)
                              pw.Text(activity['description'],
                                  style: pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                      )),
                  pw.Divider(),
                ],
              )),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/guia_tourify.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  void _shareGuide() async {
    try {
      final String guideTitle = widget.guideTitle;
      final String? city = _guide?['city'] ?? 'Destino desconocido';
      final String author = _guide?['author'] ?? 'Tourify';
      final pdfFile = await generateGuidePdf(
        title: guideTitle,
        city: city ?? 'Destino desconocido',
        author: author,
        dayActivities: _guide!['days'],
      );

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: '¡Mira esta guía de viaje creada con Tourify!',
        subject: 'Guía de viaje: $guideTitle',
        sharePositionOrigin: _getSharePositionOrigin(),
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) _showShareSuccessMessage();
    } catch (e) {
      print('Error al compartir la guía como PDF: $e');
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _showShareErrorMessage();
    }
  }

  // Obtener la posición de origen para el modal de compartir
  Rect? _getSharePositionOrigin() {
    try {
      // Obtener el contexto del botón de compartir en la AppBar
      final MediaQueryData mediaQuery = MediaQuery.of(context);
      final double screenWidth = mediaQuery.size.width;
      final double statusBarHeight = mediaQuery.padding.top;
      final double appBarHeight = kToolbarHeight;

      // Posicionar el modal cerca del botón de compartir (esquina superior derecha)
      return Rect.fromLTWH(
        screenWidth - 100, // 100px desde el borde derecho
        statusBarHeight + appBarHeight, // Justo debajo de la AppBar
        50, // Ancho del área
        50, // Alto del área
      );
    } catch (e) {
      print('Error obteniendo posición de origen: $e');
      return null;
    }
  }

  // Mostrar mensaje de éxito con posicionamiento mejorado
  void _showShareSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('¡Guía compartida exitosamente!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 100, left: 16, right: 16),
      ),
    );
  }

  // Mostrar mensaje de error con posicionamiento mejorado
  void _showShareErrorMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Error al compartir la guía'),
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
      'images': activity['images'] ?? [],
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
              // TODO: Implementar función de deshacer si es necesario
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
                      // Botón Ordenar Actividades
                      Tooltip(
                        message: 'Organizar actividades',
                        child: _buildCircularButton(
                          onTap: _showOrganizeModal,
                          size: 56,
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
                      const SizedBox(height: 12),
                      // Botón Añadir Actividad
                      Tooltip(
                        message: 'Añadir actividad',
                        child: _buildCircularButton(
                          onTap: _addNewActivity,
                          size: 56,
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
                      const SizedBox(height: 12),
                      // Botón Compartir
                      Tooltip(
                        message: 'Compartir guía',
                        child: _buildCircularButton(
                          onTap: _shareGuide,
                          size: 56,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF42A5F5), // Azul claro
                              Color(0xFF1565C0), // Azul oscuro
                            ],
                          ),
                          shadowColor: Colors.blue,
                          icon: Icons.share,
                          iconSize: 24,
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
            size: 64,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2196F3), // Azul claro
                Color(0xFF0D47A1), // Azul profundo
              ],
            ),
            shadowColor: Colors.blue,
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
    required IconData icon,
    required double iconSize,
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
              child: Icon(
                icon,
                color: Colors.white,
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
}
