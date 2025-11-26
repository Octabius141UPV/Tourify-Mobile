import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../config/app_colors.dart';
import '../../services/analytics_service.dart';
import '../guides/guide_detail_screen.dart';
import '../../services/guest_guide_service.dart';
import 'welcome_screen.dart';

/// Autocomplete minimalista para Google Places sin bordes feos.
class CustomPlaceAutoComplete extends StatefulWidget {
  final TextEditingController controller;
  final String apiKey;
  final ValueChanged<String> onPlaceSelected; // description

  const CustomPlaceAutoComplete({
    super.key,
    required this.controller,
    required this.apiKey,
    required this.onPlaceSelected,
  });

  @override
  State<CustomPlaceAutoComplete> createState() =>
      _CustomPlaceAutoCompleteState();
}

class _CustomPlaceAutoCompleteState extends State<CustomPlaceAutoComplete> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  List<dynamic> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;

  void _fetchSuggestions(String input) async {
    if (input.trim().isEmpty) {
      _clearSuggestions();
      return;
    }

    final encoded = Uri.encodeComponent(input);
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encoded&language=es&key=${widget.apiKey}&types=(cities)';

    try {
      setState(() {
        _isLoading = true;
      });
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (mounted) {
          setState(() {
            _suggestions = data['predictions'] ?? [];
          });
          _showOverlay();
        }
      } else {
        // error silencioso
        _clearSuggestions();
      }
    } catch (e) {
      _clearSuggestions();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text);
    });
  }

  void _showOverlay() {
    _overlay?.remove();

    final overlay = OverlayEntry(builder: (context) {
      final renderBox = context.findRenderObject() as RenderBox?;
      return Positioned(
        width: renderBox != null
            ? renderBox.size.width
            : MediaQuery.of(context).size.width - 80,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: _suggestions.isEmpty
                  ? const SizedBox()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];
                        final description = item['description'] as String;
                        return ListTile(
                          title: Text(
                            description,
                            style: const TextStyle(fontSize: 16),
                          ),
                          onTap: () {
                            widget.controller.text = description;
                            widget.onPlaceSelected(description);
                            _clearSuggestions();
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      );
    });

    _overlay = overlay;
    Overlay.of(context).insert(overlay);
  }

  void _clearSuggestions() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) {
      setState(() {
        _suggestions = [];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      _onTextChanged(widget.controller.text);
    });
  }

  @override
  void dispose() {
    _overlay?.remove();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        onChanged: (v) {
          // ya maneja el listener
        },
        decoration: InputDecoration(
          hintText: 'Buscar destinos...',
          hintStyle: const TextStyle(fontSize: 18, color: Colors.grey),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          suffixIcon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (widget.controller.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        widget.controller.clear();
                        widget.onPlaceSelected('');
                        _clearSuggestions();
                      },
                      icon: const Icon(
                        Icons.clear,
                        size: 20,
                        color: Colors.grey,
                      ),
                    )
                  : null),
        ),
        style: const TextStyle(fontSize: 18, color: Colors.black87),
      ),
    );
  }
}

class GuestGuideCreationScreen extends StatefulWidget {
  const GuestGuideCreationScreen({super.key});

  @override
  State<GuestGuideCreationScreen> createState() =>
      _GuestGuideCreationScreenState();
}

