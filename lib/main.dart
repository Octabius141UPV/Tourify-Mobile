import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:clarity_flutter/clarity_flutter.dart' as clarity;
// import 'package:flutter_smartlook/flutter_smartlook.dart';  // Temporalmente comentado
import 'config/firebase_config.dart';

import 'config/app_colors.dart';
import 'services/navigation_service.dart';
import 'services/analytics_service.dart';
import 'services/navigation_observer.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/profile_screen.dart';
import 'screens/guides/my_guides_screen.dart';
import 'screens/guides/guide_detail_screen.dart';
import 'screens/onboarding/interactive_onboarding_screen.dart';
import 'screens/main/app_wrapper.dart';
// import 'utils/onboarding_debug.dart'; // Para testing del onboarding
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:flutter/rendering.dart';
import 'services/auth_service.dart'; // Added import for AuthService
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Cargar variables de entorno
    await dotenv.load(fileName: ".env");
    print('API_BASE_URL al iniciar:  [32m [1m' +
        (dotenv.env['API_BASE_URL'] ?? 'NO DEFINIDO') +
        '\u001b[0m'); // <-- Añadido para debug visual

    // Inicializar Firebase
    final firebaseOptions = await FirebaseConfig.firebaseOptions;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: firebaseOptions);
      debugPrint('Firebase inicializado correctamente');
    }

    // Inicializar servicio de analytics
    await AnalyticsService.initialize();

    // 🚀 DESARROLLO: Reseteo de onboarding deshabilitado para no forzar flujos
    // await devResetOnboarding();

    // Obtener Project ID de Clarity (si existe)
    final clarityProjectId = dotenv.env['CLARITY_PROJECT_ID'] ?? '';

    Widget rootApp;

    if (clarityProjectId.isNotEmpty &&
        clarityProjectId != 'tu_clarity_project_id_aqui') {
      // Usar ClarityWidget para inicializar y envolver la app
      rootApp = clarity.ClarityWidget(
        app: const MyApp(),
        clarityConfig: clarity.ClarityConfig(
          projectId: clarityProjectId,
          logLevel: clarity.LogLevel.None, // Cambia a verbose para debug
        ),
      );
      debugPrint('✅ ClarityWidget configurado con ID $clarityProjectId');
    } else {
      // Ejecutar la app sin Clarity si no hay Project ID
      debugPrint(
          'ℹ️ CLARITY_PROJECT_ID no establecido; ejecutando sin Clarity');
      rootApp = const MyApp();
    }

    runApp(rootApp);
  } catch (e, stackTrace) {
    debugPrint('Error durante la inicialización: $e');
    debugPrint('Stack trace: $stackTrace');
    // En caso de error, ejecutar la app sin Clarity
    runApp(const MyApp());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _linkSubscription;
  late final AppLinks _appLinks;
  // static bool _pendingDeepLink = false;
  // final Smartlook smartlook = Smartlook.instance;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();
    // Escuchar links en segundo plano
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        _handleIncomingLink(uri?.toString());
      },
      onError: (err) {
        print('Error al escuchar links: $err');
      },
    );

    // Manejar link inicial si la app se abrió desde un link
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        _handleIncomingLink(initialUri.toString());
      }
    } catch (e) {
      print('Error al obtener link inicial: $e');
    }
  }

  void _handleIncomingLink(String? link) {
    if (link == null) return;

    try {
      final uri = Uri.parse(link);
      print('Deep link recibido: $link');

      // Verificar si es un deep link de Firebase Auth
      if (AuthService.isFirebaseAuthDeepLink(link)) {
        print('🔗 Deep link de Firebase Auth detectado');

        // Verificar si estamos en onboarding usando el contexto
        final navigator = NavigationService.navigatorKey.currentState;
        final isInOnboarding = navigator?.context.mounted == true &&
            (navigator != null
                ? ModalRoute.of(navigator.context)
                        ?.settings
                        .name
                        ?.contains('onboarding') ==
                    true
                : false);

        print('🔍 Verificando contexto del deep link:');
        print('  - Navigator null: ${navigator == null}');
        print('  - Context mounted: ${navigator?.context.mounted}');
        print(
            '  - Current route: ${navigator != null ? ModalRoute.of(navigator.context)?.settings.name : 'null'}');
        print('  - Is in onboarding: $isInOnboarding');
        print(
            '  - Callback registrado: ${AuthService.isCaptchaCallbackRegistered}');

        // SIEMPRE preservar el onboarding si hay callback registrado
        if (AuthService.isCaptchaCallbackRegistered) {
          print('📱 Callback detectado, preservando onboarding');
          AuthService.handleFirebaseAuthDeepLink(link,
              preserveOnboarding: true);
        } else if (isInOnboarding) {
          print(
              '📱 Detectado deep link durante onboarding, preservando contexto');
          AuthService.handleFirebaseAuthDeepLink(link,
              preserveOnboarding: true);
        } else {
          print('🏠 Deep link fuera del onboarding, navegando normalmente');
          AuthService.handleFirebaseAuthDeepLink(link);
        }
        return;
      } else {
        print('❌ Deep link NO detectado como Firebase Auth');
      }

      if (uri.scheme == 'tourify') {
        // Marcar que hay un deep link pendiente
        // _pendingDeepLink = true;

        if (uri.host == 'guide') {
          // Link para ver guía: tourify://guide/{guideId}?token={token}
          final guideId = uri.pathSegments.last;
          final token = uri.queryParameters['token'];
          NavigationService.navigateToGuide(guideId, accessToken: token);
        } else if (uri.host == 'join-guide') {
          // Link para unirse a guía: tourify://join-guide/{guideId}?token={token}
          final guideId =
              uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
          final token = uri.queryParameters['token'];

          if (guideId.isNotEmpty && token != null) {
            // Registrar join pendiente para cubrir casos en que el Navigator aún no está listo
            NavigationService.setPendingJoin(guideId: guideId, token: token);

            // Si NO hay usuario autenticado, navegar inmediatamente a vista previa
            final current = FirebaseAuth.instance.currentUser;
            if (current == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                NavigationService.navigateToGuidePreview(
                  guideId: guideId,
                  token: token,
                  guideTitle: 'Guía compartida',
                );
              });
            } else {
              // Si hay usuario, intentar procesar el join completo
              NavigationService.handleJoinGuideLink(guideId, token);
            }
          } else {
            print('Error: guideId o token faltante en el deep link');
          }
        }

        // Después de procesar el deep link, limpiar la bandera
        Future.delayed(const Duration(seconds: 2), () {
          // _pendingDeepLink = false;
        });
      }
    } catch (e) {
      print('Error al procesar link: $e');
      // _pendingDeepLink = false;
    }
  }

  // Método para obtener el estado de deep link pendiente
  // static bool get hasPendingDeepLink => _pendingDeepLink;

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tourify',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      navigatorObservers: [
        AnalyticsNavigatorObserver(), // Tracking automático de navegación
        // ClarityNavigatorObserver eliminado: ahora AnalyticsService maneja screen names
        if (AnalyticsService.observer != null)
          AnalyticsService.observer!, // Firebase Analytics observer
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        // Configurar transiciones personalizadas para eliminar el slide
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoTransitionPageTransitionsBuilder(),
            TargetPlatform.iOS: NoTransitionPageTransitionsBuilder(),
            TargetPlatform.macOS: NoTransitionPageTransitionsBuilder(),
            TargetPlatform.windows: NoTransitionPageTransitionsBuilder(),
            TargetPlatform.linux: NoTransitionPageTransitionsBuilder(),
          },
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      home: const AppWrapper(),
      onGenerateRoute: (settings) {
        // Configurar rutas con transiciones personalizadas
        Widget page;
        switch (settings.name) {
          case '/login':
            page = const LoginScreen();
            break;
          case '/register':
            page = const RegisterScreen();
            break;
          case '/verify-email':
            page = const VerifyEmailScreen();
            break;
          case '/forgot-password':
            page = const ForgotPasswordScreen();
            break;
          case '/onboarding':
            page = const InteractiveOnboardingScreen();
            break;
          case '/home':
            page = const HomeScreen();
            break;
          case '/profile':
            page = const ProfileScreen();
            break;
          case '/my-guides':
            page = const MyGuidesScreen();
            break;
          case '/guide-detail':
            final args = settings.arguments as Map<String, dynamic>?;
            final guideId = args?['guideId'] ?? '';
            final guideTitle = args?['guideTitle'] ?? 'Guía';
            page = GuideDetailScreen(guideId: guideId, guideTitle: guideTitle);
            break;
          default:
            page = const HomeScreen();
        }

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      },
    );
  }
}

// Clase personalizada para eliminar transiciones
class NoTransitionPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Retornar directamente el child sin animación
    return child;
  }
}
