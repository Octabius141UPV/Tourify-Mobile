import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourify_flutter/widgets/common/custom_bottom_navigation_bar.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:tourify_flutter/screens/guides/guide_detail_screen.dart';
import 'package:tourify_flutter/services/collaborators_service.dart';
import 'package:tourify_flutter/services/api_service.dart';
import 'package:tourify_flutter/config/app_colors.dart';
import 'package:tourify_flutter/utils/dialog_utils.dart';

class MyGuidesScreen extends StatefulWidget {
  const MyGuidesScreen({super.key});

  @override
  State<MyGuidesScreen> createState() => _MyGuidesScreenState();
}

class _MyGuidesScreenState extends State<MyGuidesScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isLoadingShared = false;
  List<Map<String, dynamic>> _myGuides = [];
  List<Map<String, dynamic>> _sharedGuides = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollaboratorsService _collaboratorsService = CollaboratorsService();
  final ApiService _apiService = ApiService();
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();

    _fetchGuides();
  }

  Future<void> _fetchGuides() async {
    try {
      setState(() {
        _isLoading = true;
        _isLoadingShared = true;
      });

      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _isLoadingShared = false;
        });
        return;
      }

      // Ejecutar ambas cargas en paralelo para mejorar el rendimiento
      await Future.wait([
        _fetchMyGuides(user.uid),
        _fetchSharedGuides(user.uid, user.email),
      ]);
    } catch (error) {
      // Error silencioso
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingShared = false;
      });
    }
  }

  Future<void> _fetchMyGuides(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      List<Map<String, dynamic>> allGuides = [];
      DocumentSnapshot? lastDocument;
      const int batchSize = 25; // Cargar en lotes de 25

      // Cargar todas las guías en lotes para mejor rendimiento
      while (true) {
        Query query = _firestore
            .collection('guides')
            .where('userRef', isEqualTo: userRef)
            .orderBy('createdAt', descending: true)
            .limit(batchSize);

        if (lastDocument != null) {
          query = query.startAfterDocument(lastDocument);
        }

        final QuerySnapshot guidesQuery = await query.get();

        if (guidesQuery.docs.isEmpty) {
          break; // No hay más documentos
        }

        final batchGuides = guidesQuery.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'city': data['city'] ?? data['name'] ?? 'Sin título',
            'title': data['title'] ?? data['name'] ?? 'Sin título',
            'destination': data['city'] ?? data['name'] ?? 'Sin destino',
            'location': data['formattedAddress'] ??
                data['destination'] ??
                'Sin ubicación',
            'createdAt': data['createdAt'] ?? DateTime.now(),
            'totalDays': data['totalDays'] ?? 0,
            'startDate': data['startDate'],
            'endDate': data['endDate'],
            'name': data['name'] ?? 'Sin nombre',
            'isShared': false,
          };
        }).toList();

        allGuides.addAll(batchGuides);

        // Actualizar UI cada lote para mostrar progreso
        if (mounted) {
          setState(() {
            _myGuides = List.from(allGuides);
          });
        }

        // Si obtuvimos menos documentos que el tamaño del lote, hemos terminado
        if (guidesQuery.docs.length < batchSize) {
          break;
        }

        lastDocument = guidesQuery.docs.last;
      }

      if (mounted) {
        setState(() {
          _myGuides = allGuides;
        });
      }
    } catch (error) {
      // Error silencioso, solo actualizar estado
      if (mounted) {
        setState(() {
          _myGuides = [];
        });
      }
    }
  }

  Future<void> _fetchSharedGuides(String userId, String? userEmail) async {
    try {
      setState(() {
        _isLoadingShared = true;
      });

      final List<Map<String, dynamic>> sharedGuides = [];

      // Solo usar el método 1: Buscar en la subcolección sharedWithMe del usuario
      // Este es el método más eficiente y confiable
      final sharedWithMeRef =
          _firestore.collection('users').doc(userId).collection('sharedWithMe');
      final sharedWithMeDocs = await sharedWithMeRef.get();

      // Procesar en lotes para mejor rendimiento
      final List<Future<void>> guideFutures = [];

      for (final doc in sharedWithMeDocs.docs) {
        guideFutures.add(_processSharedGuide(doc, sharedGuides));
      }

      // Procesar todos los documentos en paralelo
      await Future.wait(guideFutures);

      // Ordenar por fecha de compartido (más reciente primero)
      sharedGuides.sort((a, b) {
        DateTime _toDt(dynamic v) {
          if (v is Timestamp) return v.toDate();
          if (v is DateTime) return v;
          if (v is String)
            return DateTime.tryParse(v) ??
                DateTime.fromMillisecondsSinceEpoch(0);
          if (v is Map) {
            final s = v['_seconds'] ?? v['seconds'];
            final n = v['_nanoseconds'] ?? v['nanoseconds'];
            if (s is num) {
              final ms =
                  (s * 1000).toInt() + ((n is num) ? (n / 1e6).floor() : 0);
              return DateTime.fromMillisecondsSinceEpoch(ms);
            }
          }
          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        final aDate = _toDt(a['sharedAt']);
        final bDate = _toDt(b['sharedAt']);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _sharedGuides = sharedGuides;
      });
    } catch (error) {
      setState(() {
        _sharedGuides = [];
      });
    } finally {
      setState(() {
        _isLoadingShared = false;
      });
    }
  }

  Future<void> _processSharedGuide(
      DocumentSnapshot doc, List<Map<String, dynamic>> sharedGuides) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final guideId = data['guideId'] ?? doc.id;
      // final sharedAt = data['sharedAt'];
      // final sharedBy = data['sharedBy'] ?? '';
      final role =
          data['role'] ?? 'viewer'; // Obtener rol directamente del documento

      // Obtener los datos de la guía
      final guideDoc = await _firestore.collection('guides').doc(guideId).get();

      if (guideDoc.exists) {
        final guideData = guideDoc.data()!;

        // Solo verificar con el servicio si no tenemos rol en el documento
        String finalRole = role;
        if (role == 'viewer' || role.isEmpty) {
          try {
            final roleResponse =
                await _collaboratorsService.getUserRole(guideId);
            if (roleResponse['success'] == true &&
                roleResponse['isOwner'] != true &&
                roleResponse['role'] != null &&
                roleResponse['role'] != 'none') {
              finalRole = roleResponse['role'] as String;
            } else {
              // Si no tiene un rol válido, no incluir la guía
              return;
            }
          } catch (e) {
            // Si falla la verificación de rol, usar el rol del documento
            if (role.isEmpty || role == 'viewer') return;
          }
        }

        sharedGuides.add({
          'id': guideId,
          'city': guideData['city'] ?? guideData['name'] ?? 'Sin título',
          'title': guideData['title'] ?? guideData['name'] ?? 'Sin título',
          'destination':
              guideData['city'] ?? guideData['name'] ?? 'Sin destino',
          'location': guideData['formattedAddress'] ??
              guideData['destination'] ??
              'Sin ubicación',
          'createdAt': guideData['createdAt'] ?? DateTime.now(),
          'totalDays': guideData['totalDays'] ?? 0,
          'startDate': guideData['startDate'],
          'endDate': guideData['endDate'],
          'name': guideData['name'] ?? 'Sin nombre',
          'isShared': true,
          'role': finalRole,
          'sharedBy': 'Sistema',
          'sharedAt': null,
        });
      }
    } catch (e) {
      // Error silencioso para esta guía específica
    }
  }

  Future<void> _refreshGuides() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _isLoadingShared = true;
    });

    try {
      // Ejecutar ambas recargas en paralelo
      await Future.wait([
        _fetchMyGuides(user.uid),
        _fetchSharedGuides(user.uid, user.email),
      ]);
    } catch (error) {
      // Error silencioso
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingShared = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera mejorada
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.blue[50]!.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF60A5FA).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.map_rounded,
                                color: Color(0xFF2563EB),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mis Viajes',
                                    style: TextStyle(
                                      color: Color(0xFF1F2937),
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Gestiona y organiza tus aventuras',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Tabs mejorados
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTabIndex = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 0
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: _selectedTabIndex == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_rounded,
                                    size: 18,
                                    color: _selectedTabIndex == 0
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mis Guías',
                                    style: TextStyle(
                                      color: _selectedTabIndex == 0
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 0
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_myGuides.length}',
                                      style: TextStyle(
                                        color: _selectedTabIndex == 0
                                            ? Colors.white
                                            : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTabIndex = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 1
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: _selectedTabIndex == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_rounded,
                                    size: 18,
                                    color: _selectedTabIndex == 1
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Compartidas',
                                    style: TextStyle(
                                      color: _selectedTabIndex == 1
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 1
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_sharedGuides.length}',
                                      style: TextStyle(
                                        color: _selectedTabIndex == 1
                                            ? Colors.white
                                            : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido de las tabs
                  Expanded(
                    child: _selectedTabIndex == 0
                        ? _buildGuidesListView(_myGuides)
                        : _buildGuidesListView(_sharedGuides),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: 1,
          onTap: (index) {
            switch (index) {
              case 0:
                NavigationService.navigateToMainScreen('/home');
                break;
              case 1:
                // Already on my-guides, do nothing
                break;
              case 2:
                NavigationService.navigateToMainScreen('/profile');
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _buildGuidesListView(List<Map<String, dynamic>> guides) {
    // Mostrar loading según la pestaña activa
    final isLoadingCurrent =
        _selectedTabIndex == 0 ? _isLoading : _isLoadingShared;

    if (isLoadingCurrent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (guides.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0
                      ? const Color(0xFF60A5FA).withOpacity(0.1)
                      : const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  _selectedTabIndex == 0
                      ? Icons.explore_rounded
                      : Icons.people_rounded,
                  size: 48,
                  color: _selectedTabIndex == 0
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _selectedTabIndex == 0
                    ? '¡Tu aventura comienza aquí!'
                    : '¡Conecta con otros viajeros!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _selectedTabIndex == 0
                    ? 'Aún no has creado ninguna guía de viaje.\nComienza planificando tu próxima aventura.'
                    : 'Cuando otros viajeros compartan sus guías contigo,\naparecerán aquí para que puedas colaborar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (_selectedTabIndex == 1) ...[
                if (_isLoadingShared)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Buscando guías compartidas...',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF60A5FA),
                          const Color(0xFF2563EB),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _refreshGuides,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                      label: const Text(
                        'Actualizar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshGuides,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: guides.length,
        itemBuilder: (context, index) {
          final guide = guides[index];
          return _buildGuideCard(guide);
        },
        physics: const AlwaysScrollableScrollPhysics(),
      ),
    );
  }

  Widget _buildGuideCard(Map<String, dynamic> guide) {
    final String title = (guide['title'] ?? 'Sin título').toString();
    final String location = (guide['location'] ?? 'Sin ubicación').toString();
    final int totalDays =
        int.tryParse(guide['totalDays']?.toString() ?? '0') ?? 0;
    final bool isShared = guide['isShared'] == true;
    final String role = (guide['role'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Registrar última apertura
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('recentlyOpened')
                    .doc(guide['id'].toString())
                    .set({
                  'guideId': guide['id'].toString(),
                  'openedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }
            } catch (_) {}
            Navigator.of(context).push(
              MaterialPageRoute(
                settings: RouteSettings(name: 'Guide: $title'),
                builder: (context) => GuideDetailScreen(
                  guideId: guide['id'].toString(),
                  guideTitle: title,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con título y acciones
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Menu de acciones - Solo mostrar si tiene permisos
                    if (!isShared || role == 'editor')
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _editGuideName(guide);
                              break;
                            case 'delete':
                              _confirmarEliminarGuia(guide);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          // Editar (solo si es propietario o editor)
                          if (!isShared || role == 'editor')
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded,
                                      size: 20, color: Colors.blue[600]),
                                  const SizedBox(width: 12),
                                  const Text('Editar'),
                                ],
                              ),
                            ),
                          // Eliminar (solo propietarios)
                          if (!isShared)
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_rounded,
                                      size: 20, color: Colors.red[600]),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.red[600]),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),

                // Badges y etiquetas
                if (isShared) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF60A5FA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF60A5FA).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_rounded,
                          size: 14,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          role == 'editor' ? 'Organizador' : 'Acoplado',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Información adicional
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (totalDays > 0) ...[
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$totalDays día${totalDays > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Indicador de acceso rápido
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF60A5FA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 12,
                            color: const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Toca para ver',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  void _editGuideName(Map<String, dynamic> guide) {
    showDialog(
      context: context,
      builder: (context) => _EditGuideDialog(
        guide: guide,
        onUpdate: _updateGuideInfo,
      ),
    );
  }

  Future<void> _updateGuideInfo(
    Map<String, dynamic> guide,
    String newName,
    String newDescription,
  ) async {
    try {
      final guideId = guide['id'].toString();
      final updateData = {
        'name': newName,
        'title': newName, // Actualizar también title para compatibilidad
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Solo añadir descripción si no está vacía
      if (newDescription.isNotEmpty) {
        updateData['description'] = newDescription;
      } else {
        updateData['description'] = FieldValue.delete();
      }

      await _firestore.collection('guides').doc(guideId).update(updateData);

      // Actualizar la lista local
      setState(() {
        _myGuides = _myGuides.map((g) {
          if (g['id'] == guideId) {
            return {
              ...g,
              'name': newName,
              'title': newName,
              'description': newDescription.isNotEmpty ? newDescription : null,
            };
          }
          return g;
        }).toList();

        _sharedGuides = _sharedGuides.map((g) {
          if (g['id'] == guideId) {
            return {
              ...g,
              'name': newName,
              'title': newName,
              'description': newDescription.isNotEmpty ? newDescription : null,
            };
          }
          return g;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guía actualizada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar la guía: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarEliminarGuia(Map<String, dynamic> guide) {
    DialogUtils.showCupertinoConfirmation(
      context: context,
      title: '¿Eliminar guía?',
      content:
          '¿Seguro que quieres eliminar la guía "${guide['title']}"? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmColor: Colors.red,
    ).then((confirmed) async {
      if (confirmed == true) {
        await _eliminarGuia(guide);
      }
    });
  }

  Future<void> _eliminarGuia(Map<String, dynamic> guide) async {
    try {
      final guideId = guide['id'].toString();

      // Usar el endpoint del servidor para eliminar la guía
      final result = await _apiService.deleteGuide(guideId);

      if (result['success'] == true) {
        // Solo actualizar la UI si la eliminación fue exitosa
        setState(() {
          _myGuides = _myGuides.where((g) => g['id'] != guideId).toList();
          _sharedGuides =
              _sharedGuides.where((g) => g['id'] != guideId).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Guía eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Mostrar error específico del servidor
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Error al eliminar la guía'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // En caso de error de conexión, intentar eliminar directamente de Firestore como fallback
      try {
        print('Error con API, intentando fallback a Firestore: $e');
        final guideId = guide['id'].toString();
        await _firestore.collection('guides').doc(guideId).delete();

        setState(() {
          _myGuides = _myGuides.where((g) => g['id'] != guideId).toList();
          _sharedGuides =
              _sharedGuides.where((g) => g['id'] != guideId).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guía eliminada correctamente (modo offline)'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (fallbackError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar la guía: $fallbackError'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EditGuideDialog extends StatefulWidget {
  final Map<String, dynamic> guide;
  final Future<void> Function(Map<String, dynamic>, String, String) onUpdate;

  const _EditGuideDialog({
    required this.guide,
    required this.onUpdate,
  });

  @override
  State<_EditGuideDialog> createState() => _EditGuideDialogState();
}

class _EditGuideDialogState extends State<_EditGuideDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.guide['name'] ?? widget.guide['title'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.guide['description'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar guía'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nombre de la guía',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Nombre de tu guía',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              maxLength: 100,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            const Text(
              'Descripción (opcional)',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Describe tu viaje...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              maxLines: 3,
              maxLength: 300,
              enabled: !_isLoading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Inicia sesión o regístrate'),
          content: Text(
              'Debes iniciar sesión o registrarte para guardar cambios en la guía.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/login');
              },
              child: Text('Iniciar sesión'),
            ),
          ],
        ),
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre no puede estar vacío'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await widget.onUpdate(
        widget.guide,
        _nameController.text.trim(),
        _descriptionController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