class _GuestGuideCreationScreenState extends State<GuestGuideCreationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideOffsetAnimation;
  late Animation<double> _scaleAnimation;

  int _currentStep = 0;
  bool _isAnimating = false;

  // 2. Cambiar el total de pasos
  int get _stepsCount => 7; // Aumentado a 7 pasos (agregado paso de intensidad)

  // Datos de la guía que vamos recopilando
  String _destination = '';
  int _selectedDays = 3; // Default a 3 días (máximo 7)
  int _travelers = 2;
  List<String> _travelModes = [];
  List<String> _budgets = []; // Presupuestos seleccionados
  String _travelIntensity = ''; // Intensidad del viaje (tranquilo/intenso)

  // Para el autocompletado de Google Places
  final TextEditingController _destinationController = TextEditingController();

  // CTA de registro eliminado: navegación directa como invitado

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();

    // Analytics: Usuario inicia creación de guía sin registro
    AnalyticsService.trackEvent('guest_guide_creation_started');
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideOffsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutBack));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _buttonAnimationController, curve: Curves.elasticOut),
    );
  }

  void _startAnimations() {
    _animationController.forward();
    _buttonAnimationController.forward();
  }

  void _goBack() async {
    if (_isAnimating) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    setState(() {
      _isAnimating = true;
    });

    // Animar salida
    await _animationController.reverse();

    setState(() {
      _currentStep--;
    });

    // Animar entrada del paso anterior
    await _animationController.forward();

    setState(() {
      _isAnimating = false;
    });
  }

  void _onClosePressed() {
    HapticFeedback.lightImpact();

    // Analytics: Usuario cierra la creación de guía
    AnalyticsService.trackEvent('guest_guide_creation_closed');

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

  void _nextStep() async {
    if (_isAnimating) return;

    // Validar paso actual antes de continuar
    if (!_validateCurrentStep()) {
      _showValidationError();
      return;
    }

    setState(() {
      _isAnimating = true;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    if (_currentStep < _stepsCount - 1) {
      // Animar salida
      await _animationController.reverse();

      setState(() {
        _currentStep++;
      });

      // Animar entrada del nuevo paso
      await _animationController.forward();
    } else {
      // Ir al discover
      await _startGuideCreation();
    }

    setState(() {
      _isAnimating = false;
    });
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Destino
        return _destination.trim().isNotEmpty;
      case 1: // Fechas
        return _selectedDays > 0;
      case 2: // Viajeros
        return _travelers > 0;
      case 3: // Modos de viaje
        return _travelModes.isNotEmpty;
      case 4: // Presupuesto
        return _budgets.isNotEmpty;
      case 5: // Intensidad del viaje
        return _travelIntensity.isNotEmpty;
      case 6: // Listo para crear guía
        return true; // No validar edad/teléfono, se hace en onboarding después
      default:
        return true;
    }
  }

  void _showValidationError() {
    HapticFeedback.mediumImpact();

    String errorMessage = '¡Completa este paso antes de continuar!';

    switch (_currentStep) {
      case 0:
        errorMessage = '¡Por favor ingresa un destino!';
        break;
      case 1:
        errorMessage = '¡Por favor selecciona una opción de fechas!';
        break;
      case 2:
        errorMessage = '¡Por favor indica cuántos viajeros son!';
        break;
      case 3:
        errorMessage = '¡Por favor elige al menos un tipo de viaje!';
        break;
      case 4:
        errorMessage = '¡Por favor selecciona tu rango de presupuesto!';
        break;
      case 5:
        errorMessage = '¡Por favor selecciona la intensidad de tu viaje!';
        break;
      case 6:
        errorMessage = '¡Ya estás listo para crear tu guía!';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startGuideCreation() async {
    // Analytics: Usuario completa configuración sin registro
    AnalyticsService.trackEvent('guest_guide_config_completed', parameters: {
      'destination': _destination,
      'travelers': _travelers,
      'travel_modes': _travelModes,
      'budgets': _budgets,
      'travel_intensity': _travelIntensity,
      'days': _selectedDays,
    });

    // Guardar la configuración temporalmente para el registro posterior
    final temporaryGuide = {
      'destination': _destination,
      'selectedDays': _selectedDays,
      'travelers': _travelers,
      'travelModes': _travelModes,
      'budgets': _budgets,
      'travelIntensity': _travelIntensity,
      'startDate': DateTime.now().toIso8601String(),
      'endDate': DateTime.now()
          .add(Duration(days: _selectedDays - 1))
          .toIso8601String(),
    };

    // Guardar en GuestGuideService para que esté disponible durante el onboarding
    await GuestGuideService.saveTemporaryGuide(temporaryGuide);

    // Crear una guía temporal y navegar directamente al GuideDetailScreen (sin CTA de registro)
    if (mounted) {
      final tempGuideId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final guideTitle = 'Guía para $_destination';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GuideDetailScreen(
            guideId: tempGuideId,
            guideTitle: guideTitle,
          ),
          settings: RouteSettings(
            arguments: {
              'guideId': tempGuideId,
              'guideTitle': guideTitle,
              'isPublic': false,
              'guestConfig': temporaryGuide,
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Barra de progreso
              _buildProgressBar(),
              // Contenido principal
              Expanded(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideOffsetAnimation,
                        child: _buildCurrentStep(),
                      ),
                    );
                  },
                ),
              ),
              // Botón continuar
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationInput(String? googleMapsApiKey) {
    if (googleMapsApiKey == null || googleMapsApiKey.isEmpty) {
      return _buildSimpleDestinationInput();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPlaceAutoComplete(
        controller: _destinationController,
        apiKey: googleMapsApiKey,
        onPlaceSelected: (desc) {
          setState(() {
            _destination = desc;
          });
        },
      ),
    );
  }

  Widget _buildSimpleDestinationInput() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: TextField(
            controller: _destinationController,
            onChanged: (value) {
              setState(() {
                _destination = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Escribe tu destino (ej: Madrid, París, Roma)...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              filled: false,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.primary,
                size: 24,
              ),
              suffixIcon: _destination.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _destination = '';
                          _destinationController.clear();
                        });
                      },
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.grey,
                        size: 20,
                      ),
                    )
                  : null,
            ),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ),
        if (_destination.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Divider(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Destinos populares en Europa:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Madrid, España',
                    'París, Francia',
                    'Roma, Italia',
                    'Londres, Reino Unido',
                    'Barcelona, España',
                    'Berlín, Alemania',
                    'Ámsterdam, Países Bajos',
                    'Lisboa, Portugal',
                  ]
                      .map((city) => GestureDetector(
                            onTap: () {
                              FocusScope.of(context)
                                  .unfocus(); // Cierra el teclado y fuerza rebuild
                              setState(() {
                                _destination = city;
                                _destinationController.text = city;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                city,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón de retroceso o cerrar
              if (_currentStep > 0)
                GestureDetector(
                  onTap: _goBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _onClosePressed,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              Text(
                'Paso ${_currentStep + 1} de $_stepsCount',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${((_currentStep + 1) / _stepsCount * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _stepsCount,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildDestinationStep();
      case 1:
        return _buildDatesStep();
      case 2:
        return _buildTravelersStep();
      case 3:
        return _buildTravelModesStep();
      case 4:
        return _buildBudgetStep();
      case 5:
        return _buildIntensityStep();
      case 6:
        return _buildReadyStep();
      default:
        return Container();
    }
  }

  Widget _buildDestinationStep() {
    final googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

    // No mostrar error al usuario, simplemente usar el input simple
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Icon(
              Icons.place,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            const Text(
              '¿A dónde viajas? ✈️',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Busca tu destino y te ayudamos\na crear la guía perfecta',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _buildDestinationInput(googleMapsApiKey),
            ),
            const SizedBox(height: 16),
            // CTA de registro eliminado
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getDurationText(int days) {
    if (days == 1) {
      return 'Un día';
    } else if (days == 2) {
      return 'Fin de semana';
    } else if (days >= 3 && days <= 4) {
      return 'Escapada corta';
    } else if (days == 7) {
      return 'Una semana';
    } else if (days >= 8 && days <= 10) {
      return 'Semana larga';
    } else if (days == 14) {
      return 'Dos semanas';
    } else if (days >= 21 && days <= 31) {
      return 'Un mes';
    } else {
      return 'Viaje personalizado';
    }
  }

  Widget _buildDatesStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_month,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 30),
            const Text(
              '¿Cuántos días durará tu viaje? 📅',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Selecciona la duración de tu viaje',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            // Contenedor para la rueda de selección
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    _getDurationText(_selectedDays),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: _selectedDays - 1,
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _selectedDays = index + 1;
                        });
                      },
                      children: List.generate(7, (index) {
                        final days = index + 1;
                        return Center(
                          child: Text(
                            '$days ${days == 1 ? 'día' : 'días'}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelersStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.group,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 30),
          const Text(
            '¿Cuántos viajeros? 👥',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Esto nos ayuda a recomendar\nactividades más precisas',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _travelers > 1
                      ? () {
                          setState(() {
                            _travelers--;
                          });
                        }
                      : null,
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: _travelers > 1 ? AppColors.primary : Colors.grey,
                    size: 32,
                  ),
                ),
                Text(
                  '$_travelers',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  onPressed: _travelers < 10
                      ? () {
                          setState(() {
                            _travelers++;
                          });
                        }
                      : null,
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: _travelers < 10 ? AppColors.primary : Colors.grey,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _travelers == 1 ? '1 viajero' : '$_travelers viajeros',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelModesStep() {
    final modes = [
      {'emoji': '🏛️', 'title': 'Cultural', 'desc': 'Historia, museos, arte'},
      {'emoji': '🎉', 'title': 'Fiesta', 'desc': 'Vida nocturna, eventos'},
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 0),
      child: Column(
        children: [
          const Text(
            '¿Qué te gusta hacer? 🎯',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Puedes elegir varias opciones',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              if (_travelModes.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_travelModes.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              children: modes.asMap().entries.map((entry) {
                final index = entry.key;
                final mode = entry.value;
                final isSelected = _travelModes.contains(mode['title']);
                final isLast = index == modes.length - 1;

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            _travelModes.remove(mode['title']!);
                          } else {
                            _travelModes.add(mode['title']!);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withOpacity(0.3),
                            width: isSelected ? 4 : 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              mode['emoji']!,
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode['title']!,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode['desc']!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isSelected
                                          ? Colors.grey[600]
                                          : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected) ...[
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStep() {
    final budgets = [
      {'emoji': '💰', 'title': 'Económico', 'desc': 'Menos de 50€/día'},
      {'emoji': '💳', 'title': 'Moderado', 'desc': '50-150€/día'},
      {'emoji': '🏆', 'title': 'Premium', 'desc': '150-300€/día'},
      {'emoji': '👑', 'title': 'Lujo', 'desc': 'Más de 300€/día'},
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 0),
      child: Column(
        children: [
          const Text(
            '¿Cuál es tu presupuesto? 💰',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Puedes elegir varias opciones',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              if (_budgets.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_budgets.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: budgets.length,
              itemBuilder: (context, index) {
                final budget = budgets[index];
                final isSelected = _budgets.contains(budget['title']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isSelected) {
                          _budgets.remove(budget['title']!);
                        } else {
                          _budgets.add(budget['title']!);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.3),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            budget['emoji']!,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  budget['title']!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  budget['desc']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected
                                        ? Colors.grey[600]
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityStep() {
    final intensities = [
      {'emoji': '🦥', 'title': 'Relajado', 'desc': '3 actividades por día'},
      {'emoji': '🚶', 'title': 'Moderado', 'desc': '5 actividades por día'},
      {'emoji': '🏃', 'title': 'Activo', 'desc': '7 actividades por día'},
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 0),
      child: Column(
        children: [
          const Text(
            '¿Cuántas actividades por día? 📅',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige cuántas actividades quieres hacer cada día',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: intensities.asMap().entries.map((entry) {
                  final index = entry.key;
                  final intensity = entry.value;
                  final isSelected = _travelIntensity == intensity['title'];
                  final isLast = index == intensities.length - 1;

                  return Container(
                    height: 120,
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _travelIntensity = intensity['title']!;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withOpacity(0.3),
                            width: isSelected ? 4 : 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              intensity['emoji']!,
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    intensity['title']!,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    intensity['desc']!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isSelected
                                          ? Colors.grey[600]
                                          : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected) ...[
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Icon(
              Icons.rocket_launch,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 30),
            const Text(
              '¡Todo listo!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vamos a crear tu guía personalizada\n',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('📍 Destino', _destination),
                  const SizedBox(height: 12),
                  _buildSummaryRow('📅 Duración',
                      '$_selectedDays ${_selectedDays == 1 ? 'día' : 'días'}'),
                  const SizedBox(height: 12),
                  _buildSummaryRow('👥 Viajeros', '$_travelers personas'),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                      '🎯 Intereses', '${_travelModes.length} tipos'),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                      '💰 Presupuesto', '${_budgets.length} rangos'),
                  const SizedBox(height: 12),
                  _buildSummaryRow('📅 Actividades/día', _travelIntensity),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    final isLastStep = _currentStep == _stepsCount - 1;
    final canContinue = _validateCurrentStep();

    return Container(
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: _buttonAnimationController,
        builder: (context, child) {
          return ScaleTransition(
            scale: _scaleAnimation,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canContinue && !_isAnimating ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canContinue ? Colors.white : Colors.grey[400],
                  foregroundColor:
                      canContinue ? AppColors.primary : Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: canContinue ? 8 : 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isAnimating)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    else
                      Text(
                        isLastStep ? '¡Crear mi guía!' : 'Continuar',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (!_isAnimating && !isLastStep) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
