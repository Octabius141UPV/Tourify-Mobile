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
      final activity = _allActivities.removeAt(oldIndex);
      _allActivities.insert(newIndex, activity);

      // Recalcular días basado en la nueva posición
      _reassignDaysAndOrders();
    });
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
    final totalActivities = _allActivities.length;
    final totalDays = originalDays.length;
    final activitiesPerDay = (totalActivities / totalDays).ceil();

    for (int i = 0; i < _allActivities.length; i++) {
      final dayIndex = (i / activitiesPerDay).floor().clamp(0, totalDays - 1);
      final targetDay = originalDays[dayIndex];
      final orderInDay = i % activitiesPerDay;

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
    _workingDayActivities.clear();

    Map<int, List<Activity>> dayGroups = {};
    for (final activity in _allActivities) {
      final dayNum = activity.day;
      if (!dayGroups.containsKey(dayNum)) {
        dayGroups[dayNum] = [];
      }
      dayGroups[dayNum]!.add(activity);
    }

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
          : _buildSimpleListView(),
    );
  }

  Widget _buildSimpleListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _allActivities.length,
      itemBuilder: (context, index) {
        final activity = _allActivities[index];
        final isFirstOfDay =
            index == 0 || activity.day != _allActivities[index - 1].day;

        return Column(
          children: [
            // Separador de día fijo (no draggable)
            if (isFirstOfDay)
              Container(
                margin: EdgeInsets.only(
                  top: index == 0 ? 4 : 12,
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
                        'DÍA ${activity.day}',
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

            // Tarjeta de actividad con drag personalizado
            _buildDraggableActivityCard(activity, index),
          ],
        );
      },
    );
  }

  Widget _buildDraggableActivityCard(Activity activity, int index) {
    return Draggable<int>(
      data: index,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Transform.scale(
          scale: 1.02,
          child: _buildActivityCard(activity, true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildActivityCard(activity, false),
      ),
      child: DragTarget<int>(
        onAcceptWithDetails: (details) {
          final draggedIndex = details.data;
          if (draggedIndex != index) {
            _reorderActivities(draggedIndex, index);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return _buildActivityCard(activity, false);
        },
      ),
    );
  }

  Widget _buildActivityCard(Activity activity, bool isDragging) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: isDragging ? 8 : 2,
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
    );
  }
}
