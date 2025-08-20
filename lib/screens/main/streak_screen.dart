import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourify_flutter/services/user_service.dart';
import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:tourify_flutter/config/app_colors.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Datos de racha
  int _citiesGoal = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastTravelDate;
  List<Map<String, dynamic>> _streakHistory = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadStreakData();
  }

  Future<void> _loadStreakData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;

          setState(() {
            _citiesGoal = userData['citiesGoal'] ?? 0;
          });

          // Calcular racha y cargar historial
          await _calculateStreakFromGuides(user.uid);
          await _loadStreakHistory(user.uid);
        }
      }
    } catch (e) {
      print('Error cargando datos de racha: $e');
    } finally {
      setState(() {
        _isLoading = false;
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

  Future<void> _loadStreakHistory(String userId) async {
    try {
      print('Cargando historial de racha para usuario: $userId');

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

      print('Encontradas ${guides.length} guías para historial');

      // Procesar fechas de creación de guías
      final Map<String, int> monthlyGuides = {};
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

          final monthKey =
              '${guideDate.year}-${guideDate.month.toString().padLeft(2, '0')}';
          monthlyGuides[monthKey] = (monthlyGuides[monthKey] ?? 0) + 1;
        }
      }

      // Generar historial de los últimos 3 meses
      final List<Map<String, dynamic>> history = [];
      final now = DateTime.now();

      for (int i = 2; i >= 0; i--) {
        final checkDate = DateTime(now.year, now.month - i, 1);
        final monthKey =
            '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}';
        final monthName = _getMonthName(checkDate);
        final cities = monthlyGuides[monthKey] ?? 0;
        final goal = _citiesGoal;
        final completed = cities >= goal && goal > 0;

        history.add({
          'month': monthName,
          'cities': cities,
          'goal': goal,
          'completed': completed,
          'monthKey': monthKey,
        });
      }

      setState(() {
        _streakHistory = history;
      });

      print('Historial generado: ${history.length} meses');
    } catch (e) {
      print('Error cargando historial: $e');
    }
  }

  String _getMonthName(DateTime date) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _updateCitiesGoal(int newGoal) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await UserService.updateUserData(
          user.uid,
          {'citiesGoal': newGoal},
        );

        setState(() {
          _citiesGoal = newGoal;
        });

        // Analytics
        await AnalyticsService.trackEvent('streak_goal_updated', parameters: {
          'new_goal': newGoal,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Objetivo actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar objetivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Racha de Viajes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Explicación de la racha
                  _buildExplanationSection(),
                  const SizedBox(height: 24),

                  // Estadísticas actuales
                  _buildCurrentStatsSection(),
                  const SizedBox(height: 24),

                  // Cambiar objetivo
                  _buildGoalSection(),
                  const SizedBox(height: 24),

                  // Historial de racha
                  _buildHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildExplanationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade400,
            Colors.orange.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  Icons.local_fire_department_rounded,
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
                      '¿Qué es la Racha de Viajes?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mantén una racha mensual visitando ciudades.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu Racha Actual',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Racha actual',
                  '$_currentStreak ${_currentStreak == 1 ? 'mes' : 'meses'}',
                  Icons.local_fire_department_rounded,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Racha más larga',
                  '$_longestStreak ${_longestStreak == 1 ? 'mes' : 'meses'}',
                  Icons.trending_up_rounded,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Último viaje',
                  _getLastTravelText(),
                  Icons.calendar_today_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Objetivo',
                  _getCitiesGoalText(_citiesGoal),
                  Icons.flag_rounded,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String title, String value, IconData icon, Color color) {
    return Container(
      height: 100, // Altura fija para todos los contenedores
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center, // Centrar el contenido verticalmente
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cambiar Objetivo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '¿Qué tipo de viajero eres?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(
                initialItem: _citiesGoal > 0 ? _citiesGoal - 1 : 0,
              ),
              itemExtent: 50,
              onSelectedItemChanged: (int index) {
                if (!_isSaving) {
                  _updateCitiesGoal(index + 1);
                }
              },
              children: [
                _buildGoalOption('1 cada dos meses', 'Relajado', 1),
                _buildGoalOption('1 al mes', 'Moderado', 2),
                _buildGoalOption('2 al mes', 'Activo', 3),
                _buildGoalOption('4 al mes', 'Intenso', 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalOption(String title, String subtitle, int goal) {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color:
                  _citiesGoal == goal ? Colors.orange[700] : Colors.grey[700],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color:
                  _citiesGoal == goal ? Colors.orange[600] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de Racha',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          if (_streakHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aún no hay historial',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_streakHistory.map((month) => _buildHistoryItem(month))),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> month) {
    final bool completed = month['completed'] as bool;
    final int cities = month['cities'] as int;
    final int goal = month['goal'] as int;
    final String monthName = month['month'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: completed ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                Text(
                  '$cities/$goal ciudades',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: completed ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              completed ? 'Completado' : 'Incompleto',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCitiesGoalText(int goal) {
    switch (goal) {
      case 1:
        return '1 cada 2 meses';
      case 2:
        return '1 al mes';
      case 3:
        return '2 al mes';
      case 4:
        return '4 al mes';
      default:
        return 'Sin objetivo';
    }
  }

  String _getLastTravelText() {
    if (_lastTravelDate == null) {
      return 'Nunca';
    }

    final now = DateTime.now();
    final difference = now.difference(_lastTravelDate!).inDays;

    if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Ayer';
    } else if (difference < 7) {
      return 'Hace $difference días';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return 'Hace $weeks semana${weeks > 1 ? 's' : ''}';
    } else {
      final months = (difference / 30).floor();
      return 'Hace $months mes${months > 1 ? 'es' : ''}';
    }
  }
}
