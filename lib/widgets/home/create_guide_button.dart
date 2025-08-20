import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tourify_flutter/config/app_colors.dart';
import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:animations/animations.dart';
import 'package:tourify_flutter/widgets/home/create_guide_modal.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';

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
          onTap: () {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              // Buscar el contexto más cercano para mostrar el diálogo
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Inicia sesión o regístrate'),
                  content: Text(
                      'Debes iniciar sesión o registrarte para acceder a esta función.'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed('/login');
                      },
                      child: Text('Iniciar sesión'),
                    ),
                  ],
                ),
              );
            } else {
              action();
            }
          },
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: double.infinity,
            height: 64,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
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
                color: AppColors.primaryLight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: const [
                Icon(Icons.flight_takeoff, color: AppColors.primary, size: 24),
                SizedBox(width: 16),
                Text(
                  'Comenzar mi viaje',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
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
