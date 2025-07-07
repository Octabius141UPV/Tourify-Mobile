import 'package:flutter/material.dart';
import '../../data/activity.dart';
import '../../services/map/places_service.dart';
import '../../utils/activity_utils.dart';

class ActivityList extends StatelessWidget {
  final List<Activity> activities;
  final int selectedIndex;
  final ValueChanged<int> onActivityTap;
  final List<PlaceInfo?>? placesInfo;

  const ActivityList({
    super.key,
    required this.activities,
    required this.selectedIndex,
    required this.onActivityTap,
    this.placesInfo,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        final isSelected = index == selectedIndex;
        final placeInfo = (placesInfo != null && index < placesInfo!.length)
            ? placesInfo![index]
            : null;
        return GestureDetector(
          onTap: () => onActivityTap(index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
              border: isSelected
                  ? Border.all(color: Color(0xFF0062FF), width: 2)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Chip del día
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: DayColors.getColorForDay(activity.day),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Día ${activity.day}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activity.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color(0xFF0062FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (placeInfo != null && placeInfo.rating != null)
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                placeInfo.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              if (placeInfo.address != null) ...[
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    placeInfo.address!,
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        if (placeInfo != null && placeInfo.review != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '"${placeInfo.review!.length > 80 ? placeInfo.review!.substring(0, 80) + '...' : placeInfo.review!}"',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (activity.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              activity.description.length > 80
                                  ? activity.description.substring(0, 80) +
                                      '...'
                                  : activity.description,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Text(
                          '${activity.duration}min',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
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
      },
    );
  }
}
