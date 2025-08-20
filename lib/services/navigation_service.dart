import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tourify_flutter/screens/guides/guide_detail_screen.dart';
import 'dart:convert';
import 'package:tourify_flutter/services/collaborators_service.dart';
import 'package:tourify_flutter/services/auth_service.dart';
import 'package:tourify_flutter/screens/onboarding/welcome_screen.dart';
import 'package:tourify_flutter/services/analytics_service.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  // Deep link pendiente (para unirse a guía tras registro/login)
  static Map<String, String>? _pendingJoin; // { guideId, token }
  static bool _isHandlingJoin = false;

  static void setPendingJoin({required String guideId, required String token}) {
    _pendingJoin = {'guideId': guideId, 'token': token};
  }

  static bool get hasPendingJoin => _pendingJoin != null;

  static Map<String, String>? takePendingJoin() {
    final pending = _pendingJoin;
    _pendingJoin = null;
    return pending;
  }

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

  // Navegar a Welcome para registro/login desde deep link
  static Future<void> navigateToWelcome({Object? arguments}) async {
    final context = NavigationService.context;
    if (context == null) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: '/welcome'),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WelcomeScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // Navegar a vista previa de guía (solo lectura) usando token
  static Future<void> navigateToGuidePreview({
    required String guideId,
    required String token,
    String? guideTitle,
  }) async {
    final context = NavigationService.context;
    if (context == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          settings: RouteSettings(
            name: '/guide-preview',
            arguments: {
              'guideId': guideId,
              'guideTitle': guideTitle ?? 'Guía',
              'isPreview': true,
              'previewToken': token,
            },
          ),
          pageBuilder: (context, animation, secondaryAnimation) =>
              GuideDetailScreen(
            guideId: guideId,
            guideTitle: guideTitle ?? 'Guía',
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    });
  }

  // Navigate to guide details
  static Future<void> navigateToGuide(String guideId,
      {String? guideTitle, String? accessToken}) async {
    final context = NavigationService.context;
    if (context == null) return;

    try {
      // Si hay un token de acceso, verificar y procesar
      if (accessToken != null) {
        // Fuerza previsualización en tokens de debug/mock para pruebas
        final tokenLc = accessToken.toLowerCase();
        if (tokenLc.startsWith('debug') || tokenLc.startsWith('mock')) {
          await navigateToGuidePreview(
            guideId: guideId,
            token: accessToken,
            guideTitle: guideTitle,
          );
          return;
        }
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
          // Mostrar vista previa primero
          await navigateToGuidePreview(
            guideId: guideId,
            token: accessToken,
            guideTitle: guideTitle,
          );
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recordGuideOpened(guideId);
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            settings: const RouteSettings(name: '/guide'),
            pageBuilder: (context, animation, secondaryAnimation) =>
                GuideDetailScreen(
              guideId: guideId,
              guideTitle: guideTitle ?? 'Mi Guía de Viaje',
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      });
    } catch (e) {
      print('Error navigating to guide: $e');
      _showErrorDialog('Error al abrir la guía');
    }
  }

  // Registrar última apertura de guía
  static Future<void> _recordGuideOpened(String guideId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('recentlyOpened')
          .doc(guideId)
          .set({
        'guideId': guideId,
        'openedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // Show error dialog
  static void _showErrorDialog(String message) {
    final context = NavigationService.context;
    if (context == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    });
  }

  // Show retry dialog for temporary errors
  static void _showRetryDialog(String message, String guideId, String token) {
    final context = NavigationService.context;
    if (context == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    });
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
      if (_isHandlingJoin) {
        print('⚠️ Ya se está procesando un deeplink, se ignora el duplicado.');
        return;
      }
      _isHandlingJoin = true;
      print('Procesando link de unirse a guía: $guideId con token: $token');

      // Tokens debug/mock: si no hay usuario -> previsualizar; si hay usuario -> mock join
      final tokenLc = token.toLowerCase();
      if (tokenLc.startsWith('debug') || tokenLc.startsWith('mock')) {
        final current = FirebaseAuth.instance.currentUser;
        if (current == null) {
          await navigateToGuidePreview(
            guideId: guideId,
            token: token,
            guideTitle: 'Guía compartida',
          );
          return;
        }
        // MOCK JOIN con usuario autenticado
        try {
          final firestore = FirebaseFirestore.instance;
          final guides = firestore.collection('guides');
          final users = firestore.collection('users');

          final guideRef = guides.doc(guideId);
          final guideSnap = await guideRef.get();
          if (!guideSnap.exists) {
            await guideRef.set({
              'title': 'Guía compartida (debug)',
              'city': 'Roma',
              'startDate': DateTime.now(),
              'endDate': DateTime.now().add(const Duration(days: 2)),
              'isPublic': false,
              'totalDays': 2,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'collaborators': <String>[],
            });
          }

          await users
              .doc(current.uid)
              .collection('sharedWithMe')
              .doc(guideId)
              .set({
            'guideId': guideId,
            'role': 'viewer',
            'sharedAt': FieldValue.serverTimestamp(),
            'sharedBy': 'Mock Debug',
          }, SetOptions(merge: true));

          // Añadir entrada en subcolección collaborators de la guía
          await guideRef.collection('collaborators').doc(current.uid).set({
            'userId': current.uid,
            'role': 'viewer',
            'addedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Asegurar que el array collaborators del documento principal contiene al usuario
          await guideRef.update({
            'collaborators': FieldValue.arrayUnion([current.uid]),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          showSuccessMessage('¡Guía de prueba guardada en Compartidas!');
        } catch (e) {
          // Fallback: llamar al endpoint admin del servidor
          try {
            final baseUrl =
                dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
            final uriPrimary = Uri.parse('$baseUrl/collaborators/admin/add');
            final bodyJson = jsonEncode({
              'guideId': guideId,
              'userId': current.uid,
              'role': 'viewer',
            });
            http.Response resp = await http.post(
              uriPrimary,
              headers: {'Content-Type': 'application/json'},
              body: bodyJson,
            );

            if (resp.statusCode == 200) {
              showSuccessMessage('¡La guía compartida se ha guardado!');
            } else {
              final body = resp.body.isNotEmpty ? resp.body : '(sin cuerpo)';
              _showErrorDialog(
                  'No se pudo guardar la guía (admin): ${resp.statusCode}\nHosts probados: $baseUrl, localhost:4000, 127.0.0.1:4000\n$body');
            }
          } catch (e2) {
            _showErrorDialog('No se pudo guardar la guía: $e2');
          }
        }
        return;
      }

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
        // Mostrar vista previa primero
        await navigateToGuidePreview(
          guideId: guideId,
          token: token,
          guideTitle: 'Guía compartida',
        );
        return;
      }

      // Mostrar diálogo de progreso
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
      });

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
        AnalyticsService.trackEvent('join_completed', parameters: {
          'guide_id': guideId,
        });
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
    } finally {
      _isHandlingJoin = false;
    }
  }

  // Procesa join pendiente tras autenticación
  static Future<void> processPendingJoinIfAny() async {
    final pending = takePendingJoin();
    if (pending == null) return;
    final guideId = pending['guideId']!;
    final token = pending['token']!;
    await handleJoinGuideLink(guideId, token);
  }
}
