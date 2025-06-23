import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF2563EB),
      unselectedItemColor: Colors.grey,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(
            Symbols.home_rounded,
            weight: 600,
          ),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Symbols.card_travel_rounded,
            weight: 600,
          ),
          label: 'Mis viajes',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Symbols.person_rounded,
            weight: 600,
          ),
          label: 'Perfil',
        ),
      ],
    );
  }
}
