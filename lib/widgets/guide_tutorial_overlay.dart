import 'package:tourify_flutter/services/guide_tutorial_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuideTutorialOverlay extends StatefulWidget {
  final bool canEdit;
  final VoidCallback? onTutorialCompleted;

  const GuideTutorialOverlay({
    super.key,
    required this.canEdit,
    this.onTutorialCompleted,
  });

  @override
  State<GuideTutorialOverlay> createState() => _GuideTutorialOverlayState();
}

class _GuideTutorialOverlayState extends State<GuideTutorialOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  List<TutorialStep> get _tutorialSteps {
    final steps = <TutorialStep>[
      // Paso 1: Bienvenida
      TutorialStep(
        title: '¡Bienvenido a tu guía! 🗺️',
        description:
            'Aquí tienes todas las actividades organizadas por días. Te mostraré todo lo que puedes hacer.',
        icon: Icons.map_rounded,
        color: Colors.blue,
      ),
      // Paso 2: Días y actividades
      TutorialStep(
        title: 'Actividades por día 📅',
        description:
            'Cada día está organizado con sus actividades. Puedes expandir cada actividad para ver más detalles.',
        icon: Icons.event_note_rounded,
        color: Colors.green,
      ),
      // Paso 3: Ver mapa
      TutorialStep(
        title: 'Ver en el mapa 📍',
        description:
            'Toca el botón del mapa para ver todas las actividades ubicadas geográficamente.',
        icon: Icons.map_rounded,
        color: Colors.orange,
      ),
      // Pasos condicionales según permisos de edición
      if (widget.canEdit) ...[
        TutorialStep(
          title: 'Añadir actividades ➕',
          description:
              'Usa el menú flotante para añadir nuevas actividades, lugares o editar las existentes.',
          icon: Icons.add_circle_rounded,
          color: Colors.purple,
        ),
        TutorialStep(
          title: 'Editar actividades ✏️',
          description:
              'Toca los tres puntos (⋮) de cualquier actividad para editarla, cambiar su duración o eliminarla.',
          icon: Icons.edit_rounded,
          color: Colors.teal,
        ),
        TutorialStep(
          title: 'Organizar días 📋',
          description:
              'Reorganiza las actividades entre días o cambia el orden para optimizar tu itinerario.',
          icon: Icons.swap_vert_rounded,
          color: Colors.indigo,
        ),
      ],
      // Paso: Descargar PDF
      TutorialStep(
        title: 'Descargar PDF 📄',
        description:
            'Descarga tu guía completa como un documento PDF para tener toda la información offline.',
        icon: Icons.download_rounded,
        color: Colors.red,
      ),
      // Paso: Compartir con colaboradores
      TutorialStep(
        title: 'Añadir colaboradores 👥',
        description:
            'Invita amigos para que puedan ver y editar la guía contigo en tiempo real.',
        icon: Icons.group_add_rounded,
        color: Colors.green,
      ),
      // Paso de cierre
      TutorialStep(
        title: '¡Perfecto! 🎉',
        description:
            'Ya conoces todas las funcionalidades. ¡Disfruta planificando tu viaje perfecto!',
        icon: Icons.celebration_rounded,
        color: Colors.amber,
      ),
    ];
    return steps;
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _tutorialSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _scaleController.reset();
      _scaleController.forward();
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _scaleController.reset();
      _scaleController.forward();
    }
  }

  void _skipTutorial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Saltar tutorial?'),
        content: const Text(
          'Puedes volver a ver este tutorial desde el perfil en cualquier momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeTutorial();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Saltar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _completeTutorial() async {
    await GuideTutorialService.markGuideTutorialCompleted();
    if (widget.onTutorialCompleted != null) {
      widget.onTutorialCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _tutorialSteps[_currentStep];

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Fondo oscuro simple
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.7),
          ),

          // Contenido principal del tutorial - centrado
          Center(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icono del paso (más pequeño)
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: currentStep.color.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  currentStep.icon,
                                  size: 30,
                                  color: currentStep.color,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Título (más pequeño)
                              Text(
                                currentStep.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),

                              // Descripción (más compacta)
                              Text(
                                currentStep.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),

                              // Indicador de progreso
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _tutorialSteps.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    width: index == _currentStep ? 24 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: index == _currentStep
                                          ? currentStep.color
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Botones de navegación
                              Column(
                                children: [
                                  // Botón Saltar (solo en la primera pantalla)
                                  if (_currentStep == 0)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: Center(
                                        child: TextButton(
                                          onPressed: _skipTutorial,
                                          child: Text(
                                            'Saltar tutorial',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Botones Anterior y Siguiente
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_currentStep > 0) ...[
                                        Expanded(
                                          child: TextButton(
                                            onPressed: _previousStep,
                                            child: const Text(
                                              'Anterior',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                      ],
                                      Expanded(
                                        flex: _currentStep > 0 ? 1 : 2,
                                        child: ElevatedButton(
                                          onPressed: _nextStep,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: currentStep.color,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                          ),
                                          child: Text(
                                            _currentStep ==
                                                    _tutorialSteps.length - 1
                                                ? '¡Empezar!'
                                                : 'Siguiente',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
