import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para haptic feedback
import 'dart:math' as math; // Para animaciones de partículas
import 'package:tourify_flutter/data/mock_activities.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:tourify_flutter/services/auth_service.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:tourify_flutter/services/discover_service.dart';

class DiscoverScreen extends StatefulWidget {
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final int travelers;
  final List<String>? travelModes;
  final String? guideName;
  final String? guideDescription;

  const DiscoverScreen({
    super.key,
    this.destination,
    this.startDate,
    this.endDate,
    this.travelers = 1,
    this.travelModes,
    this.guideName,
    this.guideDescription,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with TickerProviderStateMixin {
  // Agregar para animaciones
  final CardSwiperController controller = CardSwiperController();
  bool _showTutorial = true;
  int _currentIndex = 0;
  Stream<List<Activity>>? _activitiesStream;

  // Variables para feedback visual estilo Duolingo
  late AnimationController _progressAnimationController;
  late AnimationController _feedbackAnimationController;
  late AnimationController _celebrationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _feedbackScaleAnimation;
  late Animation<double> _celebrationAnimation;

  bool _showFeedback = false;
  bool _isPositiveFeedback = false;
  int _currentStreak = 0; // Racha actual de actividades aceptadas

  @override
  void initState() {
    super.initState();

    // Limpiar actividades de sesiones anteriores de discover
    DiscoverService.reset();

    // Inicializar controladores de animación para feedback estilo Duolingo
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _feedbackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Configurar animaciones
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    _feedbackScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _feedbackAnimationController,
      curve: Curves.elasticOut,
    ));

    _celebrationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.bounceOut,
    ));

