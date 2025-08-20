import 'package:flutter/material.dart';
import 'package:tourify_flutter/services/version_service.dart';
import 'package:tourify_flutter/screens/onboarding/welcome_screen.dart';
import 'package:tourify_flutter/screens/main/home_screen.dart';
import 'package:tourify_flutter/services/auth_service.dart';
import 'package:tourify_flutter/screens/other/update_screen.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:tourify_flutter/services/onboarding_service.dart';
import 'package:tourify_flutter/screens/onboarding/interactive_onboarding_screen.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isLoading = true;
  bool _shouldShowUpdate = false;
  VersionCheckResult? _versionResult;
  bool _processingPendingJoin = false;
  bool _redirectedToOnboarding = false;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Verificar si necesita actualización
      final versionResult = await VersionService().checkVersion();

      if (versionResult.isForced) {
        // Solo mostrar pantalla completa si es actualización FORZADA (< mínima)
        setState(() {
          _shouldShowUpdate = true;
          _versionResult = versionResult;
          _isLoading = false;
        });
        return;
      }

      // No hay actualización forzada: continuar a Welcome
      final hasCompleted = await OnboardingService.hasCompletedOnboarding();
      setState(() {
        _isLoading = false;
        _hasCompletedOnboarding = hasCompleted;
      });

      print('App initialization: needsUpdate = ${versionResult.needsUpdate}');
    } catch (e) {
      print('Error initializing app: $e');
      // En caso de error, mostrar welcome screen por seguridad
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleUpdateSkip() {
    if (_versionResult?.isForced != true) {
      // Cerrar cartel de actualización no forzada y continuar a Welcome
      setState(() {
        _shouldShowUpdate = false;
        _versionResult = null;
      });
    }
  }

  void _handleUpdateContinue() {
    if (_versionResult?.isForced != true) {
      // Cerrar cartel de actualización no forzada y continuar a Welcome
      setState(() {
        _shouldShowUpdate = false;
        _versionResult = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.authStateChanges,
      builder: (context, authSnapshot) {
        // Si está cargando, mostrar pantalla de carga
        if (_isLoading) {
          return const _LoadingScreen();
        }

        // Mostrar pantalla de actualización si es necesario
        if (_shouldShowUpdate && _versionResult != null) {
          return UpdateScreen(
            versionResult: _versionResult!,
            onSkip: _handleUpdateSkip,
            onContinue: _handleUpdateContinue,
          );
        }

        // Si hay usuario autenticado
        if (authSnapshot.hasData && authSnapshot.data != null) {
          // Si NO ha completado onboarding aún, redirigir a onboarding y no procesar join
          if (!_hasCompletedOnboarding && !_redirectedToOnboarding) {
            _redirectedToOnboarding = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  settings: const RouteSettings(name: '/onboarding'),
                  pageBuilder: (context, a, b) =>
                      const InteractiveOnboardingScreen(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            });
            return const _LoadingScreen();
          }

          // Si ya completó onboarding, procesar join pendiente (si existe) y luego ir al Home
          if (NavigationService.hasPendingJoin && !_processingPendingJoin) {
            _processingPendingJoin = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await NavigationService.processPendingJoinIfAny();
              if (mounted) {
                setState(() {
                  _processingPendingJoin = false;
                });
              }
            });
          }
          return const HomeScreen();
        }

        // Si no está autenticado
        if (NavigationService.hasPendingJoin && !_processingPendingJoin) {
          // Caso: deeplink de join recibido sin autenticación → mostrar vista previa
          _processingPendingJoin = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final pending = NavigationService.takePendingJoin();
            if (pending != null) {
              await NavigationService.navigateToGuidePreview(
                guideId: pending['guideId']!,
                token: pending['token']!,
                guideTitle: 'Guía compartida',
              );
            }
            if (mounted) {
              setState(() {
                _processingPendingJoin = false;
              });
            }
          });
        }
        return const WelcomeScreen();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo de la app
            Image.asset(
              'assets/icon.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const Text(
              'Tourify',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Preparando tu experiencia...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
