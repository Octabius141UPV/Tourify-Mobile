import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tourify_flutter/config/app_colors.dart';
import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:tourify_flutter/screens/onboarding/guest_guide_creation_screen.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:tourify_flutter/screens/onboarding/interactive_onboarding_screen.dart';
import 'package:tourify_flutter/screens/onboarding/welcome_screen.dart';

class GuestGuideIntroScreen extends StatefulWidget {
  const GuestGuideIntroScreen({super.key});

  @override
  State<GuestGuideIntroScreen> createState() => _GuestGuideIntroScreenState();
}

class _GuestGuideIntroScreenState extends State<GuestGuideIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Track analytics
    AnalyticsService.trackEvent('guest_guide_intro_viewed');

    // Configurar animaciones
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutBack));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _buttonAnimationController, curve: Curves.elasticOut),
    );

    // Iniciar animaciones
    _animationController.forward();
    _buttonAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  void _continueToCreation() {
    HapticFeedback.mediumImpact();
    AnalyticsService.trackEvent('guest_guide_intro_continue');
    // Si venimos de deeplink (pendingJoin), saltar a onboarding interactivo
    if (NavigationService.hasPendingJoin) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const InteractiveOnboardingScreen(),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const GuestGuideCreationScreen(),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  void _onClosePressed() {
    HapticFeedback.lightImpact();

    // Analytics: Usuario cierra el modal de creación de guía
    AnalyticsService.trackEvent('guest_guide_intro_closed');

    // Navegar de vuelta a la pantalla de bienvenida
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WelcomeScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2563EB),
              Color(0xFF1D4ED8),
              Color(0xFF1E40AF),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Botón de cerrar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        const Text(
                          'Crear Guía',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: _onClosePressed,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),

                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ilustración de la caricatura con clipboard.png
                          Image.asset(
                            'assets/images/clipboard.png',
                            width: 250,
                            height: 250,
                            fit: BoxFit.contain,
                          ),

                          const SizedBox(height: 40),

                          // Título principal
                          const Text(
                            '¡Crea tu primera guía!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Subtítulo explicativo
                          const Text(
                            'Te ayudaremos a crear una guía personalizada para tu viaje en solo unos pasos',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 60),
                        ],
                      ),
                    ),

                    // Botón de continuar
                    const SizedBox(height: 32),
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _continueToCreation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Comenzar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
