import 'package:flutter/material.dart';
import 'package:tourify_flutter/data/activity.dart';
import 'dart:ui' show lerpDouble;

class OrganizeActivitiesScreen extends StatefulWidget {
  final List<DayActivities> dayActivities;
  final Function(List<DayActivities>) onReorganize;
  final String guideId;

  const OrganizeActivitiesScreen({
    super.key,
    required this.dayActivities,
    required this.onReorganize,
    required this.guideId,
  });

  @override
  State<OrganizeActivitiesScreen> createState() =>
      _OrganizeActivitiesScreenState();
}

class _OrganizeActivitiesScreenState extends State<OrganizeActivitiesScreen> {
  late List<Activity> _allActivities;
  late List<DayActivities> _workingDayActivities;

  @override
  void initState() {
    super.initState();
    _workingDayActivities = widget.dayActivities
        .map((day) => DayActivities(
              dayNumber: day.dayNumber,
              activities: List.from(day.activities),
            ))
        .toList();

    // Crear una lista unificada de todas las actividades ordenadas por día y luego por orden
    _allActivities = [];
    for (final day in _workingDayActivities) {
      _allActivities.addAll(day.activities);
    }
    _allActivities.sort((a, b) {
      if (a.day != b.day) {
        return a.day.compareTo(b.day);
      }
      final orderA = a.order ?? 0;
      final orderB = b.order ?? 0;
      return orderA.compareTo(orderB);
    });
  }

  void _reorderActivities(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      
      // Necesitamos mapear los índices de la lista expandida a los índices de actividades
      // Los separadores no se pueden mover, solo las actividades
      int activityOldIndex = _getActivityIndexFromExpandedIndex(oldIndex);
      int activityNewIndex = _getActivityIndexFromExpandedIndex(newIndex);
      
      if (activityOldIndex != -1 && activityNewIndex != -1) {
        final activity = _allActivities.removeAt(activityOldIndex);
        _allActivities.insert(activityNewIndex, activity);
        _reassignDaysAndOrders();
      }
    });
  }

  int _getActivityIndexFromExpandedIndex(int expandedIndex) {
    int activityCount = 0;
    int currentExpandedIndex = 0;
    
    for (int i = 0; i < _allActivities.length; i++) {
      final activity = _allActivities[i];
      final isFirstOfDay = i == 0 || activity.day != _allActivities[i - 1].day;
      
      // Si es el primer día, hay un separador
      if (isFirstOfDay) {
        if (currentExpandedIndex == expandedIndex) {
          return -1; // Es un separador, no una actividad
        }
        currentExpandedIndex++;
      }
      
      // Verificar si es la actividad que buscamos
      if (currentExpandedIndex == expandedIndex) {
        return activityCount;
      }
      
      currentExpandedIndex++;
      activityCount++;
    }
    
    return -1;
  }

  void _reassignDaysAndOrders() {
    if (_allActivities.isEmpty) return;

    // Obtener todos los días únicos disponibles
    final originalDays = widget.dayActivities.map((d) => d.dayNumber).toList()
      ..sort();

    if (originalDays.isEmpty) {
      originalDays.add(1);
    }

    // LÓGICA SIMPLE: Basarse únicamente en la POSICIÓN en la lista
    // Sin redistribución automática - el usuario controla todo con el drag

    final totalActivities = _allActivities.length;
    final totalDays = originalDays.length;

    // Calcular cuántas actividades van en cada día (distribución uniforme)
    final activitiesPerDay = (totalActivities / totalDays).ceil();

    for (int i = 0; i < _allActivities.length; i++) {
      // Determinar a qué día pertenece basándose SOLO en la posición
      final dayIndex = (i / activitiesPerDay).floor().clamp(0, totalDays - 1);
      final targetDay = originalDays[dayIndex];

      // Calcular orden dentro del día
      final orderInDay = i % activitiesPerDay;

      // Solo actualizar si es necesario
      if (_allActivities[i].day != targetDay ||
          _allActivities[i].order != orderInDay) {
        _allActivities[i] = Activity(
          id: _allActivities[i].id,
          title: _allActivities[i].title,
          description: _allActivities[i].description,
          duration: _allActivities[i].duration,
          day: targetDay,
          order: orderInDay,
          images: _allActivities[i].images,
          city: _allActivities[i].city,
          category: _allActivities[i].category,
          likes: _allActivities[i].likes,
          startTime: _allActivities[i].startTime,
          endTime: _allActivities[i].endTime,
          price: _allActivities[i].price,
        );
      }
    }
  }

  void _updateDayAssignments() {
    // Reconstruir la estructura de días basada en la lista reordenada
    _workingDayActivities.clear();

    Map<int, List<Activity>> dayGroups = {};
    for (final activity in _allActivities) {
      final dayNum = activity.day;
      if (!dayGroups.containsKey(dayNum)) {
        dayGroups[dayNum] = [];
      }
      dayGroups[dayNum]!.add(activity);
    }

    // Ordenar las keys y crear DayActivities
    final sortedKeys = dayGroups.keys.toList()..sort();
    for (final dayNum in sortedKeys) {
      _workingDayActivities.add(DayActivities(
        dayNumber: dayNum,
        activities: dayGroups[dayNum]!,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Organizar actividades',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _updateDayAssignments();
              widget.onReorganize(_workingDayActivities);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Actividades reorganizadas'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Guardar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
        ],
      ),
      body: _allActivities.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.reorder_rounded,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No hay actividades para organizar',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : _buildActivityListWithSeparators(),
    );
  }

  Widget _buildActivityListWithSeparators() {
    // Crear una lista expandida con separadores
    final List<Widget> allItems = [];

    for (int i = 0; i < _allActivities.length; i++) {
      final activity = _allActivities[i];
      final isFirstOfDay = i == 0 || activity.day != _allActivities[i - 1].day;

      // Agregar separador si es necesario
      if (isFirstOfDay) {
        allItems.add(_buildDaySeparator(activity.day, i == 0));
      }

      // Agregar actividad
      allItems.add(_buildSimpleActivityCard(activity, i));
    }

    return ReorderableListView(
      padding: const EdgeInsets.all(8),
      onReorder: _reorderActivities,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(animation.value);
            final elevation = lerpDouble(2, 8, t) ?? 2;
            final scale = lerpDouble(1.0, 1.02, t) ?? 1.0;

            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: elevation,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      children: allItems,
    );
  }

  Widget _buildDaySeparator(int day, bool isFirst) {
    return IgnorePointer(
      key: ValueKey('separator_day_$day'),
      child: Container(
        margin: EdgeInsets.only(
          top: isFirst ? 4 : 12,
          bottom: 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.grey[300],
                thickness: 1,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'DÍA $day',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.grey[300],
                thickness: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleActivityCard(Activity activity, int originalIndex) {
    // Calcular el índice correcto en la lista expandida
    int expandedIndex = originalIndex;
    for (int i = 0; i <= originalIndex; i++) {
      final currentActivity = _allActivities[i];
      final isFirstOfDay = i == 0 || currentActivity.day != _allActivities[i - 1].day;
      if (isFirstOfDay) {
        expandedIndex++; // Añadir uno por cada separador antes de esta actividad
      }
    }

    return ReorderableDragStartListener(
      key: ValueKey('activity_${activity.id}_$originalIndex'),
      index: expandedIndex,
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            children: [
              // Indicador de día compacto
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${activity.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Título de la actividad
              Expanded(
                child: Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Handle de drag compacto
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 16,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 16,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
