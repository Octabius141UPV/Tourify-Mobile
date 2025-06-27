import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourify_flutter/screens/guide_detail_screen.dart';
import 'package:tourify_flutter/services/collaborators_service.dart';
import 'package:tourify_flutter/services/auth_service.dart';

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
        // Esperar un momento para asegurar que Firebase Auth esté listo
        await Future.delayed(const Duration(milliseconds: 500));

        // Verificar autenticación
        User? user = FirebaseAuth.instance.currentUser;

        // Si no hay usuario, esperar un poco más y reintentar
        if (user == null) {
          await Future.delayed(const Duration(seconds: 1));
          user = FirebaseAuth.instance.currentUser;
        }

        // Si aún no hay usuario, intentar reautenticar
        if (user == null) {
          final hasValidSession = await AuthService.hasValidSession();
          if (hasValidSession) {
            try {
              final credentials = await AuthService.getSavedCredentials();
              if (credentials['email'] != null &&
                  credentials['password'] != null) {
                final userCredential =
                    await AuthService.signInWithEmailAndPassword(
                  credentials['email']!,
                  credentials['password']!,
                );
                if (userCredential?.user != null) {
                  user = userCredential!.user;
                  print('Usuario reautenticado para acceso a guía');
                }
              }
            } catch (e) {
              print('Error al reautenticar para acceso a guía: $e');
            }
          }
        }

        if (user == null) {
          _showErrorDialog('El link de acceso no es válido o ha expirado');
          return;
        }

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

  // Show retry dialog for temporary errors
  static void _showRetryDialog(String message, String guideId, String token) {
    final context = NavigationService.context;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Servicio no disponible'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reintentar después de un breve delay
              Future.delayed(const Duration(seconds: 1), () {
                handleJoinGuideLink(guideId, token);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
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

  // Handle join guide deep link
  static Future<void> handleJoinGuideLink(String guideId, String token) async {
    final context = NavigationService.context;
    if (context == null) {
      print('Error: NavigationService.context es null');
      return;
    }

    try {
      print('Procesando link de unirse a guía: $guideId con token: $token');

      // Esperar un momento para que Firebase Auth se inicialice completamente
      await Future.delayed(const Duration(milliseconds: 500));

      // Verificar que tenemos un usuario autenticado antes de proceder
      User? user = FirebaseAuth.instance.currentUser;

      // Si no hay usuario, esperar un poco más y reintentar
      if (user == null) {
        await Future.delayed(const Duration(seconds: 1));
        user = FirebaseAuth.instance.currentUser;
      }

      if (user == null) {
        // Verificar si hay credenciales recordadas
        final hasValidSession = await AuthService.hasValidSession();
        final hasStoredCredentials = await AuthService.hasStoredCredentials();

        if (hasValidSession || hasStoredCredentials) {
          // Intentar reautenticar con credenciales guardadas
          try {
            final credentials = await AuthService.getSavedCredentials();
            if (credentials['email'] != null &&
                credentials['password'] != null) {
              final userCredential =
                  await AuthService.signInWithEmailAndPassword(
                credentials['email']!,
                credentials['password']!,
              );
              if (userCredential?.user != null) {
                user = userCredential!.user;
                print(
                    'Usuario reautenticado exitosamente para procesar deep link');
              }
            }
          } catch (e) {
            print('Error al reautenticar usuario: $e');
          }
        }
      }

      if (user == null) {
        _showErrorDialog(
            'Debes iniciar sesión antes de unirte a una guía.\n\nPor favor, inicia sesión e intenta nuevamente.');
        return;
      }

      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Uniéndote a la guía...'),
            ],
          ),
        ),
      );

      final collaboratorsService = CollaboratorsService();

      // Asegurar que el token esté fresco antes de la verificación
      try {
        await user.getIdToken(true); // Forzar refresh del token
        print('Token de autenticación refrescado');
      } catch (tokenError) {
        print('Error al refrescar token: $tokenError');
        // Si hay error al refrescar el token, intentar reautenticar
        if (tokenError.toString().contains('network-request-failed') ||
            tokenError.toString().contains('invalid-user-token')) {
          // Cerrar diálogo de progreso temporal
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }

          _showErrorDialog(
              'Tu sesión ha expirado. Por favor, cierra sesión y vuelve a iniciar sesión para continuar.');
          return;
        }
      }

      bool result = false;
      try {
        result = await collaboratorsService.verifyAccessLink(guideId, token);
      } catch (verifyError) {
        // Si hay error de permisos, intentar refrescar el token una vez más
        if (verifyError.toString().contains('permission-denied') ||
            verifyError.toString().contains('Error interno del servidor')) {
          print(
              'Error de permisos detectado, intentando refrescar token nuevamente...');
          try {
            await user.getIdToken(true);
            await Future.delayed(const Duration(milliseconds: 500));
            result =
                await collaboratorsService.verifyAccessLink(guideId, token);
          } catch (retryError) {
            print('Error en segundo intento: $retryError');
            throw retryError; // Re-lanzar el error para el manejo normal
          }
        } else {
          throw verifyError; // Re-lanzar otros errores
        }
      }

      // Cerrar diálogo de progreso
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (result) {
        // Éxito: navegar a la guía y mostrar mensaje
        showSuccessMessage('¡Te has unido exitosamente a la guía!');

        // Navegar a la guía después de un pequeño retraso
        await Future.delayed(const Duration(milliseconds: 500));
        await navigateToGuide(guideId, guideTitle: 'Guía compartida');
      } else {
        // Error: mostrar mensaje de error
        _showErrorDialog(
            'No se pudo unir a la guía.\n\nPosibles causas:\n• El link ha expirado\n• Ya eres colaborador de esta guía\n• La guía no existe');
      }
    } catch (e) {
      // Cerrar diálogo de progreso si está abierto
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error al procesar link de unirse a guía: $e');

      // Análisis más detallado del error
      String errorMessage = 'Error al procesar el link de invitación.';

      if (e.toString().contains('permission-denied')) {
        errorMessage = '🚫 Error de permisos\n\n'
            'No tienes permisos para acceder a esta guía. Esto puede ocurrir si:\n\n'
            '• Tu sesión ha expirado\n'
            '• El link ha sido revocado\n'
            '• No tienes permisos en esta guía\n\n'
            '💡 Solución: Intenta cerrar sesión y volver a iniciar sesión.';
      } else if (e.toString().contains('Error interno del servidor')) {
        errorMessage = '🔄 Error del servidor\n\n'
            'Hay un problema temporal con el servidor. Esto suele resolverse automáticamente.\n\n'
            '💡 Solución:\n'
            '• Espera 1-2 minutos e inténtalo de nuevo\n'
            '• El link sigue siendo válido\n'
            '• Si persiste, reinicia la aplicación';
      } else if (e.toString().contains('temporalmente no disponible') ||
          e.toString().contains('unavailable') ||
          e.toString().contains('service is currently unavailable')) {
        errorMessage = '🔄 Servicio temporalmente no disponible\n\n'
            'Firebase está experimentando dificultades técnicas. '
            'Este es un problema temporal que se resuelve automáticamente.\n\n'
            '💡 Solución:\n'
            '• Espera 1-2 minutos e inténtalo de nuevo\n'
            '• El link sigue siendo válido\n'
            '• No es necesario que te envíen un nuevo link';
      } else if (e.toString().contains('not-found')) {
        errorMessage =
            '🔍 Guía no encontrada\n\nLa guía no existe o ha sido eliminada.';
      } else if (e.toString().contains('network')) {
        errorMessage = '📡 Error de conexión\n\n'
            'Verifica tu conexión a internet e inténtalo de nuevo.';
      } else {
        errorMessage += '\n\n${e.toString()}';
      }

      // Mostrar diálogo con opción de reintentar para errores temporales
      if (e.toString().contains('temporalmente no disponible') ||
          e.toString().contains('unavailable') ||
          e.toString().contains('service is currently unavailable') ||
          e.toString().contains('Error interno del servidor')) {
        _showRetryDialog(errorMessage, guideId, token);
      } else {
        _showErrorDialog(errorMessage);
      }
    }
  }
}
