import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourify_flutter/widgets/home/create_guide_button.dart';
import 'package:tourify_flutter/services/api_service.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:tourify_flutter/screens/guides/guide_detail_screen.dart';
import 'package:tourify_flutter/widgets/home/create_guide_modal.dart';
import 'package:tourify_flutter/widgets/common/custom_bottom_navigation_bar.dart';
import 'package:tourify_flutter/services/version_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tourify_flutter/screens/main/streak_screen.dart';
import 'dart:io' show Platform;

class HomeScreen extends StatefulWidget {
  final VersionCheckResult? recommendedUpdate;

  const HomeScreen({super.key, this.recommendedUpdate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _recentGuides = [];
  bool _isLoadingRecentGuides = true;
  bool _isLoadingStats = true;
  bool _hasStatsError = false;

  // Estadísticas del usuario
  int _totalGuides = 0;
  int _totalActivities = 0;
  int _uniqueCities = 0;
  int _totalDaysTraveled = 0;
  // Campos reservados para futuras métricas en home
  List<String> _visitedCities = [];
  Map<String, int> _cityVisitCount = {};

  // Datos de racha
  int _citiesGoal = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastTravelDate;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    print('=== HomeScreen initState ===');
    WidgetsBinding.instance.addObserver(this);
    _loadRecentGuides();
    print('Llamando a _loadUserStats desde initState');
    _loadUserStats();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Recargar datos cuando la app vuelve al primer plano
      _refreshData();
    }
  }

  Future<void> _loadRecentGuides() async {
    setState(() {
      _isLoadingRecentGuides = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _recentGuides = [];
          _isLoadingRecentGuides = false;
        });
        return;
      }

      final userRef = _firestore.collection('users').doc(user.uid);

      // 0) Intentar backend primero
      try {
        final serverGuides = await _api.fetchRecentGuides();
        if (serverGuides.isNotEmpty) {
          setState(() {
            _recentGuides = serverGuides;
            _isLoadingRecentGuides = false;
          });
          return;
        }
      } catch (_) {}
      // Últimas abiertas: leer primero recentlyOpened
      final roSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('recentlyOpened')
          .orderBy('openedAt', descending: true)
          .limit(15)
          .get();

      final recentlyIds = roSnap.docs.map((d) => d.id).toList();

      // Guías propias (para fallback y completar datos)
      // 1) Por userRef
      List<QueryDocumentSnapshot> ownDocs = [];
      try {
        final q1 = await _firestore
            .collection('guides')
            .where('userRef', isEqualTo: userRef)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();
        ownDocs.addAll(q1.docs);
      } catch (_) {
        try {
          final q1 = await _firestore
              .collection('guides')
              .where('userRef', isEqualTo: userRef)
              .limit(20)
              .get();
          ownDocs.addAll(q1.docs);
        } catch (_) {}
      }
      // 2) Fallback por userId
      try {
        final q2 = await _firestore
            .collection('guides')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();
        ownDocs.addAll(q2.docs);
      } catch (_) {
        try {
          final q2 = await _firestore
              .collection('guides')
              .where('userId', isEqualTo: user.uid)
              .limit(20)
              .get();
          ownDocs.addAll(q2.docs);
        } catch (_) {}
      }

