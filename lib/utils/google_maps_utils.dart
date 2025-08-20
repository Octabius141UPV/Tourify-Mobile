import 'package:flutter/material.dart';

/// Utilidades para manejar errores y experiencia de usuario con Google Maps
class GoogleMapsUtils {
  /// Obtiene un mensaje de error amigable para el usuario
  static String getFriendlyErrorMessage(String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('cookies') ||
        lowerError.contains('authentication') ||
        lowerError.contains('login')) {
      return 'Error de autenticación con Google. Por favor, intenta iniciar sesión nuevamente.';
    }

    if (lowerError.contains('quota') ||
        lowerError.contains('limit') ||
        lowerError.contains('exceeded')) {
      return 'Se ha alcanzado el límite de listas. Por favor, elimina algunas listas existentes en Google Maps.';
    }

    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('timeout')) {
      return 'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.';
    }

    if (lowerError.contains('api key') || lowerError.contains('invalid key')) {
      return 'Error de configuración. Por favor, contacta al soporte técnico.';
    }

    if (lowerError.contains('place') ||
        lowerError.contains('location') ||
        lowerError.contains('not found')) {
      return 'Algunos lugares no se pudieron encontrar en Google Maps. Esto es normal si los nombres no coinciden exactamente.';
    }

    return 'Error inesperado. Por favor, intenta nuevamente.';
  }

  /// Obtiene un icono apropiado para el tipo de error
  static IconData getErrorIcon(String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('cookies') ||
        lowerError.contains('authentication') ||
        lowerError.contains('login')) {
      return Icons.login;
    }

    if (lowerError.contains('quota') || lowerError.contains('limit')) {
      return Icons.storage;
    }

    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return Icons.wifi_off;
    }

    if (lowerError.contains('place') || lowerError.contains('location')) {
      return Icons.location_off;
    }

    return Icons.error;
  }

  /// Obtiene un color apropiado para el tipo de error
  static Color getErrorColor(String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('cookies') ||
        lowerError.contains('authentication') ||
        lowerError.contains('login')) {
      return Colors.orange;
    }

    if (lowerError.contains('quota') || lowerError.contains('limit')) {
      return Colors.purple;
    }

    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return Colors.blue;
    }

    if (lowerError.contains('place') || lowerError.contains('location')) {
      return Colors.amber;
    }

    return Colors.red;
  }

  /// Muestra un SnackBar con información sobre el error
  static void showErrorSnackBar(BuildContext context, String error) {
    final friendlyMessage = getFriendlyErrorMessage(error);
    final icon = getErrorIcon(error);
    final color = getErrorColor(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                friendlyMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Entendido',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Muestra un SnackBar de éxito
  static void showSuccessSnackBar(BuildContext context, String message,
      {int placesAdded = 0}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  if (placesAdded > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$placesAdded lugares añadidos',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Muestra un diálogo de confirmación para reintentar
  static Future<bool> showRetryDialog(BuildContext context, String error) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(getErrorIcon(error), color: getErrorColor(error)),
            const SizedBox(width: 8),
            const Text('Error de Exportación'),
          ],
        ),
        content: Text(getFriendlyErrorMessage(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }
}
