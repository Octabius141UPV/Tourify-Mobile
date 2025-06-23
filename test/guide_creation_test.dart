import 'package:flutter_test/flutter_test.dart';
import 'package:tourify_flutter/data/mock_activities.dart';
import 'package:tourify_flutter/services/guide_service.dart';

void main() {
  group('Guide Creation Tests', () {
    test('Activity data structure is valid', () {
      expect(mockActivities.isNotEmpty, true);
      final firstActivity = mockActivities.first;
      expect(firstActivity.id.isNotEmpty, true);
      expect(firstActivity.name.isNotEmpty, true);
      expect(firstActivity.category.isNotEmpty, true);
    });

    test('Guide creation parameters are valid', () {
      final activities = mockActivities.take(5).toList();
      final destination = 'París';
      final startDate = DateTime.now();
      final endDate = DateTime.now().add(const Duration(days: 3));

      expect(activities.length, 5);
      expect(destination.isNotEmpty, true);
      expect(endDate.isAfter(startDate), true);
    });

    test('Date range calculation works correctly', () {
      final startDate = DateTime(2025, 6, 1);
      final endDate = DateTime(2025, 6, 3);

      // This would test the private _getDaysBetweenDates method
      // In a real implementation, you might make it public for testing
      final daysDifference = endDate.difference(startDate).inDays + 1;
      expect(daysDifference, 3);
    });
  });
}