      List<Map<String, dynamic>> recentGuides = ownDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final created = data['createdAt'];
        DateTime createdDt;
        if (created is Timestamp) {
          createdDt = created.toDate();
        } else if (created is String) {
          createdDt = DateTime.tryParse(created) ?? DateTime.now();
        } else if (created is DateTime) {
          createdDt = created;
        } else {
          createdDt = DateTime.now();
        }
        return {
          'id': doc.id,
          'title': data['title'] ?? data['name'] ?? 'Sin título',
          'city': data['city'] ?? data['name'] ?? 'Sin título',
          'location': data['formattedAddress'] ??
              data['destination'] ??
              'Sin ubicación',
          'createdAt': createdDt,
          'sortDate': createdDt,
          'totalDays': data['totalDays'] ?? 0,
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'isShared': false,
        };
      }).toList();

      // Guías compartidas
      try {
        QuerySnapshot sharedSnap;
        try {
          sharedSnap = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('sharedWithMe')
              .orderBy('sharedAt', descending: true)
              .limit(12)
              .get();
        } catch (_) {
          // Sin índice: obtener sin orden y ordenar en memoria luego
          sharedSnap = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('sharedWithMe')
              .limit(12)
              .get();
        }

        // Ordenar en memoria si fue necesario
        final sharedDocs = List<QueryDocumentSnapshot>.from(sharedSnap.docs);
        sharedDocs.sort((a, b) {
          final sa = (a.data() as Map<String, dynamic>)['sharedAt'];
          final sb = (b.data() as Map<String, dynamic>)['sharedAt'];
          DateTime da;
          DateTime db;
          if (sa is Timestamp) {
            da = sa.toDate();
          } else if (sa is String) {
            da =
                DateTime.tryParse(sa) ?? DateTime.fromMillisecondsSinceEpoch(0);
          } else if (sa is DateTime) {
            da = sa;
          } else {
            da = DateTime.fromMillisecondsSinceEpoch(0);
          }
          if (sb is Timestamp) {
            db = sb.toDate();
          } else if (sb is String) {
            db =
                DateTime.tryParse(sb) ?? DateTime.fromMillisecondsSinceEpoch(0);
          } else if (sb is DateTime) {
            db = sb;
          } else {
            db = DateTime.fromMillisecondsSinceEpoch(0);
          }
          return db.compareTo(da);
        });

        for (final s in sharedDocs) {
          final shared = (s.data() as Map<String, dynamic>?) ?? {};
          final guideId = shared['guideId'] as String?;
          if (guideId == null) continue;
          try {
            final guideDoc =
                await _firestore.collection('guides').doc(guideId).get();
            if (!guideDoc.exists) continue;
            final g = (guideDoc.data() as Map<String, dynamic>?) ?? {};
            final sharedAt = shared['sharedAt'];
            DateTime sharedDt;
            if (sharedAt is Timestamp) {
              sharedDt = sharedAt.toDate();
            } else if (sharedAt is String) {
              sharedDt = DateTime.tryParse(sharedAt) ?? DateTime.now();
            } else if (sharedAt is DateTime) {
              sharedDt = sharedAt;
            } else {
              sharedDt = DateTime.now();
            }
            recentGuides.add({
              'id': guideDoc.id,
              'title': g['title'] ?? g['name'] ?? 'Sin título',
              'city': g['city'] ?? g['name'] ?? 'Sin título',
              'location':
                  g['formattedAddress'] ?? g['destination'] ?? 'Sin ubicación',
              'createdAt': g['createdAt'] ?? sharedDt,
              'sortDate': sharedDt,
              'totalDays': g['totalDays'] ?? 0,
              'startDate': g['startDate'],
              'endDate': g['endDate'],
              'isShared': true,
            });
          } catch (_) {}
        }
      } catch (_) {}

      // Si hay recentlyOpened, reordenar priorizando ese orden
      final seen = <String>{};
      List<Map<String, dynamic>> combined;
      if (recentlyIds.isNotEmpty) {
        // Mapa por id para acceso rápido
        final byId = {for (final g in recentGuides) (g['id'] as String): g};
        combined = [];
        for (final id in recentlyIds) {
          final g = byId[id];
          if (g != null && !seen.contains(id)) {
            seen.add(id);
            combined.add(g);
          }
        }
        // Completar hasta 10 con el resto más recientes
        recentGuides.sort((a, b) {
          final DateTime bd = b['sortDate'] is DateTime
              ? b['sortDate'] as DateTime
              : DateTime.now();
          final DateTime ad = a['sortDate'] is DateTime
              ? a['sortDate'] as DateTime
              : DateTime.now();
          return bd.compareTo(ad);
        });
        for (final g in recentGuides) {
          final id = (g['id'] ?? '') as String;
          if (id.isEmpty || seen.contains(id)) continue;
          combined.add(g);
          seen.add(id);
          if (combined.length >= 10) break;
        }
      } else {
        // Sin recentlyOpened: ordenar por fecha como antes
        recentGuides.sort((a, b) {
          final DateTime bd = b['sortDate'] is DateTime
              ? b['sortDate'] as DateTime
              : DateTime.now();
          final DateTime ad = a['sortDate'] is DateTime
              ? a['sortDate'] as DateTime
              : DateTime.now();
          return bd.compareTo(ad);
        });
        combined = [];
        for (final g in recentGuides) {
          final id = (g['id'] ?? '') as String;
          if (id.isEmpty || seen.contains(id)) continue;
          seen.add(id);
          combined.add(g);
          if (combined.length >= 10) break;
        }
      }

      setState(() {
        _recentGuides = combined;
        _isLoadingRecentGuides = false;
      });

      // Fallback de emergencia: si sigue vacío, intentar una consulta simple por userId sin ordenar
      if (combined.isEmpty) {
        try {
          final q = await _firestore
              .collection('guides')
              .where('userId', isEqualTo: user.uid)
              .limit(10)
              .get();
          if (q.docs.isNotEmpty) {
            final extra = q.docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>? ?? {};
              return {
                'id': doc.id,
                'title': d['title'] ?? d['name'] ?? 'Sin título',
                'city': d['city'] ?? d['name'] ?? 'Sin título',
                'location': d['formattedAddress'] ??
                    d['destination'] ??
                    'Sin ubicación',
                'createdAt': DateTime.now(),
                'sortDate': DateTime.now(),
                'totalDays': d['totalDays'] ?? 0,
                'startDate': d['startDate'],
                'endDate': d['endDate'],
                'isShared': false,
              };
            }).toList();
            setState(() {
              _recentGuides = extra;
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Error loading recent guides: $e');
      setState(() {
        _recentGuides = [];
        _isLoadingRecentGuides = false;
      });
    }
  }

  Future<void> _loadUserStats() async {
    print('=== INICIANDO _loadUserStats ===');

    setState(() {
      _isLoadingStats = true;
      _hasStatsError = false;
    });

    try {
      final user = _auth.currentUser;
      print('Usuario actual: ${user?.uid ?? 'null'}');

      if (user == null) {
        print('Usuario no autenticado, no se pueden cargar estadísticas');
        setState(() {
          _isLoadingStats = false;
        });
        return;
      }

      // Cargar datos de racha del usuario
      await _loadUserStreakData(user);

      print('Cargando estadísticas para usuario: ${user.uid}');

      // Cargar estadísticas reales desde Firestore
      try {
        print('Iniciando consulta a Firestore...');

        // Obtener todas las guías del usuario
        final userRef = _firestore.collection('users').doc(user.uid);
        final guidesQuery = await _firestore
            .collection('guides')
            .where('userRef', isEqualTo: userRef)
            .get()
            .timeout(const Duration(seconds: 10));

        print('Encontradas ${guidesQuery.docs.length} guías del usuario');

        if (guidesQuery.docs.isNotEmpty) {
          await _processGuidesData(guidesQuery.docs);
        } else {
          // Intentar con userId como string
          final guidesQuery2 = await _firestore
              .collection('guides')
              .where('userId', isEqualTo: user.uid)
              .get()
              .timeout(const Duration(seconds: 10));

          print('Encontradas ${guidesQuery2.docs.length} guías con userId');

          if (guidesQuery2.docs.isNotEmpty) {
            await _processGuidesData(guidesQuery2.docs);
          } else {
            print('No se encontraron guías, estableciendo valores por defecto');
            _setDefaultStats();
          }
        }
      } catch (e) {
        print('Error cargando estadísticas: $e');
        _setDefaultStats();
      }

      print('=== FINALIZANDO _loadUserStats ===');
    } catch (e) {
      print('Error general cargando estadísticas: $e');
      setState(() {
        _isLoadingStats = false;
        _hasStatsError = true;
      });
    }
  }

  Future<void> _loadUserStreakData(User user) async {
    try {
      // Obtener datos del usuario desde Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        setState(() {
          _citiesGoal = userData['citiesGoal'] ?? 0;
        });

        // Calcular racha basándose en las guías creadas
        await _calculateStreakFromGuides(user.uid);
      } else {
        // Si no existe el documento, establecer valores por defecto
        setState(() {
          _citiesGoal = 0;
          _currentStreak = 0;
          _longestStreak = 0;
          _lastTravelDate = null;
        });
      }
    } catch (e) {
      print('Error cargando datos de racha: $e');
      // En caso de error, establecer valores por defecto
      setState(() {
        _citiesGoal = 0;
        _currentStreak = 0;
        _longestStreak = 0;
        _lastTravelDate = null;
      });
    }
  }

  Future<void> _calculateStreakFromGuides(String userId) async {
    try {
      print('Calculando racha para usuario: $userId');

      // Obtener todas las guías del usuario
      final userRef = _firestore.collection('users').doc(userId);
      final guidesQuery = await _firestore
          .collection('guides')
          .where('userRef', isEqualTo: userRef)
          .orderBy('createdAt', descending: true)
          .get();

      // Si no hay guías con userRef, intentar con userId
      List<QueryDocumentSnapshot> guides = guidesQuery.docs;
      if (guides.isEmpty) {
        final guidesQuery2 = await _firestore
            .collection('guides')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();
        guides = guidesQuery2.docs;
      }

      print('Encontradas ${guides.length} guías para calcular racha');

      if (guides.isEmpty) {
        setState(() {
          _currentStreak = 0;
          _longestStreak = 0;
          _lastTravelDate = null;
        });
        return;
      }

      // Procesar fechas de creación de guías
      final List<DateTime> guideDates = [];
      DateTime? lastTravelDate;

      for (var doc in guides) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'];

        if (createdAt != null) {
          DateTime guideDate;
          if (createdAt is Timestamp) {
            guideDate = createdAt.toDate();
          } else if (createdAt is String) {
            guideDate = DateTime.tryParse(createdAt) ?? DateTime.now();
          } else {
            continue;
          }

          guideDates.add(guideDate);
          if (lastTravelDate == null || guideDate.isAfter(lastTravelDate)) {
            lastTravelDate = guideDate;
          }
        }
      }

      // Calcular racha mensual
      final streakData = _calculateMonthlyStreak(guideDates);

      setState(() {
        _currentStreak = streakData['currentStreak'] ?? 0;
        _longestStreak = streakData['longestStreak'] ?? 0;
        _lastTravelDate = lastTravelDate;
      });

      // Actualizar datos en Firestore
      await _updateStreakInFirestore(userId, streakData, lastTravelDate);

      print('Racha calculada:');
      print('  - Racha actual: $_currentStreak meses');
      print('  - Racha más larga: $_longestStreak meses');
      print('  - Último viaje: $_lastTravelDate');
    } catch (e) {
      print('Error calculando racha: $e');
    }
  }

  Map<String, int> _calculateMonthlyStreak(List<DateTime> guideDates) {
    if (guideDates.isEmpty) {
      return {'currentStreak': 0, 'longestStreak': 0};
    }

    // Ordenar fechas de más reciente a más antigua
    guideDates.sort((a, b) => b.compareTo(a));

    // Agrupar por mes y año
    final Map<String, int> monthlyGuides = {};
    for (var date in guideDates) {
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthlyGuides[monthKey] = (monthlyGuides[monthKey] ?? 0) + 1;
    }

    print('Guías por mes: $monthlyGuides');

    // Calcular racha actual
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    final now = DateTime.now();

    // Verificar meses consecutivos desde el mes actual hacia atrás
    for (int i = 0; i < 3; i++) {
      // Revisar solo los últimos 3 meses
      final checkDate = DateTime(now.year, now.month - i, 1);
      final monthKey =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}';

      if (monthlyGuides.containsKey(monthKey) && monthlyGuides[monthKey]! > 0) {
        tempStreak++;
        if (currentStreak == 0) {
          currentStreak = tempStreak;
        }
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
      } else {
        tempStreak = 0;
        // Si ya encontramos la racha actual, podemos parar
        if (currentStreak > 0) {
          break;
        }
      }
    }

    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
    };
  }

  Future<void> _updateStreakInFirestore(String userId,
      Map<String, int> streakData, DateTime? lastTravelDate) async {
    try {
      final updateData = {
        'currentStreak': streakData['currentStreak'],
        'longestStreak': streakData['longestStreak'],
        'lastTravelDate':
            lastTravelDate != null ? Timestamp.fromDate(lastTravelDate) : null,
        'streakLastUpdated': Timestamp.now(),
      };

      await _firestore.collection('users').doc(userId).update(updateData);
      print('Datos de racha actualizados en Firestore');
    } catch (e) {
      print('Error actualizando racha en Firestore: $e');
    }
  }

  void _setDefaultStats() {
    print('Estableciendo estadísticas por defecto');
    setState(() {
      _totalGuides = 0;
      _totalActivities = 0;
      _uniqueCities = 0;
      _totalDaysTraveled = 0;
      _visitedCities = [];
      _cityVisitCount = {};
      _isLoadingStats = false;
      _hasStatsError = false;
    });
  }

  Future<void> _processGuidesData(List<QueryDocumentSnapshot> docs) async {
    print('Procesando ${docs.length} guías...');

    int totalActivities = 0;
    int totalDaysTraveled = 0;
    Set<String> uniqueCities = {};
    Map<String, int> cityVisitCount = {};

    for (var doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final guideTitle = data['title'] ?? data['name'] ?? 'Sin título';
        print('Procesando guía: $guideTitle');

        // Contar días y actividades desde la subcolección "days"
        try {
          final daysSnapshot = await _firestore
              .collection('guides')
              .doc(doc.id)
              .collection('days')
              .get();

          final daysCount = daysSnapshot.docs.length;
          totalDaysTraveled += daysCount;
          print('  - Días (subcolección): $daysCount');

          // Contar actividades desde los arrays dentro de cada día
          int activitiesInGuide = 0;
          for (var dayDoc in daysSnapshot.docs) {
            final dayData = dayDoc.data() as Map<String, dynamic>;
            if (dayData['activities'] != null) {
              final activities = dayData['activities'];
              if (activities is List) {
                activitiesInGuide += activities.length;
              } else if (activities is Map) {
                activitiesInGuide += activities.length;
              }
            }
          }

          totalActivities += activitiesInGuide;
          print('  - Actividades (desde días): $activitiesInGuide');
        } catch (e) {
          print('  - Error leyendo días/actividades: $e');
          // Fallback: intentar leer desde los campos de la guía
          int totalDays = 0;
          final daysData = data['totalDays'];
          if (daysData != null) {
            if (daysData is int) {
              totalDays = daysData;
            } else if (daysData is double) {
              totalDays = daysData.toInt();
            } else if (daysData is String) {
              totalDays = int.tryParse(daysData) ?? 0;
            }
          }
          totalDaysTraveled += totalDays;
          print('  - Días (fallback): $totalDays');

          // Fallback para actividades
          if (data['activities'] != null) {
            final activities = data['activities'];
            if (activities is List) {
              totalActivities += activities.length;
              print('  - Actividades (campo guía): ${activities.length}');
            } else if (activities is Map) {
              totalActivities += activities.length;
              print('  - Actividades (Map guía): ${activities.length}');
            }
          }
        }

        // Contar ciudades únicas
        final city = data['city'] ?? data['destination'] ?? data['name'] ?? '';
        if (city.isNotEmpty && city != 'Sin título') {
          uniqueCities.add(city);
          cityVisitCount[city] = (cityVisitCount[city] ?? 0) + 1;
          print('  - Ciudad: $city');
        }
      } catch (e) {
        print('Error procesando guía ${doc.id}: $e');
      }
    }

    print('Estadísticas finales:');
    print('  - Total guías: ${docs.length}');
    print('  - Total actividades: $totalActivities');
    print('  - Total días: $totalDaysTraveled');
    print('  - Ciudades únicas: ${uniqueCities.length}');

    setState(() {
      _totalGuides = docs.length;
      _totalActivities = totalActivities;
      _uniqueCities = uniqueCities.length;
      _totalDaysTraveled = totalDaysTraveled;
      _visitedCities = uniqueCities.toList()..sort();
      _cityVisitCount = cityVisitCount;
      _isLoadingStats = false;
      _hasStatsError = false;
    });
  }

  void _showCreateGuideModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateGuideModal(),
    );
  }

  Future<void> _refreshData() async {
    print('=== REFRESH DATA ===');
    await Future.wait([
      _loadRecentGuides(),
      _loadUserStats(),
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notificación de actualización recomendada (no invasiva)
            if (widget.recommendedUpdate?.hasRecommendedUpdate == true)
              _buildUpdateNotification(),
            const SizedBox(height: 32),
            // Botón "Me voy de viaje" al principio
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CreateGuideButton(
                onTap: _showCreateGuideModal,
              ),
            ),
            const SizedBox(height: 16),

            // Sección de racha de viajes (parte superior)
            if (_auth.currentUser != null) ...[
              const SizedBox(height: 18),
              _buildStreakSection(),
              const SizedBox(height: 16),
            ],

            // Divisor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Divider(
                color: Colors.grey.withOpacity(0.3),
                thickness: 1,
                height: 32,
              ),
            ),
            // Contenido scrolleable
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sección de mis últimas guías (ahora primero)
                      if (_auth.currentUser != null) ...[
                        _buildRecentGuidesSection(),
                        const SizedBox(height: 32),
                      ],

                      // Sección de estadísticas del usuario
                      if (_auth.currentUser != null) ...[
                        _buildUserStatsSection(),
                        const SizedBox(height: 32),
                      ],

                      // Sección motivacional para usuarios no autenticados
                      if (_auth.currentUser == null) ...[
                        _buildMotivationalSection(),
                        const SizedBox(height: 32),
                      ],

                      const SizedBox(height: 100), // Espacio para el navbar
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          final user = FirebaseAuth.instance.currentUser;
          switch (index) {
            case 0:
              // Ya estás en Home
              break;
            case 1:
              if (user == null) {
                _showLoginRequiredDialog();
              } else {
                NavigationService.navigateToMainScreen('/my-guides');
              }
              break;
            case 2:
              if (user == null) {
                _showLoginRequiredDialog();
              } else {
                NavigationService.navigateToMainScreen('/profile');
              }
              break;
          }
        },
      ),
    );
  }

  Widget _buildUserStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tu aventura en números',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _loadUserStats,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: const Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingStats)
            Container(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF3B82F6),
                ),
              ),
            )
          else if (_hasStatsError)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No pudimos cargar tus estadísticas',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _loadUserStats,
                      child: Text(
                        'Reintentar',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Estadísticas principales
                Row(
                  children: [
                    Expanded(
                        child: _buildStatCard('Guías Creadas',
                            _totalGuides.toString(), Icons.map_rounded)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildStatCard(
                            'Actividades',
                            _totalActivities.toString(),
                            Icons.explore_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildStatCard(
                            'Ciudades Visitadas',
                            _uniqueCities.toString(),
                            Icons.location_city_rounded)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildStatCard(
                            'Días de Viaje',
                            _totalDaysTraveled.toString(),
                            Icons.calendar_today_rounded)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStreakSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StreakScreen(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade50,
                Colors.orange.shade100.withOpacity(0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.orange.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.orange[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _citiesGoal > 0 ? 'Racha de viajes' : 'Configurar racha',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _citiesGoal > 0
                          ? '$_currentStreak ${_currentStreak == 1 ? 'mes' : 'meses'} consecutivos'
                          : 'Establece tu objetivo de viajes',
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.orange[700],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // widget no usado eliminado para limpiar lints

  // utilidades no usadas eliminadas para limpiar lints

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6),
                  const Color(0xFF1D4ED8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Descubre el mundo!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6),
                  const Color(0xFF1D4ED8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.explore_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Planifica tu próxima aventura',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Crea itinerarios únicos y comparte experiencias inolvidables',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildMotivationalFeature(
                        'Organiza', Icons.calendar_today_rounded),
                    const SizedBox(width: 16),
                    _buildMotivationalFeature('Descubre', Icons.map_rounded),
                    const SizedBox(width: 16),
                    _buildMotivationalFeature('Inspira', Icons.share_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalFeature(String title, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentGuidesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tus viajes recientes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              if (_recentGuides.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextButton(
                    onPressed: () {
                      NavigationService.navigateToMainScreen('/my-guides');
                    },
                    child: Text(
                      'Ver todas',
                      style: TextStyle(
                        color: const Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingRecentGuides)
            Container(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF3B82F6),
                ),
              ),
            )
          else if (_recentGuides.isEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.explore_outlined,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¡Tu primera aventura te espera!',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crea tu primera guía y comienza a explorar',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentGuides.length,
                itemBuilder: (context, index) {
                  final guide = _recentGuides[index];
                  return _buildRecentGuideCard(guide);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentGuideCard(Map<String, dynamic> guide) {
    final String title = guide['title'] ?? 'Sin título';
    final String location = guide['location'] ?? 'Sin ubicación';
    final int totalDays = guide['totalDays'] ?? 0;
    final bool isShared = guide['isShared'] == true;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: RouteSettings(name: 'Guide: $title'),
                builder: (context) => GuideDetailScreen(
                  guideId: guide['id'],
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6),
                            const Color(0xFF1D4ED8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.map_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isShared) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF10B981)
                                            .withOpacity(0.3)),
                                  ),
                                  child: const Text(
                                    'Compartida',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (totalDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalDays día${totalDays > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: const Color(0xFF3B82F6),
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

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¡Únete a la aventura!'),
        content: Text(
            'Inicia sesión o regístrate para crear y compartir tus viajes.'),
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
              NavigationService.navigateToMainScreen(
                  '/login'); // Ajusta la ruta si es diferente
            },
            child: Text('Iniciar sesión'),
          ),
        ],
      ),
    );
  }

  /// Construye la notificación no invasiva de actualización recomendada
  Widget _buildUpdateNotification() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.system_update,
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¡Nueva versión disponible!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  widget.recommendedUpdate?.message ??
                      'Descarga la versión ${widget.recommendedUpdate?.recommendedVersion} con nuevas mejoras',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              String? url = widget.recommendedUpdate?.storeUrl;
              // Si no tenemos URL configurada o estamos en iOS y queremos forzar
              // la App Store, usamos el enlace por defecto según plataforma.
              if (url == null || url.isEmpty) {
                url = Platform.isIOS
                    ? 'https://apps.apple.com/us/app/tourify/id6747407603' // Sustituye por tu ID real
                    : 'https://play.google.com/store/apps/details?id=com.mycompany.tourify';
              }

              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: Text(
              'Actualizar',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
