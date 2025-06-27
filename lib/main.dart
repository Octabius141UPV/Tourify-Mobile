import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:clarity_flutter/clarity_flutter.dart';
// import 'package:flutter_smartlook/flutter_smartlook.dart';  // Temporalmente comentado
import 'config/firebase_config.dart';
import 'config/app_colors.dart';
import 'services/navigation_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_guides_screen.dart';
import 'screens/guide_detail_screen.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:flutter/rendering.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Cargar variables de entorno
    await dotenv.load(fileName: ".env");

    // Inicializar Firebase
    final firebaseOptions = await FirebaseConfig.firebaseOptions;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: firebaseOptions);
      debugPrint('Firebase inicializado correctamente');
    }

    // Configurar Microsoft Clarity
    final clarityProjectId = dotenv.env['CLARITY_PROJECT_ID'];
    if (clarityProjectId != null &&
        clarityProjectId.isNotEmpty &&
        clarityProjectId != 'tu_clarity_project_id_aqui') {
      final config = ClarityConfig(
        projectId: clarityProjectId,
        logLevel: LogLevel.Info,
      );

      runApp(ClarityWidget(
        app: const MyApp(),
        clarityConfig: config,
      ));
      debugPrint(
          'Microsoft Clarity configurado correctamente con ID: $clarityProjectId');
    } else {
      debugPrint(
          'ID de proyecto de Clarity no configurado, ejecutando sin Clarity');
      runApp(const MyApp());
    }
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
  static bool _pendingDeepLink = false;
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

      if (uri.scheme == 'tourify') {
        // Marcar que hay un deep link pendiente
        _pendingDeepLink = true;

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
            NavigationService.handleJoinGuideLink(guideId, token);
          } else {
            print('Error: guideId o token faltante en el deep link');
          }
        }

        // Después de procesar el deep link, limpiar la bandera
        Future.delayed(const Duration(seconds: 2), () {
          _pendingDeepLink = false;
        });
      }
    } catch (e) {
      print('Error al procesar link: $e');
      _pendingDeepLink = false;
    }
  }

  // Método para obtener el estado de deep link pendiente
  static bool get hasPendingDeepLink => _pendingDeepLink;

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
      home: const AuthChecker(),
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
            page = const AuthChecker();
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

// Widget para verificar autenticación
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final shouldRemember = await AuthService.shouldRememberUser();

      // Si hay un deep link pendiente, dar más tiempo para que se procese
      if (_MyAppState.hasPendingDeepLink) {
        print(
            'Deep link pendiente detectado, esperando antes de verificar auth...');
        await Future.delayed(const Duration(seconds: 2));
      }

      if (mounted) {
        if (user != null && shouldRemember) {
          // Usuario logueado y quiere recordar sesión
          Navigator.pushReplacementNamed(context, '/home');
        } else if (user != null && !_MyAppState.hasPendingDeepLink) {
          // Hay usuario pero no quiere recordar sesión Y no hay deep link pendiente
          if (!shouldRemember) {
            // Cerrar sesión si no quiere recordar
            await AuthService.signOut();
          }
          Navigator.pushReplacementNamed(context, '/login');
        } else if (user == null && !_MyAppState.hasPendingDeepLink) {
          // No hay usuario y no hay deep link pendiente
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          // Hay deep link pendiente, esperar un poco más
          if (_MyAppState.hasPendingDeepLink) {
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              _checkAuthStatus(); // Reintentar
            }
          }
        }
      }
    } catch (e) {
      print('Error verificando estado de autenticación: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Widget transparente para que se vea el native splash
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
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
