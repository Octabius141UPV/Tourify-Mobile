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
  late List<DayActivities> _workingDayActivities;
  Map<int, List<Activity>> _dayActivitiesMap = {};
  int? _draggedDay;
  int? _draggedActivityIndex;

  @override
  void initState() {
    super.initState();
    _workingDayActivities = widget.dayActivities
        .map((day) => DayActivities(
              dayNumber: day.dayNumber,
              activities: List.from(day.activities),
            ))
        .toList();

    // Crear un mapa de actividades por día para facilitar el manejo
    for (final day in _workingDayActivities) {
      _dayActivitiesMap[day.dayNumber] = List.from(day.activities);
    }
  }

  void _onDragStarted(int day, int activityIndex) {
    setState(() {
      _draggedDay = day;
      _draggedActivityIndex = activityIndex;
    });
  }

  void _onDragEnded() {
    setState(() {
      _draggedDay = null;
      _draggedActivityIndex = null;
    });
  }

  void _onActivityDropped(int targetDay, int targetIndex) {
    if (_draggedDay == null || _draggedActivityIndex == null) return;

    setState(() {
      // Obtener la actividad que se está moviendo
      final activity =
          _dayActivitiesMap[_draggedDay!]!.removeAt(_draggedActivityIndex!);

      int insertIndex = targetIndex;
      // Si el día es el mismo y el índice de destino es mayor que el de origen, hay que restar 1
      if (targetDay == _draggedDay && targetIndex > _draggedActivityIndex!) {
        insertIndex--;
      }

      // Si el día de destino es diferente, crear una nueva actividad con el día actualizado
      if (targetDay != _draggedDay) {
        final updatedActivity = Activity(
          id: activity.id,
          title: activity.title,
          description: activity.description,
          duration: activity.duration,
          day: targetDay,
          order: activity.order,
          images: activity.images,
          city: activity.city,
          category: activity.category,
          likes: activity.likes,
          startTime: activity.startTime,
          endTime: activity.endTime,
          price: activity.price,
        );
        _dayActivitiesMap[targetDay]!.insert(insertIndex, updatedActivity);
      } else {
        _dayActivitiesMap[targetDay]!.insert(insertIndex, activity);
      }

      // Actualizar el orden de todas las actividades en ambos días
      _updateActivitiesOrder(_draggedDay!);
      if (targetDay != _draggedDay) {
        _updateActivitiesOrder(targetDay);
      }
    });
  }

  void _updateActivitiesOrder(int day) {
    final activities = _dayActivitiesMap[day]!;
    for (int i = 0; i < activities.length; i++) {
      activities[i] = Activity(
        id: activities[i].id,
        title: activities[i].title,
        description: activities[i].description,
        duration: activities[i].duration,
        day: day,
        order: i,
        images: activities[i].images,
        city: activities[i].city,
        category: activities[i].category,
        likes: activities[i].likes,
        startTime: activities[i].startTime,
        endTime: activities[i].endTime,
        price: activities[i].price,
      );
    }
  }

  void _saveChanges() {
    // Convertir el mapa de vuelta a la lista de DayActivities
    _workingDayActivities = _dayActivitiesMap.entries
        .map((entry) => DayActivities(
              dayNumber: entry.key,
              activities: entry.value,
            ))
        .toList()
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    widget.onReorganize(_workingDayActivities);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Actividades reorganizadas'),
        backgroundColor: Colors.green,
      ),
    );
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
            onPressed: _saveChanges,
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
      body: _workingDayActivities.isEmpty
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
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _workingDayActivities.length,
              itemBuilder: (context, dayIndex) {
                final day = _workingDayActivities[dayIndex];
                final activities = _dayActivitiesMap[day.dayNumber] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Día ${day.dayNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    ...activities.asMap().entries.expand((entry) {
                      final index = entry.key;
                      final activity = entry.value;
                      return [
                        DragTarget<Activity>(
                          onWillAccept: (data) {
                            print('DragTarget onWillAccept: $data');
                            return true;
                          },
                          onAccept: (data) {
                            _onActivityDropped(day.dayNumber, index);
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isHovering = candidateData != null &&
                                candidateData.isNotEmpty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              height: isHovering ? 16 : 8,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: isHovering
                                    ? Colors.blueAccent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          },
                        ),
                        LongPressDraggable<Activity>(
                          data: activity,
                          feedback: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: MediaQuery.of(context).size.width - 32,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 2,
                                ),
                              ),
                              child: _buildActivityContent(activity),
                            ),
                          ),
                          childWhenDragging: Container(
                            height: 60,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                          ),
                          onDragStarted: () =>
                              _onDragStarted(day.dayNumber, index),
                          onDragEnd: (_) => _onDragEnded(),
                          child: Container(
                            height: 60,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _buildActivityContent(activity),
                          ),
                        ),
                      ];
                    }).toList()
                      ..add(
                        DragTarget<Activity>(
                          onWillAccept: (data) {
                            print('DragTarget (final) onWillAccept: $data');
                            return true;
                          },
                          onAccept: (data) {
                            _onActivityDropped(
                                day.dayNumber, activities.length);
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isHovering = candidateData != null &&
                                candidateData.isNotEmpty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              height: isHovering ? 16 : 8,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: isHovering
                                    ? Colors.blueAccent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildActivityContent(Activity activity) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.drag_indicator,
                color: Colors.blue.shade700,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activity.city?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    activity.city ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (activity.duration != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${activity.duration} min',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
