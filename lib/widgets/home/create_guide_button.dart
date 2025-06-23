import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'create_guide_modal.dart';
import 'dart:ui';

class CreateGuideButton extends StatelessWidget {
  final VoidCallback?
      onTap; // Ya no se usará directamente, pero se mantiene por compatibilidad

  const CreateGuideButton({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 500),
      closedElevation: 8,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      openShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      closedBuilder: (context, action) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(
                width: 2,
                style: BorderStyle.solid,
                color: const Color(0xFF60A5FA),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: const [
                Icon(Icons.flight_takeoff, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 12),
                Text(
                  'Comenzar mi viaje',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      openBuilder: (context, action) => Stack(
        children: [
          // Fondo blanco difuminado
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ),
          const CreateGuideModal(),
        ],
      ),
    );
  }
}
