import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/onboarding_service.dart';
import '../screens/home_screen.dart';
import '../config/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _pageAnimationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;

  int _currentPage = 0;
  final int _totalPages = 5;
  bool _isAnimating = false;

  final List<OnboardingItem> _onboardingItems = [
    OnboardingItem(
      icon: Icons.explore,
      title: '¡Bienvenido a Tourify!',
      description:
          'Tu compañero perfecto para crear guías de viaje personalizadas y descubrir experiencias únicas',
      backgroundColor: Colors.blue,
      iconColor: Colors.white,
    ),
    OnboardingItem(
      icon: Icons.auto_awesome,
      title: 'Descubre actividades',
      description:
          'Desliza para explorar actividades personalizadas según tus preferencias y crea tu guía ideal',
      backgroundColor: Colors.purple,
      iconColor: Colors.white,
    ),
    OnboardingItem(
      icon: Icons.map,
      title: 'Explora con el mapa',
      description:
          'Visualiza todas tus actividades en un mapa interactivo y navega por tu destino sin perderte',
      backgroundColor: Colors.green,
      iconColor: Colors.white,
    ),
    OnboardingItem(
      icon: Icons.group,
      title: 'Colabora con amigos',
      description:
          'Invita a tus amigos a editar tus guías y planifica viajes increíbles juntos en tiempo real',
      backgroundColor: const Color(
          0xFF8E24AA), // Violeta elegante que transmite colaboración
      iconColor: Colors.white,
    ),
    OnboardingItem(
      icon: Icons.rocket_launch,
      title: '¡Comienza tu aventura!',
      description:
          'Todo está listo. Crea tu primera guía y descubre un mundo de posibilidades de viaje',
      backgroundColor: Colors.indigo,
      iconColor: Colors.white,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _pageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600), // Más corto y suave
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeOut, // Más suave que easeInOut
    ));

    _slideAnimation = Tween<double>(
      begin: 30.0, // Menos movimiento
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeOut, // Cambiar de elasticOut a easeOut
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05, // Menos escala
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeOut,
    ));

    // Iniciar animación inicial
    _pageAnimationController.forward();
  }

  void _animatePageTransition() {
    if (_isAnimating) return; // Evitar múltiples animaciones simultáneas

    _isAnimating = true;
    _pageAnimationController.reset();
    _pageAnimationController.forward().then((_) {
      _isAnimating = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageAnimationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToEnd() {
    HapticFeedback.mediumImpact();
    _pageController.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    _buttonAnimationController.forward();

    await OnboardingService.markOnboardingCompleted();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _onboardingItems[_currentPage].backgroundColor.withOpacity(0.9),
              _onboardingItems[_currentPage].backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header con botón skip
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo o título
                    const Text(
                      'Tourify',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    // Botón Skip (solo en las primeras páginas)
                    if (_currentPage < _totalPages - 1)
                      TextButton(
                        onPressed: _skipToEnd,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.8),
                        ),
                        child: const Text(
                          'Omitir',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Indicadores de página
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _totalPages,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              // Contenido principal
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _animatePageTransition();
                    HapticFeedback.selectionClick();
                  },
                  itemCount: _totalPages,
                  itemBuilder: (context, index) {
                    final item = _onboardingItems[index];
                    return _buildOnboardingPage(item);
                  },
                ),
              ),

              // Navegación inferior
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón Anterior
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentPage > 0 ? 1.0 : 0.0,
                      child: TextButton.icon(
                        onPressed: _currentPage > 0 ? _previousPage : null,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back, size: 20),
                        label: const Text('Anterior'),
                      ),
                    ),

                    // Botón Siguiente/Comenzar
                    ElevatedButton.icon(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor:
                            _onboardingItems[_currentPage].backgroundColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      icon: Icon(
                        _currentPage == _totalPages - 1
                            ? Icons.rocket_launch
                            : Icons.arrow_forward,
                        size: 20,
                      ),
                      label: Text(
                        _currentPage == _totalPages - 1
                            ? 'Comenzar'
                            : 'Siguiente',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingItem item) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono principal con animación simple
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      item.icon,
                      size: 60,
                      color: item.iconColor,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // Título
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value * 0.5),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Descripción
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value * 0.3),
                child: Opacity(
                  opacity: _fadeAnimation.value * 0.9,
                  child: Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // Elementos decorativos específicos por página
          if (_currentPage == 1) _buildDiscoverAnimation(),
          if (_currentPage == 2) _buildMapAnimation(),
          if (_currentPage == 3) _buildCollaborationAnimation(),
        ],
      ),
    );
  }

  Widget _buildDiscoverAnimation() {
    return Opacity(
      opacity: 0.8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSwipeCard(Colors.red.withOpacity(0.8), Icons.close),
          const SizedBox(width: 20),
          _buildSwipeCard(Colors.green.withOpacity(0.8), Icons.check),
        ],
      ),
    );
  }

  Widget _buildSwipeCard(Color color, IconData icon) {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  Widget _buildMapAnimation() {
    return Opacity(
      opacity: 0.8,
      child: Container(
        width: 200,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Puntos del mapa
            Positioned(
              top: 20,
              left: 30,
              child: _buildMapPin(Colors.red),
            ),
            Positioned(
              top: 50,
              right: 40,
              child: _buildMapPin(Colors.blue),
            ),
            Positioned(
              bottom: 30,
              left: 60,
              child: _buildMapPin(Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPin(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  Widget _buildCollaborationAnimation() {
    return Opacity(
      opacity: 0.8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildUserAvatar(Colors.blue),
          const SizedBox(width: 10),
          Icon(
            Icons.add,
            color: Colors.white.withOpacity(0.8),
            size: 20,
          ),
          const SizedBox(width: 10),
          _buildUserAvatar(Colors.purple),
          const SizedBox(width: 10),
          Icon(
            Icons.add,
            color: Colors.white.withOpacity(0.8),
            size: 20,
          ),
          const SizedBox(width: 10),
          _buildUserAvatar(Colors.green),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class OnboardingItem {
  final IconData icon;
  final String title;
  final String description;
  final Color backgroundColor;
  final Color iconColor;

  OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.backgroundColor,
    required this.iconColor,
  });
}
