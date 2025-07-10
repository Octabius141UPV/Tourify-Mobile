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

  // Variables para controlar el estado del stream
  bool _isStreamCompleted = false;
  bool _isStreamLoading = true;
  bool _isWaitingForStreamToComplete = false;
  bool _waitingForMoreActivities =
      false; // Esperando más actividades del stream
  int _activitiesCountWhenWaiting =
      0; // Cuántas actividades había cuando empezamos a esperar
  bool _isCreatingGuide =
      false; // Estado de carga cuando se está creando la guía

  // Set para trackear actividades ya evaluadas (por ID único)
  Set<String> _evaluatedActivityIds = <String>{};

  // Map para trackear el estado expandido de las descripciones
  Map<String, bool> _expandedDescriptions = <String, bool>{};

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
      limit: 5 * (widget.endDate!.difference(widget.startDate!).inDays + 1),
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

    // Mostrar estado de carga
    setState(() {
      _isCreatingGuide = true;
    });

    try {
      // Create authenticated guide
      final guideId = await DiscoverService.createGuide(
        destination: widget.destination ?? 'Destino desconocido',
        startDate: widget.startDate ?? DateTime.now(),
        endDate: widget.endDate ?? DateTime.now().add(const Duration(days: 7)),
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
      // Resetear estado de carga
      if (mounted) {
        setState(() {
          _isCreatingGuide = false;
        });
      }
    }
  }

  void _finishDiscoveringWithoutAutoAdd(List<Activity> activities) async {
    // No añadir actividades automáticamente - el usuario decidió no incluirlas

    // Check if user is authenticated
    if (!AuthService.isAuthenticated) {
      _showLoginRequiredDialog();
      return;
    }

    // Mostrar estado de carga
    setState(() {
      _isCreatingGuide = true;
    });

    try {
      // Create authenticated guide
      final guideId = await DiscoverService.createGuide(
        destination: widget.destination ?? 'Destino desconocido',
        startDate: widget.startDate ?? DateTime.now(),
        endDate: widget.endDate ?? DateTime.now().add(const Duration(days: 7)),
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
      // Resetear estado de carga
      if (mounted) {
        setState(() {
          _isCreatingGuide = false;
        });
      }
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

  // Mostrar diálogo de confirmación para salir
  void _showExitDialog(BuildContext context) {
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
  }

  // Filtrar actividades para mostrar solo las no evaluadas (método original como fallback)
  List<Activity> _getUnevaluatedActivities(List<Activity> allActivities) {
    if (allActivities.isEmpty) {
      return [];
    }

    try {
      final unevaluated = allActivities
          .where((activity) =>
              activity != null &&
              activity.id.isNotEmpty &&
              !_evaluatedActivityIds.contains(activity.id))
          .toList();

      // Mantener el orden original sin ninguna modificación
      return unevaluated;
    } catch (e) {
      print('Error filtering activities: $e');
      return [];
    }
  }

  // NO ordenar actividades - mantener el orden original que viene del servidor
  List<Activity> _sortActivitiesWithPartyLast(List<Activity> activities) {
    // Devolver las actividades en su orden original sin ninguna modificación
    return activities;
  }

  // Método para determinar si una actividad es de fiesta
  bool _isPartyActivity(Activity activity) {
    final category = activity.category.toLowerCase();

    // Verificar si la categoría contiene palabras relacionadas con fiesta
    return category.contains('fiesta') ||
        category.contains('party') ||
        category.contains('nightlife') ||
        category.contains('vida nocturna') ||
        category.contains('discoteca') ||
        category.contains('bar') ||
        category.contains('club') ||
        category.contains('nocturna');
  }

  void _showCompletionDialog(List<Activity> activities) {
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
                        Icon(Icons.info, color: Colors.blue, size: 20),
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
                    if (DiscoverService.rejectedActivities.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.grey, size: 20),
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
  }

  // Asegurar que el índice esté en rango válido
  void _ensureValidCurrentIndex(List<Activity> activities) {
    if (activities.isEmpty) {
      _currentIndex = 0;
    } else {
      // Si el índice está fuera de rango, resetear a 0 para mostrar desde el principio
      if (_currentIndex >= activities.length) {
        _currentIndex = 0;
      } else {
        _currentIndex = _currentIndex.clamp(0, activities.length - 1);
      }
    }
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

    // Si se está creando la guía, mostrar estado de carga
    if (_isCreatingGuide) {
      return _buildCreatingGuideInterface();
    }

    return StreamBuilder<List<Activity>>(
      stream: _activitiesStream,
      builder: (context, snapshot) {
        // Actualizar estado del stream SOLO cuando sea necesario
        final currentConnectionState = snapshot.connectionState;
        final wasCompleted = _isStreamCompleted;
        final newIsLoading =
            currentConnectionState == ConnectionState.waiting ||
                currentConnectionState == ConnectionState.active;
        final newIsCompleted = currentConnectionState == ConnectionState.done;

        // Solo ejecutar callback si hay cambios de estado importantes
        if (_isStreamLoading != newIsLoading ||
            _isStreamCompleted != newIsCompleted ||
            (!wasCompleted &&
                newIsCompleted &&
                _isWaitingForStreamToComplete) ||
            (_waitingForMoreActivities &&
                snapshot.hasData &&
                snapshot.data!.length > _activitiesCountWhenWaiting)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isStreamLoading = newIsLoading;
              _isStreamCompleted = newIsCompleted;

              // Si el stream acaba de completarse y el usuario estaba esperando
              if (!wasCompleted &&
                  _isStreamCompleted &&
                  _isWaitingForStreamToComplete) {
                _isWaitingForStreamToComplete = false;
                // Ir automáticamente a crear la guía
                _finishDiscovering(snapshot.data ?? []);
              }

              // Solo volver al discover si llegaron MÁS actividades de las que había cuando empezamos a esperar
              if (_waitingForMoreActivities &&
                  snapshot.hasData &&
                  snapshot.data!.length > _activitiesCountWhenWaiting) {
                _waitingForMoreActivities = false;
                _activitiesCountWhenWaiting = 0; // Reset
              }
            });
          });
        }

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

        final allActivities = snapshot.data!;
        final activities = _getUnevaluatedActivities(allActivities);

        // Debug logging para entender el problema del orden
        if (allActivities.isNotEmpty && _isStreamLoading) {
          print('📊 Estado del stream:');
          print('   Total actividades: ${allActivities.length}');
          print('   Actividades sin evaluar: ${activities.length}');
          print('   Índice actual: $_currentIndex');
          print('   Stream completado: $_isStreamCompleted');
          print('   Evaluadas: ${_evaluatedActivityIds.length}');

          // Mostrar títulos para verificar orden
          if (activities.isNotEmpty) {
            print('   Próximas actividades:');
            for (int i = 0; i < activities.length && i < 3; i++) {
              final activity = activities[i];
              print('     [$i] ${activity.name}');
            }
          }
        }

        // Asegurar que el índice esté en rango válido
        _ensureValidCurrentIndex(activities);

        // SOLUCIÓN ADICIONAL: Si hay problemas de índice, forzar reset a 0
        if (activities.isNotEmpty &&
            (_currentIndex >= activities.length || _currentIndex < 0)) {
          print(
              '🔄 Reseteando índice actual de $_currentIndex a 0 (activities.length: ${activities.length})');
          _currentIndex = 0;
        }

        // Si la lista está vacía pero el stream está activo, mostrar loading
        if (allActivities.isEmpty &&
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

        // Si no hay actividades sin evaluar y el stream terminó, mostrar mensaje de finalización
        if (activities.isEmpty && _isStreamCompleted) {
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

        // Verificar si estamos esperando más actividades (usuario ha evaluado todas las disponibles)
        if (_waitingForMoreActivities && !_isStreamCompleted) {
          return _buildWaitingForMoreActivitiesInterface();
        }

        // Si no hay actividades sin evaluar pero el stream sigue activo, mostrar pantalla de espera
        if (activities.isEmpty && !_isStreamCompleted) {
          // Activar estado de espera automáticamente
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_waitingForMoreActivities) {
              setState(() {
                _waitingForMoreActivities = true;
                _activitiesCountWhenWaiting = allActivities.length;
              });
            }
          });
          return _buildWaitingForMoreActivitiesInterface();
        }

        return _buildDiscoverInterface(activities, allActivities);
      },
    );
  }

  Widget _buildCreatingGuideInterface() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Creando tu guía...',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '✨ Creando tu guía personalizada',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Estamos organizando tus ${DiscoverService.acceptedActivities.length} actividades seleccionadas...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        '${DiscoverService.acceptedActivities.length} actividades confirmadas',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu guía estará lista en unos momentos',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForMoreActivitiesInterface() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.grey[700],
            size: 24,
          ),
          onPressed: () {
            _showExitDialog(context);
          },
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Cargando más actividades...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: !_isStreamCompleted
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Esperando que lleguen más actividades del servidor...'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.hourglass_empty, size: 16),
              label: const Text(
                'Esperando...',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_empty,
                size: 60,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Has evaluado todas las actividades disponibles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Estamos cargando más opciones para ti...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Progreso actual:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${DiscoverService.acceptedActivities.length} actividades seleccionadas',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (DiscoverService.rejectedActivities.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.grey, size: 16),
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
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverInterface(
      List<Activity> activities, List<Activity> allActivities) {
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

    // Mantener el orden original de las actividades como llegan del servidor
    // La primera actividad del stream debe ser la primera en mostrarse

    // SOLUCIÓN CRÍTICA: Usar la longitud de activities como key para forzar rebuild del CardSwiper
    // Esto evita problemas de índices cuando la lista filtrada cambia de tamaño
    // Incluir el hash de los IDs evaluados para detectar cambios por undo
    final cardSwiperKey = Key(
        'card_swiper_${activities.length}_${_evaluatedActivityIds.length}_${_evaluatedActivityIds.hashCode}');

    return WillPopScope(
      onWillPop: () async {
        _showExitDialog(context);
        return false; // Prevenir el pop automático, el diálogo maneja la navegación
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Colors.grey[700],
              size: 24,
            ),
            onPressed: () {
              _showExitDialog(context);
            },
          ),
          title: Column(
            children: [
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
                      // Calcular progreso real basado en actividades evaluadas vs total disponible
                      final totalEvaluated = _evaluatedActivityIds.length;
                      final totalAvailable = allActivities.length;

                      // Verificar que las animaciones estén inicializadas
                      if (!mounted) {
                        return LinearProgressIndicator(
                          value: totalAvailable == 0
                              ? 0.0
                              : (totalEvaluated / totalAvailable)
                                  .clamp(0.0, 1.0),
                          backgroundColor: Colors.transparent,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                          minHeight: 8,
                        );
                      }

                      // Progreso base real: actividades evaluadas / total disponible
                      final baseProgress = totalAvailable == 0
                          ? 0.0
                          : (totalEvaluated / totalAvailable).clamp(0.0, 1.0);

                      // Pequeño efecto de pulso cuando se evalúa una actividad
                      final animatedProgress = baseProgress +
                          (_progressAnimation.value * 0.05); // Efecto más sutil

                      return LinearProgressIndicator(
                        value: animatedProgress.clamp(0.0, 1.0),
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _progressAnimation.value > 0.3
                                ? Colors.green // Color de éxito cuando se anima
                                : baseProgress > 0.8
                                    ? Colors.orange // Cerca del final
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
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: !_isStreamCompleted
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Esperando que termine de cargar todas las actividades...'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    : null,
                child: ElevatedButton.icon(
                  onPressed: _isStreamCompleted
                      ? () {
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.info,
                                                      color: Colors.blue,
                                                      size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${DiscoverService.acceptedActivities.length} seleccionadas',
                                                      style: TextStyle(
                                                        color: Colors.blue,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if ((activities.length -
                                                          _currentIndex)
                                                      .clamp(0,
                                                          activities.length) >
                                                  0) ...[
                                                const SizedBox(height: 12),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: includeRemaining
                                                        ? Colors.green
                                                            .withOpacity(0.1)
                                                        : Colors.grey
                                                            .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
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
                                                            value:
                                                                includeRemaining,
                                                            onChanged: (value) {
                                                              setDialogState(
                                                                  () {
                                                                includeRemaining =
                                                                    value ??
                                                                        true;
                                                              });
                                                            },
                                                            activeColor:
                                                                Colors.green,
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              '${(allActivities.length - _evaluatedActivityIds.length).clamp(0, allActivities.length)} actividades se añadirán',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: includeRemaining
                                                                    ? Colors
                                                                        .green
                                                                    : Colors.grey[
                                                                        600],
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
                                                      color: Colors.blue,
                                                      size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Total: ${DiscoverService.acceptedActivities.length + (includeRemaining && (allActivities.length - _evaluatedActivityIds.length).clamp(0, allActivities.length) > 0 ? (allActivities.length - _evaluatedActivityIds.length).clamp(0, allActivities.length) : 0)} actividades',
                                                      style: TextStyle(
                                                        color: Colors.blue,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text(
                                            'Continuar descubriendo'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          // Agregar automáticamente las actividades restantes solo si la opción está marcada
                                          if (includeRemaining) {
                                            final remainingActivities =
                                                allActivities
                                                    .where((activity) =>
                                                        !_evaluatedActivityIds
                                                            .contains(
                                                                activity.id))
                                                    .toList();
                                            if (remainingActivities
                                                .isNotEmpty) {
                                              for (final activity
                                                  in remainingActivities) {
                                                DiscoverService.acceptActivity(
                                                    activity);
                                              }
                                            }
                                          }
                                          _finishDiscoveringWithoutAutoAdd(
                                              activities);
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
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isStreamCompleted ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: Icon(
                      _isStreamCompleted
                          ? Icons.playlist_add_check
                          : Icons.hourglass_empty,
                      size: 16),
                  label: Text(
                    _isStreamCompleted ? 'Crear' : 'Cargando...',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
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
                    key:
                        cardSwiperKey, // CRÍTICO: Key para forzar rebuild cuando cambie la lista
                    controller: controller,
                    cardsCount: activities
                        .length, // Simplificado - activities nunca está vacío aquí
                    numberOfCardsDisplayed:
                        1, // Solo mostrar una carta a la vez
                    backCardOffset:
                        const Offset(0, 0), // Sin offset para la carta de atrás
                    padding: const EdgeInsets.all(16.0),
                    onSwipe: (previousIndex, currentIndex, direction) {
                      // Validación de seguridad para evitar errores de índice
                      if (previousIndex >= activities.length ||
                          previousIndex < 0 ||
                          activities.isEmpty) {
                        print(
                            '⚠️ Swipe inválido - previousIndex: $previousIndex, activities.length: ${activities.length}');
                        return true; // Ignorar swipe inválido
                      }

                      final activity = activities[previousIndex];

                      // Validar que la actividad existe
                      if (activity == null) {
                        print('⚠️ Actividad nula en índice $previousIndex');
                        return true;
                      }

                      setState(() {
                        _currentIndex = (currentIndex ?? previousIndex + 1)
                            .clamp(0, activities.length);
                      });

                      // Marcar esta actividad como evaluada
                      _evaluatedActivityIds.add(activity.id);

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
                          Future.delayed(const Duration(milliseconds: 300), () {
                            HapticFeedback.mediumImpact();
                            _celebrationController.forward().then((_) {
                              Future.delayed(const Duration(milliseconds: 500),
                                  () {
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
                      return true;
                    },
                    onEnd: () {
                      // Verificar si el stream ha terminado antes de permitir crear la guía
                      if (!_isStreamCompleted) {
                        // No mostrar diálogo modal, solo cambiar el estado a "esperando más actividades"
                        setState(() {
                          _waitingForMoreActivities = true;
                          _activitiesCountWhenWaiting = allActivities
                              .length; // Recordar cuántas actividades había en total
                        });
                        return;
                      }

                      // Si el stream ha terminado, ir automáticamente a crear la guía
                      _finishDiscovering(allActivities);
                    },
                    cardBuilder: (context, index, horizontalThresholdPercentage,
                        verticalThresholdPercentage) {
                      // Validación de seguridad para evitar errores de índice
                      if (activities.isEmpty ||
                          index >= activities.length ||
                          index < 0) {
                        print(
                            '🚨 PROBLEMA CRÍTICO - CardBuilder índice inválido: $index, activities.length: ${activities.length}');
                        print(
                            '   Total actividades: ${allActivities.length}, Evaluadas: ${_evaluatedActivityIds.length}');

                        // En lugar de mostrar "Cargando", mostrar un error más claro
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.orange[100],
                            border: Border.all(color: Colors.orange, width: 2),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sync_problem,
                                    size: 48, color: Colors.orange),
                                SizedBox(height: 16),
                                Text(
                                  'Error de sincronización',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Índice $index fuera de rango (${activities.length} actividades disponibles)',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Total: ${allActivities.length} | Evaluadas: ${_evaluatedActivityIds.length}',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final activity = activities[index];

                      // Validación adicional de la actividad
                      if (activity == null) {
                        print(
                            '⚠️ Actividad nula en índice $index del cardBuilder');
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey[200],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning,
                                    color: Colors.orange, size: 48),
                                SizedBox(height: 16),
                                Text('Actividad no disponible'),
                              ],
                            ),
                          ),
                        );
                      }
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
                                          StatefulBuilder(
                                            builder:
                                                (context, setDescriptionState) {
                                              final description =
                                                  activity.description;
                                              final isLongDescription =
                                                  description.length > 120;
                                              final isExpanded =
                                                  _expandedDescriptions[
                                                          activity.id] ??
                                                      false;

                                              return GestureDetector(
                                                onTap: isLongDescription
                                                    ? () {
                                                        setState(() {
                                                          _expandedDescriptions[
                                                                  activity.id] =
                                                              !isExpanded;
                                                        });
                                                      }
                                                    : null,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    AnimatedSize(
                                                      duration: const Duration(
                                                          milliseconds: 300),
                                                      curve: Curves.easeInOut,
                                                      child: Text(
                                                        description,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          color: Colors.white,
                                                        ),
                                                        maxLines: isExpanded
                                                            ? null
                                                            : 3,
                                                        overflow: isExpanded
                                                            ? TextOverflow
                                                                .visible
                                                            : TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                    if (isLongDescription) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        isExpanded
                                                            ? 'Ver menos'
                                                            : 'Ver más',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.white
                                                              .withOpacity(0.8),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              );
                                            },
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
                                    print(
                                        '🔄 Undo para actividad: ${undoneActivity.name} (ID: ${undoneActivity.id})');

                                    setState(() {
                                      // CRÍTICO: Remover la actividad del set de evaluadas para que vuelva a aparecer
                                      _evaluatedActivityIds
                                          .remove(undoneActivity.id);

                                      // Ajustar el índice actual para mostrar la actividad que vuelve
                                      if (_currentIndex > 0) {
                                        _currentIndex--;
                                      }
                                    });

                                    // Animar el undo en la UI
                                    controller.undo();

                                    // Mostrar feedback visual para undo
                                    _showUndoVisualFeedback();

                                    // Haptic feedback
                                    HapticFeedback.lightImpact();

                                    print(
                                        '✅ Actividad ${undoneActivity.name} restaurada. Evaluadas ahora: ${_evaluatedActivityIds.length}');
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
