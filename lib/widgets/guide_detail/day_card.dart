import 'package:flutter/material.dart';

class DayCard extends StatelessWidget {
  final int dayNumber;
  final int activityCount;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;
  final List<Widget> activityTiles;

  const DayCard({
    super.key,
    required this.dayNumber,
    required this.activityCount,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.activityTiles,
  });

  @override
  Widget build(BuildContext context) {
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
        initiallyExpanded: isExpanded,
        key: ValueKey('day_$dayNumber'),
        onExpansionChanged: (expanded) => onExpansionChanged(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Día $dayNumber',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text('$activityCount actividades · horario',
            style: TextStyle(color: Colors.grey[600])),
        children: activityTiles.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay actividades para este día'),
                )
              ]
            : activityTiles,
      ),
    );
  }
}
