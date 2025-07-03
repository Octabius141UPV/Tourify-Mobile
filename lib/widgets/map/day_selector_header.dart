import 'package:flutter/material.dart';

class DaySelectorHeader extends StatelessWidget {
  final List<int> availableDays;
  final int selectedDay;
  final ValueChanged<int> onDaySelected;

  const DaySelectorHeader({
    super.key,
    required this.availableDays,
    required this.selectedDay,
    required this.onDaySelected,
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
            final selected = day == selectedDay;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(
                  'Día $day',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                selected: selected,
                selectedColor: const Color(0xFF0062FF),
                backgroundColor: Colors.grey[200],
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                onSelected: (val) {
                  if (val) onDaySelected(day);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
} 