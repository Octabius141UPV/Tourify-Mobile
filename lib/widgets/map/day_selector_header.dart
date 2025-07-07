import 'package:flutter/material.dart';
import '../../utils/activity_utils.dart';

class DaySelectorHeader extends StatelessWidget {
  final List<int> availableDays;
  final Set<int> selectedDays;
  final ValueChanged<Set<int>> onDaysSelected;

  const DaySelectorHeader({
    super.key,
    required this.availableDays,
    required this.selectedDays,
    required this.onDaysSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: availableDays.map((day) {
            final selected = selectedDays.contains(day);
            final selectedColor =
                const Color(0xFF0062FF); // Azul para seleccionados
            final unselectedColor =
                Colors.grey.shade400; // Grisáceo para no seleccionados

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: FilterChip(
                label: Text(
                  'Día $day',
                  style: TextStyle(
                    color: selected ? Colors.white : unselectedColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                selected: selected,
                selectedColor: selectedColor,
                backgroundColor: selected
                    ? selectedColor.withOpacity(0.1)
                    : unselectedColor.withOpacity(0.1),
                checkmarkColor: Colors.white,
                onSelected: (val) {
                  final newSelection = Set<int>.from(selectedDays);
                  if (val) {
                    newSelection.add(day);
                  } else {
                    newSelection.remove(day);
                  }
                  onDaysSelected(newSelection);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: selected ? selectedColor : unselectedColor,
                    width: selected ? 0 : 1.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