    _initializeStream();
  }

  void _initializeStream() {
    if (!AuthService.isAuthenticated) {
      return;
    }

    print(
        'Iniciando stream de actividades para: ${widget.destination ?? 'Madrid'}');
    print('Fechas: ${widget.startDate} - ${widget.endDate}');

    _activitiesStream = DiscoverService.fetchActivitiesStream(
      destination: widget.destination ?? 'Madrid',
      startDate: widget.startDate,
      endDate: widget.endDate,
      limit: 15, // Solicitar 15 actividades específicamente
      travelers: widget.travelers,
      travelModes: widget.travelModes,
    );
  }

  void _retryLoadActivities() {
    setState(() {
      _initializeStream();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _progressAnimationController.dispose();
    _feedbackAnimationController.dispose();
    _celebrationController.dispose();

    // Limpiar actividades cuando se cierre la pantalla sin crear guía
    DiscoverService.reset();

    super.dispose();
  }

  void _finishDiscovering(List<Activity> activities) async {
    // NO añadir actividades automáticamente - solo usar las que el usuario aceptó
    // El usuario ya ha aceptado las actividades que quería durante el discover

    // Check if user is authenticated
    if (!AuthService.isAuthenticated) {
      _showLoginRequiredDialog();
      return;
    }

    try {
      // Create authenticated guide
      final guideId = await DiscoverService.createGuide(
        destination: widget.destination ?? 'Destino desconocido',
        startDate: widget.startDate ?? DateTime.now(),
        endDate: widget.endDate ?? DateTime.now().add(const Duration(days: 3)),
        travelers: widget.travelers,
        travelModes: widget.travelModes ?? ['cultura', 'fiesta'],
        isPublic: false, // Siempre crear como borrador
        guideName: widget.guideName,
        guideDescription: widget.guideDescription,
      );

      if (guideId != null) {
        // Navigate directly to the created guide
        final guideTitle = 'Guía para ${widget.destination ?? 'tu destino'}';
        NavigationService.navigateToGuide(guideId, guideTitle: guideTitle);
      } else {
        // Show error
        NavigationService.showErrorMessage(
            'Error al crear la guía. Inténtalo de nuevo.');
      }
    } catch (e) {
      print('Error creating guide: $e');
      NavigationService.showErrorMessage(
          'Error al crear la guía: ${e.toString()}');
    } finally {
      // Asegurar que las actividades se limpien siempre, incluso si hay error
      DiscoverService.reset();
    }
  }

  void _finishDiscoveringWithoutAutoAdd(List<Activity> activities) async {
    // No añadir actividades automáticamente - el usuario decidió no incluirlas

    // Check if user is authenticated
    if (!AuthService.isAuthenticated) {
      _showLoginRequiredDialog();
      return;
    }

    try {
      // Create authenticated guide
      final guideId = await DiscoverService.createGuide(
        destination: widget.destination ?? 'Destino desconocido',
        startDate: widget.startDate ?? DateTime.now(),
        endDate: widget.endDate ?? DateTime.now().add(const Duration(days: 3)),
        travelers: widget.travelers,
        travelModes: widget.travelModes ?? ['cultura', 'fiesta'],
        isPublic: false, // Siempre crear como borrador
        guideName: widget.guideName,
        guideDescription: widget.guideDescription,
      );

      if (guideId != null) {
        // Navigate directly to the created guide
        final guideTitle = 'Guía para ${widget.destination ?? 'tu destino'}';
        NavigationService.navigateToGuide(guideId, guideTitle: guideTitle);
      } else {
        // Show error
        NavigationService.showErrorMessage(
            'Error al crear la guía. Inténtalo de nuevo.');
      }
    } catch (e) {
      print('Error creating guide: $e');
      NavigationService.showErrorMessage(
          'Error al crear la guía: ${e.toString()}');
    } finally {
      // Asegurar que las actividades se limpien siempre, incluso si hay error
      DiscoverService.reset();
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.login, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Inicio de sesión requerido'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Debes iniciar sesión para crear una guía personalizada.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Con tu cuenta puedes:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildBenefitRow(
                        Icons.save, 'Guardar guías personalizadas'),
                    _buildBenefitRow(Icons.cloud_sync,
                        'Sincronizar en todos tus dispositivos'),
                    _buildBenefitRow(Icons.share, 'Compartir con amigos'),
                    _buildBenefitRow(Icons.edit, 'Editar en cualquier momento'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                Navigator.of(context).pop();
                // Here you would navigate to login screen
                // Navigator.pushNamed(context, '/login');
              },
              child: const Text('Iniciar sesión',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showVisualFeedback(bool isPositive) {
    // Haptic feedback
    if (isPositive) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _showFeedback = true;
      _isPositiveFeedback = isPositive;
    });

    // Animar feedback
    _feedbackAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _feedbackAnimationController.reverse().then((_) {
          setState(() {
            _showFeedback = false;
          });
        });
      });
    });

    // Si es positivo, animar progreso y celebración
    if (isPositive) {
      _progressAnimationController.forward();
      _celebrationController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _celebrationController.reset();
        });
      });
    }
  }

  // Mostrar feedback visual para acción de deshacer
  void _showUndoVisualFeedback() {
    setState(() {
      _showFeedback = true;
      _isPositiveFeedback = false; // Usar el estilo "neutro"
    });

    // Animar feedback
    _feedbackAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _feedbackAnimationController.reverse().then((_) {
          setState(() {
            _showFeedback = false;
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Error'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 60, color: Colors.blue),
              SizedBox(height: 20),
              Text('Debes iniciar sesión para descubrir actividades'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<Activity>>(
      stream: _activitiesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Error'),
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red),
                  SizedBox(height: 20),
                  Text(
                      'Error al cargar actividades: ${snapshot.error.toString()}'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retryLoadActivities,
                    child: Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        // Si no hay datos aún, mostrar loading
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Cargando actividades...'),
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                      'Cargando actividades para ${widget.destination ?? "tu destino"}'),
                  SizedBox(height: 10),
                  Text(
                    'Las actividades aparecerán conforme lleguen del servidor',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final activities = snapshot.data!;

        // Si la lista está vacía pero el stream está activo, mostrar loading
        if (activities.isEmpty &&
            snapshot.connectionState == ConnectionState.active) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Buscando actividades...'),
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                      'Buscando actividades para ${widget.destination ?? "tu destino"}'),
                  SizedBox(height: 10),
                  Text(
                    'Las actividades aparecerán conforme lleguen del servidor',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // Si la lista está vacía y el stream terminó, mostrar mensaje sin actividades
        if (activities.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Sin actividades'),
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sentiment_dissatisfied,
                      size: 60, color: Colors.grey),
                  SizedBox(height: 20),
                  Text('No hay actividades disponibles para este destino'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Volver'),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildDiscoverInterface(activities);
      },
    );
  }

  Widget _buildDiscoverInterface(List<Activity> activities) {
    // Validación adicional de seguridad
    if (activities.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Sin actividades'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sentiment_dissatisfied, size: 60, color: Colors.grey),
              SizedBox(height: 20),
              Text('No hay actividades disponibles para este destino'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Mostrar el mismo diálogo de confirmación que el botón X
        bool shouldExit = false;
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.exit_to_app, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text('Salir del descubrimiento'),
                  ),
                ],
              ),
              content: const Text(
                '¿Estás seguro de que quieres salir? Perderás el progreso actual de descubrimiento.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    shouldExit = false;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () {
                    shouldExit = true;
                    // Limpiar actividades cuando el usuario confirme salir
                    DiscoverService.reset();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Salir',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
        return shouldExit;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.grey[600],
              size: 28,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.exit_to_app, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: const Text('Salir del descubrimiento'),
                        ),
                      ],
                    ),
                    content: const Text(
                      '¿Estás seguro de que quieres salir? Perderás el progreso actual de descubrimiento.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () {
                          // Limpiar actividades cuando el usuario confirme salir
                          DiscoverService.reset();
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Close discover screen
                        },
                        child: const Text(
                          'Salir',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          title: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[300],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      // Verificar que las animaciones estén inicializadas
                      if (!mounted) {
                        return LinearProgressIndicator(
                          value: _currentIndex / activities.length,
                          backgroundColor: Colors.transparent,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                          minHeight: 8,
                        );
                      }

                      final baseProgress = _currentIndex / activities.length;
                      final animatedProgress = baseProgress +
                          (_progressAnimation.value *
                              0.1); // Pequeño efecto de pulso

                      return LinearProgressIndicator(
                        value: animatedProgress.clamp(0.0, 1.0),
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _progressAnimation.value > 0.5
                                ? Colors.green // Color de éxito cuando se anima
                                : Colors.blue // Color normal
                            ),
                        minHeight: 8,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          actions: [
            // Indicador de racha estilo Duolingo
            if (_currentStreak > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _currentStreak >= 5
                        ? [Colors.orange, Colors.red] // Racha de fuego
                        : [Colors.green, Colors.teal], // Racha normal
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_currentStreak >= 5 ? Colors.orange : Colors.green)
                              .withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentStreak >= 5
                          ? Icons.local_fire_department
                          : Icons.flash_on,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_currentStreak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      bool includeRemaining =
                          true; // Mover la variable aquí para acceso global en el diálogo
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          return AlertDialog(
                            title: Row(
                              children: [
                                Icon(Icons.playlist_add_check,
                                    color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text('Crear mi guía'),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info,
                                              color: Colors.blue, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${DiscoverService.acceptedActivities.length} seleccionadas',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (activities.length - _currentIndex >
                                          0) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: includeRemaining
                                                ? Colors.green.withOpacity(0.1)
                                                : Colors.grey.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: includeRemaining
                                                  ? Colors.green
                                                      .withOpacity(0.3)
                                                  : Colors.grey
                                                      .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Checkbox(
                                                    value: includeRemaining,
                                                    onChanged: (value) {
                                                      setDialogState(() {
                                                        includeRemaining =
                                                            value ?? true;
                                                      });
                                                    },
                                                    activeColor: Colors.green,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${activities.length - _currentIndex} actividades se añadirán',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: includeRemaining
                                                            ? Colors.green
                                                            : Colors.grey[600],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.list_alt,
                                              color: Colors.blue, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Total: ${DiscoverService.acceptedActivities.length + (includeRemaining && activities.length - _currentIndex > 0 ? (activities.length - _currentIndex) : 0)} actividades',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Continuar descubriendo'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // Agregar automáticamente las actividades restantes solo si la opción está marcada
                                  if (includeRemaining) {
                                    final remainingActivities =
                                        activities.skip(_currentIndex).toList();
                                    if (remainingActivities.isNotEmpty) {
                                      for (final activity
                                          in remainingActivities) {
                                        DiscoverService.acceptActivity(
                                            activity);
                                      }
                                    }
                                  }
                                  _finishDiscoveringWithoutAutoAdd(activities);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text(
                                  'Crear guía',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.playlist_add_check, size: 16),
                label: const Text(
                  'Crear',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: CardSwiper(
                    controller: controller,
                    cardsCount: activities.length,
                    numberOfCardsDisplayed: activities.length >= 2 ? 2 : 1,
                    backCardOffset: const Offset(20, 20),
                    padding: const EdgeInsets.all(16.0),
                    onSwipe: (previousIndex, currentIndex, direction) {
                      setState(() {
                        _currentIndex = currentIndex ?? previousIndex + 1;
                      });

                      if (previousIndex < activities.length) {
                        final activity = activities[previousIndex];
                        if (direction == CardSwiperDirection.right) {
                          // Registrar actividad aceptada en el servicio
                          DiscoverService.acceptActivity(activity);

                          setState(() {
                            _currentStreak++; // Incrementar racha
                          });

                          // Mostrar feedback positivo estilo Duolingo
                          final messages = [
                            '¡Genial elección!',
                            '¡Me gusta!',
                            '¡Excelente!',
                            '¡Perfecto!',
                            '¡Increíble!',
                            '¡Buena opción!',
                            '¡Fantástico!',
                          ];

                          // Mostrar feedback visual sin texto
                          _showVisualFeedback(true);

                          // Celebración en hitos
                          if (DiscoverService.acceptedActivities.length % 3 ==
                              0) {
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              HapticFeedback.mediumImpact();
                              _celebrationController.forward().then((_) {
                                Future.delayed(
                                    const Duration(milliseconds: 500), () {
                                  _celebrationController.reset();
                                });
                              });
                            });
                          }
                        } else if (direction == CardSwiperDirection.left) {
                          // Registrar actividad rechazada en el servicio
                          DiscoverService.rejectActivity(activity);

                          setState(() {
                            _currentStreak = 0; // Resetear racha
                          });

                          // Mostrar feedback visual sin texto
                          _showVisualFeedback(false);
                        }
                      }
                      return true;
                    },
                    onEnd: () {
                      // Cuando se acaban las actividades, mostrar diálogo para crear guía
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Row(
                              children: [
                                Icon(Icons.celebration, color: Colors.green),
                                const SizedBox(width: 8),
                                const Text('¡Terminaste!'),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Has revisado todas las actividades disponibles.',
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info,
                                              color: Colors.blue, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${DiscoverService.acceptedActivities.length} actividades seleccionadas',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (DiscoverService
                                          .rejectedActivities.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.cancel,
                                                color: Colors.grey, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${DiscoverService.rejectedActivities.length} actividades descartadas',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _finishDiscovering(activities);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text(
                                  'Crear mi guía',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    cardBuilder: (context, index, horizontalThresholdPercentage,
                        verticalThresholdPercentage) {
                      final activity = activities[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            // Contorno sutil que sugiere deslizamiento
                            border: Border.all(
                              width: 2,
                              color: Colors.white.withOpacity(0.4),
                            ),
                            // Sombras direccionales que indican deslizamiento
                            boxShadow: [
                              // Sombra izquierda (rechazar) - roja
                              BoxShadow(
                                color: Colors.red.withOpacity(0.25),
                                offset: const Offset(-4, 0),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                              // Sombra derecha (aceptar) - verde
                              BoxShadow(
                                color: Colors.green.withOpacity(0.25),
                                offset: const Offset(4, 0),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                              // Sombra principal
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                offset: const Offset(0, 6),
                                blurRadius: 16,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    Image.network(
                                      activity.imageUrl,
                                      height: double.infinity,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: const [0.0, 0.5, 1.0],
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.3),
                                            Colors.black.withOpacity(0.85),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Indicadores laterales de deslizamiento
                                    Positioned(
                                      left: 8,
                                      top: 60,
                                      bottom: 60,
                                      child: Container(
                                        width: 4,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.red.withOpacity(0.7),
                                              Colors.red.withOpacity(0.9),
                                              Colors.red.withOpacity(0.7),
                                              Colors.transparent,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 60,
                                      bottom: 60,
                                      child: Container(
                                        width: 4,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.green.withOpacity(0.7),
                                              Colors.green.withOpacity(0.9),
                                              Colors.green.withOpacity(0.7),
                                              Colors.transparent,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                    // Pequeños iconos indicadores en las esquinas superiores
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.red.withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.red.withOpacity(0.8),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color:
                                                Colors.green.withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          color: Colors.green.withOpacity(0.8),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 16,
                                      left: 16,
                                      right: 16,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activity.name,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            activity.description,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Efectos de deslizamiento mejorados
                              if (horizontalThresholdPercentage != 0)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: RadialGradient(
                                        center:
                                            horizontalThresholdPercentage > 0
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                        radius: 1.5,
                                        colors: horizontalThresholdPercentage >
                                                0
                                            ? [
                                                Colors.green.withOpacity(0.6),
                                                Colors.green.withOpacity(0.3),
                                                Colors.white.withOpacity(0.1),
                                                Colors.transparent,
                                              ]
                                            : [
                                                Colors.red.withOpacity(0.6),
                                                Colors.red.withOpacity(0.3),
                                                Colors.white.withOpacity(0.1),
                                                Colors.transparent,
                                              ],
                                        stops: const [0.0, 0.3, 0.6, 1.0],
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Efecto de haz de luz
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              gradient: LinearGradient(
                                                begin:
                                                    horizontalThresholdPercentage >
                                                            0
                                                        ? Alignment.centerLeft
                                                        : Alignment.centerRight,
                                                end:
                                                    horizontalThresholdPercentage >
                                                            0
                                                        ? Alignment.centerRight
                                                        : Alignment.centerLeft,
                                                colors: [
                                                  Colors.white.withOpacity(0.0),
                                                  Colors.white.withOpacity(0.3),
                                                  Colors.white.withOpacity(0.6),
                                                  Colors.white.withOpacity(0.3),
                                                  Colors.white.withOpacity(0.0),
                                                ],
                                                stops: const [
                                                  0.0,
                                                  0.2,
                                                  0.5,
                                                  0.8,
                                                  1.0
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Icono central
                                        Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.9),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color:
                                                      horizontalThresholdPercentage >
                                                              0
                                                          ? Colors.green
                                                              .withOpacity(0.5)
                                                          : Colors.red
                                                              .withOpacity(0.5),
                                                  blurRadius: 20,
                                                  spreadRadius: 5,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              horizontalThresholdPercentage > 0
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              color:
                                                  horizontalThresholdPercentage >
                                                          0
                                                      ? Colors.green
                                                      : Colors.red,
                                              size: 60,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 16.0,
                    bottom: 28.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botón de retroceder (amarillo)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: DiscoverService.canUndo
                              ? Colors.amber
                              : Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: DiscoverService.canUndo
                              ? () {
                                  // Verificar si se puede deshacer
                                  final undoneActivity =
                                      DiscoverService.undoLastAction();

                                  if (undoneActivity != null) {
                                    // Animar el undo en la UI
                                    controller.undo();

                                    setState(() {
                                      if (_currentIndex > 0) {
                                        _currentIndex--;
                                      }
                                    });

                                    // Mostrar feedback visual para undo
                                    _showUndoVisualFeedback();

                                    // Haptic feedback
                                    HapticFeedback.lightImpact();
                                  }
                                }
                              : null,
                          icon: Icon(
                            Icons.undo,
                            color: DiscoverService.canUndo
                                ? Colors.white
                                : Colors.grey[600],
                            size: 24,
                          ),
                        ),
                      ),
                      // Botón de rechazar (rojo)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () {
                              HapticFeedback.mediumImpact(); // Feedback háptico
                              // Efecto visual en el botón
                              setState(() {});
                              controller.swipe(CardSwiperDirection.left);
                            },
                            child: AnimatedBuilder(
                              animation: _feedbackAnimationController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: !_isPositiveFeedback && _showFeedback
                                      ? 1.1
                                      : 1.0,
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      // Botón de aceptar (verde)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () {
                              HapticFeedback.mediumImpact(); // Feedback háptico
                              // Efecto visual en el botón
                              setState(() {});
                              controller.swipe(CardSwiperDirection.right);
                            },
                            child: AnimatedBuilder(
                              animation: _feedbackAnimationController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _isPositiveFeedback && _showFeedback
                                      ? 1.2
                                      : 1.0,
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_showTutorial)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showTutorial = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.swipe,
                          color: Colors.white,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Desliza a la derecha para aceptar\nDesliza a la izquierda para rechazar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showTutorial = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Entendido',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Widget de feedback visual eliminado
            // Widget de celebración de progreso
            AnimatedBuilder(
              animation: _celebrationController,
              builder: (context, child) {
                // Verificar que las animaciones estén inicializadas
                if (!mounted || _celebrationController.value == 0)
                  return const SizedBox.shrink();

                return Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      child: Stack(
                        children: [
                          // Partículas de celebración
                          ...List.generate(8, (index) {
                            final angle = (index * 45.0) * (3.14159 / 180.0);
                            final distance =
                                100.0 * _celebrationAnimation.value;
                            final opacity = 1.0 - _celebrationAnimation.value;

                            return Positioned(
                              top: MediaQuery.of(context).size.height * 0.4 +
                                  (distance * math.sin(angle)),
                              left: MediaQuery.of(context).size.width * 0.5 +
                                  (distance * math.cos(angle)),
                              child: Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale:
                                      1.0 + (_celebrationAnimation.value * 0.5),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: [
                                        Colors.green,
                                        Colors.blue,
                                        Colors.orange,
                                        Colors.purple,
                                      ][index % 4],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          // Texto de celebración
                          if (DiscoverService.acceptedActivities.length % 3 ==
                                  0 &&
                              DiscoverService.acceptedActivities.isNotEmpty &&
                              _celebrationController.value > 0.3)
                            Positioned(
                              top: MediaQuery.of(context).size.height * 0.35,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Transform.scale(
                                  scale: _celebrationAnimation.value,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.purple, Colors.blue],
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.purple.withOpacity(0.4),
                                          blurRadius: 15,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '¡${DiscoverService.acceptedActivities.length} actividades! 🎉',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
