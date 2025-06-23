import 'package:flutter/material.dart';
import 'package:tourify_flutter/screens/guide_detail_screen.dart';
import 'package:tourify_flutter/services/collaborators_service.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  // Método para navegar sin transiciones
  static Future<T?> navigateWithoutTransition<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    final context = NavigationService.context;
    if (context == null) return Future.value(null);

    return Navigator.of(context).pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  // Método para navegar a pantallas principales sin transiciones
  static void navigateToMainScreen(String routeName) {
    final context = NavigationService.context;
    if (context == null) return;

    Navigator.of(context).pushReplacementNamed(routeName);
  }

  // Navigate to guide details
  static Future<void> navigateToGuide(String guideId,
      {String? guideTitle, String? accessToken}) async {
    final context = NavigationService.context;
    if (context == null) return;

    try {
      // Si hay un token de acceso, verificar y procesar
      if (accessToken != null) {
        final collaboratorsService = CollaboratorsService();
        final result =
            await collaboratorsService.verifyAccessLink(guideId, accessToken);

        if (result == false) {
          _showErrorDialog('El link de acceso no es válido o ha expirado');
          return;
        }
      }

      // Navigate directly to the GuideDetailScreen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              GuideDetailScreen(
            guideId: guideId,
            guideTitle: guideTitle ?? 'Mi Guía de Viaje',
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } catch (e) {
      print('Error navigating to guide: $e');
      _showErrorDialog('Error al abrir la guía');
    }
  }

  // Show error dialog
  static void _showErrorDialog(String message) {
    final context = NavigationService.context;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Navigate back to home
  static void navigateToHome() {
    final context = NavigationService.context;
    if (context == null) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Show success message
  static void showSuccessMessage(String message) {
    final context = NavigationService.context;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Show error message
  static void showErrorMessage(String message) {
    final context = NavigationService.context;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
