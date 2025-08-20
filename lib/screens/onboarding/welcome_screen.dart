import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tourify_flutter/config/app_colors.dart';
import 'package:tourify_flutter/services/onboarding_service.dart';
import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:tourify_flutter/screens/onboarding/guest_guide_intro_screen.dart';
import 'package:tourify_flutter/screens/onboarding/interactive_onboarding_screen.dart';
import 'package:tourify_flutter/screens/auth/login_screen.dart';
import 'package:tourify_flutter/services/navigation_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _buttonsAnimationController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<Offset> _buttonsSlideAnimation;
  late Animation<double> _buttonsOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();

    // Analytics: Usuario llega a la pantalla de bienvenida
    AnalyticsService.trackEvent('welcome_screen_shown');
  }

  void _initializeAnimations() {
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _buttonsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _buttonsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _buttonsAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _buttonsOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonsAnimationController,
      curve: Curves.easeOut,
    ));
  }

  void _startAnimations() async {
    await _logoAnimationController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _buttonsAnimationController.forward();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _buttonsAnimationController.dispose();
    super.dispose();
  }

  void _onNewUserPressed() {
    HapticFeedback.mediumImpact();

    // Analytics: Usuario elige ser nuevo
    AnalyticsService.trackEvent('welcome_new_user_selected');

    // Si hay pendingJoin (deeplink), ir al onboarding interactivo (no a creación de guía)
    if (NavigationService.hasPendingJoin) {
      OnboardingService.markWelcomeScreenSeen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const InteractiveOnboardingScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      return;
    }

    // Sin pendingJoin: flujo habitual “probar sin registro”
    _onTryWithoutRegisterPressed();
  }

  void _onExistingUserPressed() {
    HapticFeedback.mediumImpact();

    // Analytics: Usuario elige ya tener cuenta
    AnalyticsService.trackEvent('welcome_existing_user_selected');

    // Marcar que ya vio la pantalla de bienvenida
    OnboardingService.markWelcomeScreenSeen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _onTryWithoutRegisterPressed() {
    HapticFeedback.mediumImpact();

    // Analytics: Usuario elige probar sin registro
    AnalyticsService.trackEvent('welcome_try_without_register_selected');

    // Marcar que ya vio la pantalla de bienvenida
    OnboardingService.markWelcomeScreenSeen();

    // Navegar directamente a la pantalla de creación de guía sin registro
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GuestGuideIntroScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bool hasPendingJoin = NavigationService.hasPendingJoin;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              children: [
                // Espaciado superior
                SizedBox(height: screenHeight * 0.05),

                // Logo y título animados
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo animado
                      Flexible(
                        child: AnimatedBuilder(
                          animation: _logoAnimationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _logoScaleAnimation.value,
                              child: Opacity(
                                opacity: _logoOpacityAnimation.value,
                                child: Image.asset(
                                  'assets/icon.png',
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Título
                      AnimatedBuilder(
                        animation: _logoOpacityAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _logoOpacityAnimation.value,
                            child: const Text(
                              'Tourify',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Subtítulo
                      AnimatedBuilder(
                        animation: _logoOpacityAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _logoOpacityAnimation.value * 0.9,
                            child: const Text(
                              'Tu compañero de viaje perfecto',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Botones animados
                Expanded(
                  flex: 3,
                  child: AnimatedBuilder(
                    animation: _buttonsAnimationController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _buttonsSlideAnimation,
                        child: FadeTransition(
                          opacity: _buttonsOpacityAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Texto de pregunta
                              Text(
                                hasPendingJoin
                                    ? 'Crea tu cuenta para guardar esta guía'
                                    : '¿Eres nuevo en Tourify?',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 40),

                              // Botón "Soy nuevo"
                              _buildActionButton(
                                text: 'Soy nuevo',
                                icon: Icons.person_add,
                                onPressed: _onNewUserPressed,
                                isPrimary: true,
                              ),

                              const SizedBox(height: 16),

                              // Botón "Ya tengo una cuenta"
                              _buildActionButton(
                                text: 'Ya tengo una cuenta',
                                icon: Icons.login,
                                onPressed: _onExistingUserPressed,
                                isPrimary: false,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Espaciado inferior
                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white : Colors.transparent,
          foregroundColor: isPrimary ? AppColors.primary : Colors.white,
          elevation: isPrimary ? 8 : 0,
          side: isPrimary
              ? null
              : const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isPrimary ? AppColors.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
