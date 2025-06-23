import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/common/custom_bottom_navigation_bar.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:tourify_flutter/screens/guide_detail_screen.dart';

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
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _testFirebaseConnection(); // Probar conexión primero
    _fetchGuides();
  }

  Future<void> _fetchGuides() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Cargar mis guías
      await _fetchMyGuides(user.uid);

      // También cargar guías compartidas de una vez
      await _fetchSharedGuides(user.uid, user.email);
    } catch (error) {
      print("Error al cargar guías: $error");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMyGuides(String userId) async {
    try {
      print("🏠 Buscando mis guías para userId: $userId");
      final userRef = _firestore.collection('users').doc(userId);
      final guidesQuery = await _firestore
          .collection('guides')
          .where('userRef', isEqualTo: userRef)
          .orderBy('createdAt', descending: true)
          .get();

      print("🏠 Mis guías encontradas: ${guidesQuery.docs.length}");

      final myGuides = guidesQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'city': data['city'] ?? data['name'] ?? 'Sin título',
          'title': data['title'] ?? data['name'] ?? 'Sin título',
          'destination': data['city'] ?? data['name'] ?? 'Sin destino',
          'location': data['formattedAddress'] ??
              data['destination'] ??
              'Sin ubicación',
          'createdAt': data['createdAt'] ?? DateTime.now(),
          'views': data['views'] ?? 0,
          'totalDays': data['totalDays'] ?? 0,
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'name': data['name'] ?? 'Sin nombre',
          'isShared': false,
          'isPublic': data['isPublic'] ?? false,
        };
      }).toList();

      // Ordenar por fecha de creación descendente (más reciente primero)
      myGuides.sort((a, b) {
        final aDate = a['createdAt'] is Timestamp
            ? a['createdAt'].toDate()
            : a['createdAt'];
        final bDate = b['createdAt'] is Timestamp
            ? b['createdAt'].toDate()
            : b['createdAt'];
        return bDate.compareTo(aDate);
      });

      setState(() {
        _myGuides = myGuides;
      });
    } catch (error) {
      print("❌ Error al cargar mis guías: $error");
    }
  }

  Future<void> _fetchSharedGuides(String userId, String? userEmail) async {
    try {
      setState(() {
        _isLoadingShared = true;
      });

      print(
          "🔍 Buscando guías compartidas para user: $userId, email: $userEmail");
      final List<Map<String, dynamic>> sharedGuides = [];

      // Método 1: Buscar en la subcolección sharedWithMe del usuario
      final sharedWithMeRef =
          _firestore.collection('users').doc(userId).collection('sharedWithMe');
      final sharedWithMeDocs = await sharedWithMeRef.get();
      print(
          "📊 sharedWithMe tiene: ${sharedWithMeDocs.docs.length} documentos");

      for (final doc in sharedWithMeDocs.docs) {
        final data = doc.data();
        final guideId = data['guideId'] ?? doc.id;
        final role = data['role'] ?? 'viewer';
        final sharedAt = data['sharedAt'];
        final sharedBy = data['sharedBy'] ?? '';

        // Obtener los datos de la guía
        final guideRef = _firestore.collection('guides').doc(guideId);
        final guideDoc = await guideRef.get();
        if (guideDoc.exists) {
          final guideData = guideDoc.data()!;
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
            'views': guideData['views'] ?? 0,
            'totalDays': guideData['totalDays'] ?? 0,
            'startDate': guideData['startDate'],
            'endDate': guideData['endDate'],
            'name': guideData['name'] ?? 'Sin nombre',
            'isShared': true,
            'isPublic': guideData['isPublic'] ?? false,
            'role': role,
            'sharedBy': sharedBy,
            'sharedAt': sharedAt,
          });
        }
      }

      // Método 2: Si tienes email, también buscar en guías donde seas colaborador
      if (userEmail != null) {
        print("🔍 Buscando también por email de colaborador: $userEmail");
        final guidesQuery = await _firestore
            .collection('guides')
            .where('collaborators', arrayContains: {'email': userEmail}).get();

        print("📊 Guías donde soy colaborador: ${guidesQuery.docs.length}");

        for (final doc in guidesQuery.docs) {
          final guideData = doc.data();
          final guideId = doc.id;

          // Verificar que no esté ya en la lista (para evitar duplicados)
          if (!sharedGuides.any((guide) => guide['id'] == guideId)) {
            // Buscar el rol en la lista de colaboradores
            final collaborators =
                guideData['collaborators'] as List<dynamic>? ?? [];
            final myCollaboration = collaborators.firstWhere(
              (collab) => collab['email'] == userEmail,
              orElse: () => {'role': 'viewer'},
            );

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
              'views': guideData['views'] ?? 0,
              'totalDays': guideData['totalDays'] ?? 0,
              'startDate': guideData['startDate'],
              'endDate': guideData['endDate'],
              'name': guideData['name'] ?? 'Sin nombre',
              'isShared': true,
              'isPublic': guideData['isPublic'] ?? false,
              'role': myCollaboration['role'] ?? 'viewer',
              'sharedBy': 'Directo', // Indicar que se encontró directamente
              'sharedAt': null,
            });
          }
        }
      }

      print("✅ Total de guías compartidas encontradas: ${sharedGuides.length}");
      setState(() {
        _sharedGuides = sharedGuides;
      });
    } catch (error) {
      print("❌ Error al cargar guías compartidas: $error");
      setState(() {
        _sharedGuides = [];
      });
    } finally {
      setState(() {
        _isLoadingShared = false;
      });
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
      // Recargar mis guías
      await _fetchMyGuides(user.uid);

      // Recargar guías compartidas
      await _fetchSharedGuides(user.uid, user.email);
    } catch (error) {
      print("Error al actualizar guías: $error");
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingShared = false;
      });
    }
  }

  Future<void> _testFirebaseConnection() async {
    try {
      print("🔧 Probando conexión a Firebase...");
      final user = _auth.currentUser;
      print("👤 Usuario actual: ${user?.uid} - ${user?.email}");

      // Probar consulta simple a la colección de guías
      final testQuery = await _firestore.collection('guides').limit(1).get();
      print(
          "📊 Conexión exitosa. Documentos en guides: ${testQuery.docs.length}");

      // Probar collectionGroup
      final testCollectionGroup =
          await _firestore.collectionGroup('collaborators').limit(1).get();
      print(
          "👥 CollectionGroup funciona. Documentos en collaborators: ${testCollectionGroup.docs.length}");
    } catch (error) {
      print("❌ Error en prueba de Firebase: $error");
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
                  // Cabecera
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Mis Viajes',
                          style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Gestiona tus guías de viaje',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Tabs personalizados tipo segmented control
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedTabIndex = 0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.ease,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 0
                                      ? const Color(0xFF60A5FA)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map_outlined,
                                        size: 18,
                                        color: _selectedTabIndex == 0
                                            ? Colors.white
                                            : Colors.blue[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Mis Guías (${_myGuides.length})',
                                      style: TextStyle(
                                        color: _selectedTabIndex == 0
                                            ? Colors.white
                                            : Colors.blue[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedTabIndex = 1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.ease,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 1
                                      ? const Color(0xFF60A5FA)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outlined,
                                        size: 18,
                                        color: _selectedTabIndex == 1
                                            ? Colors.white
                                            : Colors.blue[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Compartidas (${_sharedGuides.length})',
                                      style: TextStyle(
                                        color: _selectedTabIndex == 1
                                            ? Colors.white
                                            : Colors.blue[700],
                                        fontWeight: FontWeight.bold,
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
                  ),
                  const SizedBox(height: 12),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTabIndex == 0
                  ? Icons.folder_outlined
                  : Icons.people_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTabIndex == 0
                  ? 'No tienes guías creadas'
                  : 'No tienes guías compartidas',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (_selectedTabIndex == 1) ...[
              const SizedBox(height: 8),
              Text(
                'Las guías que otros compartan contigo aparecerán aquí',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingShared)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _refreshGuides,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ],
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
    final String views = (guide['views'] ?? '0').toString();
    final int totalDays =
        int.tryParse(guide['totalDays']?.toString() ?? '0') ?? 0;
    final bool isShared = guide['isShared'] == true;
    final String role = (guide['role'] ?? '').toString();
    final bool isPublic = guide['isPublic'] == true;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GuideDetailScreen(
              guideId: guide['id'].toString(),
              guideTitle: title,
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPublic
              ? Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: isPublic
                  ? const Color(0xFF10B981).withOpacity(0.15)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GuideDetailScreen(
                    guideId: guide['id'].toString(),
                    guideTitle: title,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila superior: título a la izquierda, botones a la derecha
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Botón de editar nombre (solo si es propietario o editor)
                            if (!isShared ||
                                role == 'editor' ||
                                guide['role'] == null ||
                                guide['role'] == 'owner')
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                color: Colors.grey[600],
                                onPressed: () => _editGuideName(guide),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Mostrar botón de "Hacer privada" o botón de "Publicar"
                      if (isPublic &&
                          (guide['role'] == null || guide['role'] == 'owner'))
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.lock_outline, size: 16),
                          label: const Text('Hacer privada'),
                          onPressed: () => _confirmarHacerPrivada(guide),
                        )
                      else if (!isPublic &&
                          (guide['role'] == null || guide['role'] == 'owner'))
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.cloud_upload, size: 16),
                          label: const Text('Publicar'),
                          onPressed: () => _confirmarPublicarGuia(guide),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  if (isShared)
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            role == 'editor' ? 'Editor' : 'Acoplado',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isPublic) ...[
                        const Icon(Icons.visibility,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          views,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                      if (totalDays > 0) ...[
                        const SizedBox(width: 16),
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '$totalDays días',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
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

  void _confirmarHacerPrivada(Map<String, dynamic> guide) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Hacer privada?'),
        content: Text(
            '¿Seguro que quieres hacer privada "${guide['title']}"? Ya no será visible para otros usuarios.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _hacerPrivada(guide);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hacer privada'),
          ),
        ],
      ),
    );
  }

  void _confirmarPublicarGuia(Map<String, dynamic> guide) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Publicar guía?'),
        content: Text(
            '¿Seguro que quieres publicar "${guide['title']}"? Una vez publicada será visible para otros usuarios.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _publicarGuia(guide);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  Future<void> _hacerPrivada(Map<String, dynamic> guide) async {
    try {
      final guideId = guide['id'].toString();
      await _firestore
          .collection('guides')
          .doc(guideId)
          .update({'isPublic': false});
      setState(() {
        _myGuides = _myGuides.map((g) {
          if (g['id'] == guideId) {
            return {...g, 'isPublic': false};
          }
          return g;
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guía ahora es privada'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al hacer privada la guía: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _publicarGuia(Map<String, dynamic> guide) async {
    try {
      final guideId = guide['id'].toString();
      await _firestore
          .collection('guides')
          .doc(guideId)
          .update({'isPublic': true});
      setState(() {
        _myGuides = _myGuides.map((g) {
          if (g['id'] == guideId) {
            return {...g, 'isPublic': true};
          }
          return g;
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guía publicada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al publicar la guía: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
            backgroundColor: const Color(0xFF2196F3),
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
