import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:tourify_flutter/config/app_colors.dart';
import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:tourify_flutter/services/auth_service.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io' show Platform;

import 'package:tourify_flutter/services/guest_guide_service.dart';
import 'package:tourify_flutter/services/guide_service.dart';
import 'package:tourify_flutter/services/user_service.dart';
import 'package:tourify_flutter/services/onboarding_service.dart';
import 'package:tourify_flutter/services/local_user_prefs.dart';
import 'package:tourify_flutter/screens/main/home_screen.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:tourify_flutter/screens/auth/login_screen.dart';
import 'package:tourify_flutter/data/mock_activities.dart';
import 'package:tourify_flutter/config/debug_config.dart';

class InteractiveOnboardingScreen extends StatefulWidget {
  const InteractiveOnboardingScreen({super.key});

  @override
  State<InteractiveOnboardingScreen> createState() =>
      _InteractiveOnboardingScreenState();
}

class _InteractiveOnboardingScreenState
    extends State<InteractiveOnboardingScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideOffsetAnimation;
  late Animation<double> _scaleAnimation;

  int _currentStep = 0;
  int _totalSteps = 4; // por defecto: Registro, SMS, Edad, Objetivo
  bool _isAnimating = false;

  // Datos del usuario
  String _userName = '';
  String _userPhone = '';
  int _userAge = 25;
  FixedExtentScrollController? _ageController;
  int _citiesGoal = 0;

  // Variables de registro
  bool _isRegistering = false;
  String? _registerError;

  // Variables para SMS
  String? _verificationId;
  bool _isVerifyingPhone = false;
  String _smsCode = '';
  String? _phoneVerificationError;
  // Omitir SMS deshabilitado

  // Variables para Face ID
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricAvailable = false;
  bool _isBiometricLoading = false;

  // Control de estado
  bool _showRegistrationOptions = true;
  // Estado de registro

  // Ya no se permite omitir la verificación por SMS
  // Marca si el segundo factor quedó realmente enrolado en Firebase
  bool _secondFactorEnrolled = false;

  // Deep link: recolectar preferencias sin pasar por guest_guide_creation_screen
  bool _isDeepLinkOnboarding = false;
  final List<String> _prefSelectedModes = [];
  final List<String> _prefBudgets = [];
  String _prefIntensity = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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

    _startAnimations();
    _checkBiometricAvailability();
    _checkUserExistence();

    // Controlador para selector de edad, con selección inicial
    _ageController = FixedExtentScrollController(initialItem: _userAge - 13);

    // Detectar si venimos de deeplink (hay pendingJoin)
    _isDeepLinkOnboarding = NavigationService.hasPendingJoin;
    if (_isDeepLinkOnboarding) {
      // Añadir 3 pasos: gustos, presupuesto e intensidad (sin duración)
      _totalSteps = 7; // 0..6 → (4 gustos, 5 presupuesto, 6 intensidad)
    }
  }

  void _startAnimations() {
    _animationController.forward();
    _buttonAnimationController.forward();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      setState(() {
        _isBiometricAvailable =
            isAvailable && isDeviceSupported && availableBiometrics.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _isBiometricAvailable = false;
      });
    }
  }

  Future<void> _checkUserExistence() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        setState(() {
          _showRegistrationOptions = true;
          // no auth → sin nombre
          _userName = '';
        });
        return;
      }

      // Autenticado: precargar nombre desde caché local (instantáneo)
      String? cachedName = await LocalUserPrefs.getDisplayName();
      if (cachedName != null && cachedName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _showRegistrationOptions = false;
            _userName = cachedName!;
          });
        }
      } else {
        // Fallback inmediato a FirebaseAuth o email
        final immediate = currentUser.displayName ??
            (currentUser.email?.split('@').first ?? 'Usuario');
        if (mounted) {
          setState(() {
            _showRegistrationOptions = false;
            _userName = immediate;
          });
        }
      }

      // Luego intenta refrescar desde Firestore en segundo plano y cachear
      try {
        final data = await UserService.getUserData(currentUser.uid);
        final remoteName = (data?['name'] as String?) ??
            (data?['displayName'] as String?) ?? _userName;
        if (remoteName.isNotEmpty) {
          await LocalUserPrefs.saveBasicProfile(displayName: remoteName);
          if (mounted) {
            setState(() {
              _userName = remoteName;
            });
          }
        }
      } catch (_) {}
    } catch (e) {
      setState(() {
        _showRegistrationOptions = true;
      });
    }
  }

  Future<void> _nextStep() async {
    if (_isAnimating) return;

    if (!_validateCurrentStep()) {
      _showValidationError();
      return;
    }

    setState(() {
      _isAnimating = true;
    });

    HapticFeedback.lightImpact();

    // FLUJO FORZADO PASO A PASO
    await _animationController.reverse();

    if (_currentStep == 0) {
      // FORZAR paso 0 → 1
      setState(() {
        _currentStep = 1;
      });
      await _animationController.forward();

      // Intentar enviar SMS solo si NO estamos en bypass (simulador/debug)
      if (!_shouldBypassSMS()) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _sendSmsVerification();
      }
    } else if (_currentStep == 1) {
      // VERIFICAR EL PIN SMS CORRECTAMENTE (O HACER BYPASS)
      print('🎯 BOTÓN CONTINUAR presionado en paso SMS con código: $_smsCode');

      // 🔧 BYPASS PARA SIMULADOR/DEBUG
      if (_shouldBypassSMS()) {
        DebugConfig.debugPrint(
            'BYPASS SMS ACTIVADO - Saltando verificación para simulador/debug');
        setState(() {
          _secondFactorEnrolled = true;
          _phoneVerificationError = null;
          _currentStep = 2;
        });
        await _animationController.forward();
        // Importante: permitir siguientes interacciones
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        } else {
          _isAnimating = false;
        }
        return;
      }

      if (_smsCode.length != 6) {
        print('❌ Código muy corto: ${_smsCode.length} dígitos');
        setState(() {
          _phoneVerificationError = 'Debes ingresar el código SMS de 6 dígitos';
          _isAnimating = false; // IMPORTANTE: Restablecer animación
        });
        await _animationController.forward();
        return;
      }

      // VERIFICAR EL CÓDIGO CON FIREBASE
      if (_verificationId != null) {
        // Limpiar error previo antes de verificar
        setState(() {
          _phoneVerificationError = null;
        });

        await _verifySmsCode();

        // Solo continuar si NO hay error
        if (_phoneVerificationError == null) {
          // PIN CORRECTO - Avanzar al siguiente paso
          setState(() {
            _currentStep = 2;
          });
          await _animationController.forward();
        } else {
          // PIN INCORRECTO - Mostrar error y permitir reintentar
          setState(() {
            _isAnimating =
                false; // IMPORTANTE: Restablecer para permitir otro intento
          });
          await _animationController.forward();
          return;
        }
      } else {
        // Si no hay verificationId, mostrar error - NO se puede continuar sin verificación
        print('❌ No hay verificationId - Error enviando SMS');
        setState(() {
          _phoneVerificationError =
              'Error enviando SMS. Intenta reenviar el código.';
          _isAnimating = false;
        });
        await _animationController.forward();
        return;
      }
    } else if (_currentStep == 2) {
      // FORZAR paso 2 → 3
      setState(() {
        _currentStep = 3;
      });
      await _animationController.forward();
    } else if (_currentStep == 3) {
      if (_isDeepLinkOnboarding) {
        setState(() {
          _currentStep = 4; // gustos
        });
        await _animationController.forward();
      } else {
        // COMPLETAR onboarding normal
        await _animationController.forward();
        await _completeOnboarding();
        return;
      }
    } else if (_currentStep == 4) {
      setState(() {
        _currentStep = 5; // presupuesto
      });
      await _animationController.forward();
    } else if (_currentStep == 5) {
      // Paso presupuesto → intensidad si deeplink
      if (_isDeepLinkOnboarding) {
        setState(() {
          _currentStep = 6; // intensidad
        });
        await _animationController.forward();
      } else {
        await _animationController.forward();
        await _completeOnboarding();
        return;
      }
    } else if (_currentStep == 6) {
      // Completar tras intensidad
      await _animationController.forward();
      await _completeOnboarding();
      return;
    }

    setState(() {
      _isAnimating = false;
    });
  }

  // Eliminado: no se permite saltar verificación por SMS

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Registro + teléfono
        // En bypass (simulador/debug), permitir avanzar solo con estar autenticado
        if (_shouldBypassSMS()) {
          return AuthService.isAuthenticated;
        }
        return AuthService.isAuthenticated &&
            _userPhone.isNotEmpty &&
            _isValidPhoneNumber(_userPhone);
      case 1: // Verificación SMS
        // En bypass (simulador/debug), permitir continuar directamente
        if (_shouldBypassSMS()) {
          return true;
        }
        return _secondFactorEnrolled ||
            (_smsCode.length == 6 &&
                _verificationId != null &&
                !_isVerifyingPhone);
      case 2: // Edad
        return _userAge >= 13 && _userAge <= 100;
      case 3: // Objetivo
        return _citiesGoal >= 1 && _citiesGoal <= 4;
      case 4: // Gustos
        return _prefSelectedModes.isNotEmpty;
      case 5: // Presupuesto
        return _prefBudgets.isNotEmpty;
      case 6: // Intensidad
        return !_isDeepLinkOnboarding || _prefIntensity.isNotEmpty;
      default:
        return true;
    }
  }

  /// 🔧 Determina si se debe hacer bypass del SMS
  /// Para simulador o modo debug
  bool _shouldBypassSMS() {
    return DebugConfig.shouldBypassSMS();
  }

  bool _isValidPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('+')) {
      cleanPhone = '+34$cleanPhone';
    }
    if (cleanPhone.length < 9 || cleanPhone.length > 15) {
      return false;
    }
    RegExp phoneRegex = RegExp(r'^\+?[0-9]+$');
    return phoneRegex.hasMatch(cleanPhone);
  }

  String _formatPhoneWithPrefix(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('+')) {
      return '+34$cleanPhone';
    }
    return cleanPhone;
  }

  void _showValidationError() {
    HapticFeedback.mediumImpact();
    String errorMessage = '¡Elige una opción antes de continuar!';

    if (_currentStep == 0) {
      if (!AuthService.isAuthenticated) {
        errorMessage = '¡Por favor regístrate con Google o Apple primero!';
      } else if (!_isValidPhoneNumber(_userPhone)) {
        errorMessage = '¡Por favor ingresa un número de teléfono válido!';
      }
    } else if (_currentStep == 1) {
      if (_verificationId == null) {
        errorMessage = '¡Error enviando SMS! Reenvía el código primero.';
      } else if (_smsCode.length != 6) {
        errorMessage = '¡Ingresa el código SMS de 6 dígitos!';
      } else {
        errorMessage =
            '¡El código SMS es incorrecto! Verifica y vuelve a intentar.';
      }
    } else if (_currentStep == 2) {
      if (_userAge < 9) {
        errorMessage = '¡Debes tener al menos 9 años para usar Tourify!';
      } else if (_userAge > 100) {
        errorMessage = '¡Por favor ingresa una edad válida!';
      }
    } else if (_currentStep == 3) {
      if (_citiesGoal < 1) {
        errorMessage = '¡Debes seleccionar una opción de racha!';
      }
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

  Future<void> _completeOnboarding() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        await UserService.updateUserData(
          currentUser.uid,
          {
            'phone': _formatPhoneWithPrefix(_userPhone),
            'age': _userAge,
            'citiesGoal': _citiesGoal,
            'hasCompletedOnboarding': true,
            'updatedAt': DateTime.now().toIso8601String(),
            'hasSecondFactor': true,
            'secondFactorType': 'sms',
            'secondFactorPhone': _formatPhoneWithPrefix(_userPhone),
            'secondFactorSetupDate': DateTime.now().toIso8601String(),
            if (_isDeepLinkOnboarding) 'travel_styles': _prefSelectedModes,
            if (_isDeepLinkOnboarding) 'budgets': _prefBudgets,
            if (_isDeepLinkOnboarding) 'travelIntensity': _prefIntensity,
          },
        );
      }

      final userData = {
        'name': _userName,
        'phone': _formatPhoneWithPrefix(_userPhone),
        'age': _userAge,
        'citiesGoal': _citiesGoal,
        'language': 'es',
        'hasSecondFactor': true,
        'secondFactorType': 'sms',
        if (_isDeepLinkOnboarding) 'travel_styles': _prefSelectedModes,
        if (_isDeepLinkOnboarding) 'budgets': _prefBudgets,
        if (_isDeepLinkOnboarding) 'travelIntensity': _prefIntensity,
      };

      AnalyticsService.trackEvent('onboarding_completed', parameters: userData);
      await OnboardingService.markOnboardingCompleted();
      await _processTemporaryGuestGuide();
      // Procesar deeplink pendiente (join) si existe
      await NavigationService.processPendingJoinIfAny();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        // Intentar procesar join pendiente incluso si falló parte del onboarding
        try {
          await NavigationService.processPendingJoinIfAny();
        } catch (_) {}
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _buttonAnimationController.dispose();
    try {
      _ageController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildProgressBar(),
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
              _buildContinueButton(),
            ],
          ),
        ),
      ),
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
              Text(
                'Paso ${_currentStep + 1} de $_totalSteps',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${((_currentStep + 1) / _totalSteps * 100).round()}%',
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
              value: (_currentStep + 1) / _totalSteps,
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
        return _buildRegistrationAndPhoneStep();
      case 1:
        return _buildSmsVerificationStep();
      case 2:
        return _buildAgeStep();
      case 3:
        return _buildCitiesGoalStep();
      case 4:
        return _buildPrefModesStep();
      case 5:
        return _buildPrefBudgetStep();
      case 6:
        return _buildPrefIntensityStep();
      default:
        return Container();
    }
  }

  Widget _buildPrefModesStep() {
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
              if (_prefSelectedModes.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_prefSelectedModes.length}',
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
          Column(
            children: modes.map((mode) {
              final isSelected = _prefSelectedModes.contains(mode['title']);
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSelected) {
                        _prefSelectedModes.remove(mode['title']!);
                      } else {
                        _prefSelectedModes.add(mode['title']!);
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
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 32,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefBudgetStep() {
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
              if (_prefBudgets.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_prefBudgets.length}',
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
                final isSelected = _prefBudgets.contains(budget['title']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isSelected) {
                          _prefBudgets.remove(budget['title']!);
                        } else {
                          _prefBudgets.add(budget['title']!);
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

  Widget _buildPrefIntensityStep() {
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
            '¿Qué intensidad prefieres? 📅',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige cuántas actividades quieres hacer cada día',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: intensities.length,
              itemBuilder: (context, index) {
                final intensity = intensities[index];
                final isSelected = _prefIntensity == intensity['title'];
                return Container(
                  height: 120,
                  margin: EdgeInsets.only(
                      bottom: index == intensities.length - 1 ? 0 : 16),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _prefIntensity = intensity['title']!;
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
                          Text(intensity['emoji']!,
                              style: const TextStyle(fontSize: 48)),
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
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppColors.primary, size: 32),
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

  Widget _buildRegistrationAndPhoneStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text(
              '¡Registrate en Tourify! 🎉',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 12),
            const Text(
              'Crea tu cuenta para guardar tus guías de viaje',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 32),
            // Si NO está autenticado, mostrar opciones de registro
            if (!AuthService.isAuthenticated && _showRegistrationOptions) ...[
              _buildRegistrationButtons(),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '¡Hola $_userName! 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ingresa tu número de teléfono:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        '+34',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '612 345 678',
                          hintStyle: TextStyle(color: Colors.grey),
                          contentPadding: EdgeInsets.all(16),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _userPhone = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_userPhone.isNotEmpty &&
                  !_isValidPhoneNumber(_userPhone)) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Por favor ingresa un número válido',
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            if (_registerError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade800,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade600, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _registerError!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.visible,
                            maxLines: 4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const LoginScreen(),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                return FadeTransition(
                                    opacity: animation, child: child);
                              },
                              transitionDuration:
                                  const Duration(milliseconds: 300),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_outline,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 30),
            const Text(
              '¿Cuál es tu edad? 🎂',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 12),
            const Text(
              'Necesitamos tu edad para personalizar tu experiencia',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 40),
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
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Selecciona tu edad:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: ListWheelScrollView(
                        controller: _ageController ??=
                            FixedExtentScrollController(
                                initialItem: (_userAge - 13).clamp(0, 87)),
                        itemExtent: 50,
                        diameterRatio: 1.5,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _userAge = index + 13;
                          });
                        },
                        children: List.generate(88, (index) {
                          final age = index + 13;
                          final isSelected = _userAge == age;
                          return Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$age años',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_userAge > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  'Edad seleccionada: $_userAge años',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCitiesGoalStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 30),
            const Text(
              '¡Establece tu objetivo! 🎯',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 12),
            const Text(
              '¿Qué tipo de viajero eres?\n\nElige tu ritmo de viaje para mantener una racha como en Duolingo',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 40),
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
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Ritmo de viaje:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: ListWheelScrollView(
                        itemExtent: 50,
                        diameterRatio: 1.5,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _citiesGoal = index + 1;
                          });
                        },
                        children: [
                          Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _citiesGoal == 1
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '1 cada dos meses',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: _citiesGoal == 1
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                          Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _citiesGoal == 2
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '1 al mes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: _citiesGoal == 2
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                          Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _citiesGoal == 3
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '2 al mes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: _citiesGoal == 3
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                          Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _citiesGoal == 4
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '4 al mes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: _citiesGoal == 4
                                    ? Colors.white
                                    : Colors.grey[700],
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
            if (_citiesGoal > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.blue, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Objetivo establecido',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getCitiesGoalText(_citiesGoal),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🔥 ¡Racha iniciada!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getCitiesGoalText(int goal) {
    switch (goal) {
      case 1:
        return '1 ciudad cada dos meses';
      case 2:
        return '1 ciudad al mes';
      case 3:
        return '2 ciudades al mes';
      case 4:
        return '4 ciudades al mes';
      default:
        return 'Objetivo no definido';
    }
  }

  Widget _buildSmsVerificationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
              height: 40), // Espacio extra arriba para cuando hay teclado

          const Icon(
            Icons.phone_android,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 24),

          Text(
            _shouldBypassSMS()
                ? '🔧 Modo Desarrollo (SMS desactivado)'
                : _verificationId != null
                    ? 'Verifica tu móvil 📱'
                    : '⏳ Enviando código SMS...',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          Text(
            _shouldBypassSMS()
                ? 'SMS desactivado para simulador - Pulsa "Omitir ahora"'
                : _verificationId != null
                    ? 'Código enviado a ${_formatPhoneWithPrefix(_userPhone)}'
                    : 'Enviando código a ${_formatPhoneWithPrefix(_userPhone)}...',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          // Campo para ingresar el código SMS (o bypass info)
          if (_shouldBypassSMS())
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
              ),
              child: const Column(
                children: [
                  Icon(Icons.developer_mode, color: Colors.orange, size: 48),
                  SizedBox(height: 12),
                  Text(
                    '🔧 MODO DESARROLLO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'SMS desactivado para simulador\nPulsa "Omitir ahora" para avanzar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
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
              child: TextField(
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '123456',
                  hintStyle: TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.all(16),
                  counterText: '',
                ),
                onChanged: (value) {
                  setState(() {
                    _smsCode = value;
                  });
                },
              ),
            ),

          const SizedBox(height: 16),

          // Botón para reenviar código (oculto en modo bypass)
          if (!_shouldBypassSMS())
            TextButton(
              onPressed: !_isVerifyingPhone
                  ? () async {
                      await _sendSmsVerification();
                    }
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.8),
              ),
              child: const Text(
                'Reenviar código',
                style: TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Enlace "Omitir ahora" visible solo en modo bypass (simulador/debug)
          if (_shouldBypassSMS())
            TextButton(
              onPressed: () async {
                DebugConfig.debugPrint(
                    'BYPASS SMS ACTIVADO - Omitiendo verificación (enlace)');
                setState(() {
                  _secondFactorEnrolled = true;
                  _phoneVerificationError = null;
                  _currentStep = 2;
                });
                await _animationController.forward();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Omitir ahora',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

          if (_phoneVerificationError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _phoneVerificationError!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await _cleanupAccountDueToPhoneConflict();
                  } catch (_) {}
                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (_) {}
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const LoginScreen(),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ir al Login',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],

          if (_isVerifyingPhone) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white),
          ],

          const SizedBox(height: 100), // Espacio extra abajo para el teclado
        ],
      ),
    );
  }

  Future<void> _sendSmsVerification() async {
    if (!AuthService.isValidPhoneNumber(_userPhone)) {
      setState(() {
        _phoneVerificationError = 'Número de teléfono no válido';
        _isVerifyingPhone = false;
      });
      return;
    }

    final formattedPhone = AuthService.formatPhoneNumber(_userPhone);

    // Pre-chequeo: evitar usar un teléfono ya asociado a otra cuenta
    try {
      final currentUser = AuthService.currentUser;
      final existsInOtherAccount = await _isPhoneAlreadyInUse(formattedPhone,
          excludeUid: currentUser?.uid);
      if (existsInOtherAccount) {
        await _cleanupAccountDueToPhoneConflict();
        if (mounted) {
          setState(() {
            _phoneVerificationError =
                'Este número ya está asociado a otra cuenta. Inicia sesión con esa cuenta o usa otro número.';
            _isVerifyingPhone = false;
          });
        }
        return;
      }
    } catch (_) {
      // Ignorar errores del pre-chequeo y continuar; onVerificationFailed cubrirá conflictos
    }

    setState(() {
      _isVerifyingPhone = true;
      _phoneVerificationError = null;
    });

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        setState(() {
          _phoneVerificationError = 'Debes iniciar sesión primero';
          _isVerifyingPhone = false;
        });
        return;
      }

      final result = await AuthService.setupSMSAsSecondFactor(
        phoneNumber: formattedPhone,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _handlePhoneVerificationSuccess(credential);
          } catch (e) {
            if (mounted) {
              setState(() {
                _phoneVerificationError =
                    'Error en verificación automática: $e';
                _isVerifyingPhone = false;
              });
            }
          }
        },
        onVerificationFailed: (FirebaseAuthException e) async {
          if (mounted) {
            if (e.code == 'credential-already-in-use' ||
                e.code == 'phone-already-in-use' ||
                (e.message?.toLowerCase().contains('already in use') ??
                    false)) {
              await _cleanupAccountDueToPhoneConflict();
              setState(() {
                _phoneVerificationError =
                    'Este número ya está asociado a otra cuenta. Inicia sesión con esa cuenta o usa otro número.';
                _isVerifyingPhone = false;
              });
            } else {
              setState(() {
                _phoneVerificationError =
                    AuthService.getFirebaseAuthErrorMessage(e.code);
                _isVerifyingPhone = false;
              });
            }
          }
        },
        onCodeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isVerifyingPhone = false;
            });
          }
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isVerifyingPhone = false;
            });
          }
        },
      );

      if (!result['success']) {
        if (mounted) {
          setState(() {
            _phoneVerificationError =
                'Error configurando SMS: ${result['error']}';
            _isVerifyingPhone = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phoneVerificationError = 'Error enviando SMS: $e';
          _isVerifyingPhone = false;
        });
      }
    }
  }

  /// Verifica en Firestore si el teléfono ya está en uso por otra cuenta
  Future<bool> _isPhoneAlreadyInUse(String formattedPhone,
      {String? excludeUid}) async {
    try {
      final users = FirebaseFirestore.instance.collection('users');
      // Buscar coincidencia en 'phone'
      final q1 =
          await users.where('phone', isEqualTo: formattedPhone).limit(1).get();
      if (q1.docs.isNotEmpty) {
        final uid = q1.docs.first.id;
        if (excludeUid == null || uid != excludeUid) return true;
      }
      // Buscar coincidencia en 'secondFactorPhone'
      final q2 = await users
          .where('secondFactorPhone', isEqualTo: formattedPhone)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        final uid = q2.docs.first.id;
        if (excludeUid == null || uid != excludeUid) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Limpia cuenta creada en esta sesión cuando el teléfono ya está en uso
  Future<void> _cleanupAccountDueToPhoneConflict() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      // Intento robusto: pedir al backend borrar cuenta + datos (si hay token)
      try {
        final ok = await AuthService.deleteAccount();
        if (ok) {
          return;
        }
      } catch (_) {}

      // Fallback: borrar documento en Firestore si existe
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (_) {}

      // Borrar usuario de Auth o cerrar sesión si requiere reauth
      try {
        await user.delete();
      } catch (_) {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _verifySmsCode() async {
    print(
        '🔐 VERIFICANDO SMS: $_smsCode con VerificationId: ${_verificationId?.substring(0, 20)}...');

    if (_verificationId == null) {
      print('❌ No hay verificationId disponible');
      setState(() {
        _phoneVerificationError = 'Error: No se ha enviado ningún código SMS';
        _isVerifyingPhone = false;
      });
      return;
    }

    if (_smsCode.length != 6) {
      print('❌ Código SMS incompleto: ${_smsCode.length} dígitos');
      setState(() {
        _phoneVerificationError = 'El código debe tener exactamente 6 dígitos';
        _isVerifyingPhone = false;
      });
      return;
    }

    setState(() {
      _isVerifyingPhone = true;
      _phoneVerificationError = null;
    });

    try {
      print('📡 Llamando AuthService.verifySMSAsSecondFactor...');
      final result = await AuthService.verifySMSAsSecondFactor(
        verificationId: _verificationId!,
        smsCode: _smsCode,
      );

      print('📡 Resultado de verificación: $result');

      if (result['success']) {
        print('✅ SMS VERIFICADO CORRECTAMENTE!');

        // Registrar configuración exitosa de 2FA
        AnalyticsService.trackEvent('second_factor_configured', parameters: {
          'factor_type': 'sms',
          'phone_number': _formatPhoneWithPrefix(_userPhone),
          'setup_stage': 'onboarding',
          'timestamp': DateTime.now().toIso8601String(),
        });

        setState(() {
          _isVerifyingPhone = false;
          _phoneVerificationError = null;
          _secondFactorEnrolled = true;
        });
      } else {
        print('❌ SMS INCORRECTO: ${result['error']}');
        setState(() {
          _phoneVerificationError =
              'Código SMS incorrecto. Verifica e intenta de nuevo.';
          _isVerifyingPhone = false;
        });
      }
    } catch (e) {
      print('❌ EXCEPCIÓN durante verificación: $e');
      setState(() {
        _phoneVerificationError =
            'Error verificando el código. Intenta de nuevo.';
        _isVerifyingPhone = false;
      });
    }
  }

  Future<void> _handlePhoneVerificationSuccess(
      PhoneAuthCredential credential) async {
    try {
      final result = await AuthService.enrollSecondFactorWithCredential(
        credential: credential,
      );
      if (mounted) {
        setState(() {
          _isVerifyingPhone = false;
          if (result['success'] == true) {
            _phoneVerificationError = null;
            _secondFactorEnrolled = true;
          } else {
            _phoneVerificationError =
                (result['error']?.toString() ?? 'Error en enrolamiento');
            _secondFactorEnrolled = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingPhone = false;
          _phoneVerificationError = 'Error en verificación automática: $e';
          _secondFactorEnrolled = false;
        });
      }
    }
  }

  Widget _buildContinueButton() {
    final canContinue = _validateCurrentStep();
    final isLastStep = _currentStep == _totalSteps - 1;

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
                onPressed: canContinue ? () async => await _nextStep() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: canContinue ? 4 : 0,
                ),
                child: Text(
                  isLastStep ? 'Comenzar a viajar' : 'Continuar',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _processTemporaryGuestGuide() async {
    try {
      final temporaryGuide = await GuestGuideService.getTemporaryGuide();

      if (temporaryGuide != null) {
        await GuideService.createGuide(
          destination: temporaryGuide['destination'],
          startDate: DateTime.parse(temporaryGuide['startDate']),
          endDate: DateTime.parse(temporaryGuide['endDate']),
          selectedActivities: [],
          travelers: (temporaryGuide['adults'] ?? 1) +
              (temporaryGuide['children'] ?? 0),
          travelModes: List<String>.from(temporaryGuide['travelModes'] ?? []),
        );

        await GuestGuideService.clearTemporaryGuide();
      }
    } catch (e) {
      // Error procesando guía temporal
    }
  }

  Widget _buildRegistrationButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: !_isRegistering ? _registerWithGoogle : null,
            icon: _isRegistering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Image.asset(
                    'assets/images/google_logo.png',
                    width: 20,
                    height: 20,
                  ),
            label: Text(
              _isRegistering ? 'Registrando...' : 'Registrarse con Google',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: !_isRegistering ? 2 : 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: !_isRegistering ? _registerWithApple : null,
            icon: _isRegistering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.apple, color: Colors.white, size: 24),
            label: Text(
              _isRegistering ? 'Registrando...' : 'Registrarse con Apple',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: !_isRegistering ? 2 : 0,
            ),
          ),
        ),
        if (Platform.isIOS && _isBiometricAvailable) ...[
          const SizedBox(height: 16),
          if (AuthService.isAuthenticated) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBiometricLoading ? null : _handleFaceIdLogin,
                icon: _isBiometricLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.face, color: Colors.white, size: 24),
                label: Text(
                  _isBiometricLoading
                      ? 'Autenticando...'
                      : 'Continuar con Face ID',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _registerWithGoogle() async {
    setState(() {
      _isRegistering = true;
      _registerError = null;
    });

    try {
      print('🚀 [DEBUG] Iniciando registro con Google');

      // PASO 1: Obtener información de Google SIN autenticar con Firebase
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        print('❌ [DEBUG] Google Sign In cancelado por el usuario');
        setState(() {
          _isRegistering = false;
        });
        return;
      }

      final String email = googleUser.email;
      print('🔍 [DEBUG] Email obtenido de Google: $email');

      // PASO 2: VERIFICAR SI EL EMAIL YA EXISTE EN FIRESTORE ANTES DE REGISTRAR
      final emailExists = await _checkEmailExists(email);

      if (emailExists) {
        print('❌ [DEBUG] Email YA existe en Firestore: $email');
        // Cerrar sesión de Google ya que no vamos a proceder
        await GoogleSignIn().signOut();
        setState(() {
          _registerError =
              'Esta cuenta ya existe. Inicia sesión desde la pantalla de login.';
          _isRegistering = false;
        });
        return;
      }

      print('✅ [DEBUG] Email disponible, procediendo con registro...');

      // PASO 3: AHORA SÍ, CREAR CUENTA EN FIREBASE
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user == null) {
        print('❌ [DEBUG] No se pudo crear usuario en Firebase Auth');
        setState(() {
          _registerError = 'Error al registrarse con Google. Intenta de nuevo.';
          _isRegistering = false;
        });
        return;
      }

      print('✅ [DEBUG] Usuario creado en Firebase Auth, creando perfil...');
      await _createUserWithGuestPreferences(userCredential.user!);
    } catch (e) {
      print('❌ [DEBUG] Error en registro con Google: $e');
      setState(() {
        _isRegistering = false;

        if (e is FirebaseAuthException &&
            (e.code == 'second-factor-required' ||
                e.message?.toLowerCase().contains('second-factor') == true)) {
          _registerError =
              'Esta cuenta ya existe y tiene 2FA. Inicia sesión para completarlo.';
        } else if (e.toString().contains('second-factor-required')) {
          _registerError =
              'Esta cuenta ya existe y tiene 2FA. Inicia sesión para completarlo.';
        } else if (e
            .toString()
            .contains('account-exists-with-different-credential')) {
          _registerError =
              'Esta cuenta ya existe. Inicia sesión desde la pantalla de login.';
        } else if (e.toString().contains('email-already-in-use')) {
          _registerError =
              'Esta cuenta ya existe. Inicia sesión desde la pantalla de login.';
        } else if (e.toString().contains('network')) {
          _registerError =
              'Error de conexión. Verifica tu internet y vuelve a intentar.';
        } else if (e.toString().contains('cancelled')) {
          _registerError = 'Registro cancelado por el usuario.';
        } else {
          _registerError = 'Error al registrarse con Google: $e';
        }
      });
    }
  }

  Future<void> _registerWithApple() async {
    setState(() {
      _isRegistering = true;
      _registerError = null;
    });

    try {
      print('🚀 [DEBUG] Iniciando registro con Apple');

      // PASO 1: Obtener información de Apple SIN autenticar con Firebase
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final String? email = appleCredential.email;
      print('🔍 [DEBUG] Email obtenido de Apple: $email');

      // MANEJAR CASO DONDE APPLE NO PROPORCIONA EMAIL
      if (email == null) {
        print(
            '⚠️ [DEBUG] Apple no proporcionó email, procederemos con autenticación para obtenerlo');

        // PASO 2A: Autenticar PRIMERO para obtener el email del usuario
        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

        final userCredential =
            await FirebaseAuth.instance.signInWithCredential(oauthCredential);

        if (userCredential.user == null || userCredential.user!.email == null) {
          print(
              '❌ [DEBUG] No se pudo obtener usuario o email después de autenticación');
          setState(() {
            _registerError =
                'No se pudo obtener el email de tu cuenta de Apple.';
            _isRegistering = false;
          });
          return;
        }

        final actualEmail = userCredential.user!.email!;
        print(
            '✅ [DEBUG] Email obtenido después de autenticación: $actualEmail');

        // PASO 2B: VERIFICAR SI EL EMAIL YA EXISTE EN FIRESTORE
        final emailExists = await _checkEmailExists(actualEmail);

        if (emailExists) {
          print('❌ [DEBUG] Email YA existe en Firestore: $actualEmail');
          // Limpiar la cuenta que acabamos de crear
          await FirebaseAuth.instance.signOut();
          setState(() {
            _registerError =
                'Esta cuenta ya existe. Inicia sesión desde la pantalla de login.';
            _isRegistering = false;
          });
          return;
        }

        print('✅ [DEBUG] Email disponible, creando perfil...');
        await _createUserWithGuestPreferences(userCredential.user!);
        return;
      }

      // CASO NORMAL: Apple SÍ proporcionó email
      print('✅ [DEBUG] Apple proporcionó email, verificando disponibilidad...');

      // PASO 2: VERIFICAR SI EL EMAIL YA EXISTE EN FIRESTORE ANTES DE REGISTRAR
      final emailExists = await _checkEmailExists(email);

      if (emailExists) {
        print('❌ [DEBUG] Email YA existe en Firestore: $email');
        setState(() {
          _registerError =
              'Esta cuenta ya existe. Inicia sesión desde la pantalla de login.';
          _isRegistering = false;
        });
        return;
      }

      print('✅ [DEBUG] Email disponible, procediendo con registro...');

      // PASO 3: CREAR CUENTA EN FIREBASE
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      if (userCredential.user == null) {
        print('❌ [DEBUG] No se pudo crear usuario en Firebase Auth');
        setState(() {
          _registerError = 'Error al registrarse con Apple. Intenta de nuevo.';
          _isRegistering = false;
        });
        return;
      }

      print('✅ [DEBUG] Usuario creado en Firebase Auth, creando perfil...');
      await _createUserWithGuestPreferences(userCredential.user!);
    } catch (e) {
      print('❌ [DEBUG] Error en registro con Apple: $e');
      setState(() {
        _isRegistering = false;

        if (e is FirebaseAuthException &&
            (e.code == 'second-factor-required' ||
                e.message?.toLowerCase().contains('second-factor') == true)) {
          _registerError =
              'Esta cuenta ya existe y tiene 2FA. Inicia sesión para completarlo.';
        } else if (e.toString().contains('second-factor-required')) {
          _registerError =
              'Esta cuenta ya existe y tiene 2FA. Inicia sesión para completarlo.';
        } else if (e
            .toString()
            .contains('account-exists-with-different-credential')) {
          _registerError =
              'Esta cuenta ya existe. Inicia sesión desde la pantalla de login.';
        } else if (e.toString().contains('email-already-in-use')) {
          _registerError =
              'Esta cuenta ya existe. Inicia sesión desde la pantalla de login.';
        } else if (e.toString().contains('network')) {
          _registerError =
              'Error de conexión. Verifica tu internet y vuelve a intentar.';
        } else if (e.toString().contains('cancelled')) {
          _registerError = 'Registro cancelado por el usuario.';
        } else {
          _registerError = 'Error al registrarse con Apple: $e';
        }
      });
    }
  }

  Future<void> _handleFaceIdLogin() async {
    setState(() {
      _isBiometricLoading = true;
      _registerError = null;
    });

    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        setState(() {
          _registerError = 'Face ID no está disponible en este momento.';
          _isBiometricLoading = false;
        });
        return;
      }

      final credentials = await AuthService.getSavedCredentials();
      final savedEmail = credentials['email'];
      final savedPassword = credentials['password'];

      if (savedEmail == null || savedPassword == null) {
        setState(() {
          _registerError =
              'No hay credenciales guardadas. Inicia sesión primero con "Recordarme" activado.';
          _isBiometricLoading = false;
        });
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Usa Face ID para iniciar sesión en Tourify',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: savedEmail,
          password: savedPassword,
        );

        if (mounted && userCredential.user != null) {
          AnalyticsService.trackLogin('biometric');
          await AnalyticsService.setUserId(userCredential.user!.uid);
          await AnalyticsService.setUserProperties({
            'user_type': 'authenticated',
          });

          setState(() {
            _showRegistrationOptions = false;
          });

          await _completeOnboarding();
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _registerError = 'Error al iniciar sesión: ${e.message}';
        _isBiometricLoading = false;
      });
    } catch (e) {
      setState(() {
        _registerError = 'Error en autenticación Face ID.';
        _isBiometricLoading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
        });
      }
    }
  }

  Future<void> _createUserWithGuestPreferences(User user) async {
    try {
      final temporaryGuide = await GuestGuideService.getTemporaryGuide();

      // Derivar valores adicionales requeridos en el documento del usuario
      final nowIso = DateTime.now().toIso8601String();
      final email = user.email;
      final displayName = user.displayName;
      final photoURL = user.photoURL;
      final providerId = (user.providerData.isNotEmpty)
          ? user.providerData.first.providerId
          : '';

      // Derivar username a partir del email o del UID
      String deriveUsername(String? mail, String fallback) {
        if (mail != null && mail.contains('@')) {
          final local = mail.split('@').first;
          return local.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '').toLowerCase();
        }
        return fallback.substring(0, fallback.length.clamp(0, 24));
      }

      // Mapeo de intensidad → actividades por día
      String computeActivitiesPerDay(dynamic intensity) {
        final value = (intensity ?? '').toString().toLowerCase();
        if (value.contains('relaj')) return '3 actividades por día';
        if (value.contains('moder')) return '5 actividades por día';
        if (value.contains('activo') || value.contains('activa')) {
          return '7 actividades por día';
        }
        // fallback por si no se definió intensidad
        return '3-4 actividades';
      }

      final travelIntensity = temporaryGuide?['travelIntensity'];
      final activitiesPerDay = computeActivitiesPerDay(travelIntensity);

      final userPreferences = {
        // Identidad básica
        'displayName': displayName,
        'name': displayName ?? 'Usuario',
        'email': email,
        'photoURL': photoURL,
        'username': deriveUsername(email, user.uid),
        'authProvider': providerId, // 'google.com' | 'apple.com' | etc

        // Timestamps y streaks
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'currentStreak': 1,
        'longestStreak': 1,
        'streakLastUpdated': nowIso,
        'lastTravelDate': nowIso,

        // Preferencias de viaje provenientes del flujo de invitado
        'phone':
            _userPhone.isNotEmpty ? _formatPhoneWithPrefix(_userPhone) : '',
        'travel_styles': temporaryGuide?['travelModes'] ?? ['Cultural'],
        'budgets': temporaryGuide?['budgets'] ?? ['Moderado'],
        'travelIntensity': travelIntensity ?? 'Moderado',
        'activities_per_day': activitiesPerDay,
        'group_size': temporaryGuide != null
            ? '${(temporaryGuide['adults'] ?? 1) + (temporaryGuide['children'] ?? 0)} personas'
            : '2 personas',
        'preferred_destination': temporaryGuide?['destination'] ?? '',
        'preferred_duration': temporaryGuide?['selectedDays'] ?? 3,
        'preferred_travelers': temporaryGuide?['travelers'] ?? 2,

        // Otros
        'language': 'es',
        'location': '',
        'citiesGoal': _citiesGoal > 0 ? _citiesGoal : 1,

        // 2FA se configurará en el paso de verificación
        'hasSecondFactor': false,
        'secondFactorType': null,
        'secondFactorPhone': null,
        'hasCompletedOnboarding': false,
      };

      // Crear si no existe, actualizar si ya existe
      try {
        final existing = await UserService.getUserData(user.uid);
        if (existing == null) {
          // Crear el documento con todos los campos y timestamps de servidor
          await UserService.createUserDocument(user,
              additionalData: userPreferences);
        } else {
          // Actualizar preservando lo existente
          await UserService.updateUserData(user.uid, userPreferences);
        }
      } catch (e) {
        // Intento de respaldo: crear documento si falló la lectura
        await UserService.createUserDocument(user,
            additionalData: userPreferences);
      }

      await LocalUserPrefs.saveBasicProfile(
        displayName: user.displayName ?? 'Usuario',
        email: user.email,
        photoURL: user.photoURL,
      );
      if (mounted) {
        setState(() {
          _userName = user.displayName ?? 'Usuario';
          _isRegistering = false;
          _showRegistrationOptions = false;
        });
      }

      await _migrateTemporaryGuideToCloud(temporaryGuide);
    } catch (e) {
      setState(() {
        _isRegistering = false;
        _registerError = 'Error creando perfil de usuario: $e';
      });
    }
  }

  Future<void> _migrateTemporaryGuideToCloud(
      Map<String, dynamic>? temporaryGuide) async {
    if (temporaryGuide == null) return;

    try {
      if (!AuthService.isAuthenticated) {
        return;
      }

      final activitiesData = temporaryGuide['activities'] as List<dynamic>?;
      final isGenerated = temporaryGuide['isGenerated'] as bool? ?? false;

      List<Activity> activities = [];
      if (isGenerated && activitiesData != null) {
        activities = activitiesData.map((activityData) {
          final data = activityData as Map<String, dynamic>;
          final images = data['images'] as List<dynamic>?;
          final imageUrl = data['imageUrl']?.toString() ??
              (images != null && images.isNotEmpty
                  ? images.first.toString()
                  : '');

          return Activity(
            id: data['id']?.toString() ?? '',
            name: data['title']?.toString() ?? data['name']?.toString() ?? '',
            description: data['description']?.toString() ?? '',
            imageUrl: imageUrl,
            rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
            reviews: (data['reviews'] as num?)?.toInt() ?? 0,
            category: data['category']?.toString() ?? 'cultural',
            price: (data['price'] as num?)?.toDouble() ?? 0.0,
            duration: (data['duration'] as num?)?.toInt() ?? 60,
            tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
          );
        }).toList();
      }

      final guideId = await GuideService.createGuide(
        destination: temporaryGuide['destination'] ?? 'Destino',
        startDate: DateTime.parse(temporaryGuide['startDate'] as String),
        endDate: DateTime.parse(temporaryGuide['endDate'] as String),
        selectedActivities: activities,
        travelers: temporaryGuide['travelers'] ?? 2,
        travelModes:
            List<String>.from(temporaryGuide['travelModes'] ?? ['Cultural']),
        isPublic: false,
        guideName: 'Mi guía de ${temporaryGuide['destination'] ?? 'viaje'}',
        guideDescription: 'Guía creada desde planificación como invitado',
      );

      if (guideId != null) {
        await GuestGuideService.clearTemporaryGuide();
      }
    } catch (e) {
      try {
        await GuestGuideService.clearTemporaryGuide();
      } catch (clearError) {
        // Ignorar error de limpieza
      }
    }
  }

  /// Verifica si un email ya existe en la colección de usuarios
  Future<bool> _checkEmailExists(String email) async {
    try {
      print('🔍 Verificando si el email ya existe: $email');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      final exists = querySnapshot.docs.isNotEmpty;

      if (exists) {
        print('❌ Email ya existe en la base de datos: $email');
      } else {
        print('✅ Email disponible: $email');
      }

      return exists;
    } catch (e) {
      print('⚠️ Error verificando email: $e');
      // En caso de error, permitir el registro (para no bloquear sin razón)
      return false;
    }
  }
}
