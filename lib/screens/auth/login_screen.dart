import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:tourify_flutter/screens/main/home_screen.dart';
import 'package:tourify_flutter/screens/onboarding/welcome_screen.dart';
import 'package:tourify_flutter/services/auth_service.dart';
import 'dart:io' show Platform;
import '../../config/app_colors.dart';
import '../../services/analytics_service.dart';
import '../../services/api_service.dart';
import '../../services/navigation_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;
  bool _showRegisterOption = true;

  // Variables para segundo factor SMS
  bool _showSmsVerification = false;
  String _smsCode = '';
  bool _isVerifyingSms = false;
  String? _smsError;
  String? _verificationId;
  MultiFactorResolver? _multiFactorResolver;
  String? _secondFactorMethod; // 'google' | 'apple'

  final Map<String, String> _firebaseErrorMessages = {
    'auth/user-disabled': 'Esta cuenta ha sido deshabilitada.',
    'auth/user-not-found': 'No existe ninguna cuenta.',
    'auth/invalid-email': 'El formato del email no es válido.',
    'auth/too-many-requests':
        'Demasiados intentos fallidos. Intenta de nuevo más tarde.',
    'auth/network-request-failed':
        'Error de red. Revisa tu conexión a internet.',
    'auth/internal-error':
        'Error interno del servidor. Intenta de nuevo más tarde.',
    'auth/invalid-credential':
        'Las credenciales proporcionadas no son válidas.',
    'auth/operation-not-allowed':
        'El inicio de sesión está deshabilitado temporalmente.',
    'auth/second-factor-required':
        'Tu cuenta requiere verificación SMS para iniciar sesión.',
  };

  String _getFirebaseErrorMessage(String errorCode) {
    return _firebaseErrorMessages[errorCode] ??
        'Error al iniciar sesión. Intenta de nuevo.';
  }

  Future<void> _handleSecondFactorRequired(String method) async {
    setState(() {
      _showSmsVerification = true;
      _error = null;
      _isLoading = false;
      _secondFactorMethod = method.toLowerCase();
    });

    // Obtener el número de teléfono del primer factor disponible
    if (_multiFactorResolver != null &&
        _multiFactorResolver!.hints.isNotEmpty) {
      final hint = _multiFactorResolver!.hints.first;
      if (hint is PhoneMultiFactorInfo) {
        debugPrint('🔐 [DEBUG] Enviando SMS a: ${hint.phoneNumber}');
        await _sendSecondFactorSms(hint);
      }
    }
  }

  Future<void> _sendSecondFactorSms(PhoneMultiFactorInfo hint) async {
    if (_multiFactorResolver == null) return;

    setState(() {
      _isVerifyingSms = true;
      _smsError = null;
    });

    try {
      final session = await _multiFactorResolver!.session;

      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: session,
        multiFactorInfo: hint,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _completeSecondFactorVerification(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ [DEBUG] Error verificando segundo factor: $e');
          setState(() {
            _smsError = 'Error enviando SMS. Intenta de nuevo.';
            _isVerifyingSms = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ [DEBUG] Código SMS enviado');
          setState(() {
            _verificationId = verificationId;
            _isVerifyingSms = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isVerifyingSms = false;
          });
        },
      );
    } catch (e) {
      debugPrint('❌ [DEBUG] Error en segundo factor: $e');
      setState(() {
        _smsError = 'Error configurando verificación SMS.';
        _isVerifyingSms = false;
      });
    }
  }

  Future<void> _verifySmsSecondFactor() async {
    if (_verificationId == null || _smsCode.length != 6) {
      setState(() {
        _smsError = 'Ingresa el código de 6 dígitos.';
      });
      return;
    }

    setState(() {
      _isVerifyingSms = true;
      _smsError = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCode,
      );

      await _completeSecondFactorVerification(credential);
    } catch (e) {
      debugPrint('❌ [DEBUG] Error verificando código: $e');
      setState(() {
        _smsError = 'Código incorrecto. Intenta de nuevo.';
        _isVerifyingSms = false;
      });
    }
  }

  Future<void> _completeSecondFactorVerification(
      PhoneAuthCredential credential) async {
    if (_multiFactorResolver == null) return;

    try {
      final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
      final userCredential =
          await _multiFactorResolver!.resolveSignIn(assertion);

      debugPrint('✅ [DEBUG] Login con segundo factor completado');

      // Resolver proveedor esperado: el del primer factor (google/apple)
      String _providerIdToExpected(String providerId) {
        final id = providerId.toLowerCase();
        if (id.contains('google')) return 'google';
        if (id.contains('apple')) return 'apple';
        return id;
      }

      final user = userCredential.user!;
      final providerFromUser = user.providerData.isNotEmpty
          ? _providerIdToExpected(user.providerData.first.providerId)
          : null;
      final expectedProvider =
          _secondFactorMethod ?? providerFromUser ?? 'apple';

      debugPrint('🔍 [DEBUG] Validando con proveedor esperado (2FA): '
          '$expectedProvider (providerData: $providerFromUser)');

      // Validación servidor con proveedor correcto
      final _api = ApiService();
      final _serverValidation =
          await _api.validateLogin(expectedProvider: expectedProvider);
      if (_serverValidation['success'] != true) {
        final msg = _serverValidation['message'] ?? 'Error validando la cuenta';
        debugPrint('❌ [DEBUG] Error validación servidor (2FA): $msg');
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = msg;
          _showSmsVerification = false;
          _isVerifyingSms = false;
        });
        return;
      }

      // Validar documento del usuario con el proveedor correcto (cliente)
      final validationError =
          await _validateUserDocument(user, expectedProvider);

      if (validationError != null) {
        debugPrint('❌ [DEBUG] Error en validación: $validationError');
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = validationError;
          _showSmsVerification = false;
          _isVerifyingSms = false;
        });
        return;
      }

      // Login exitoso con 2FA
      AnalyticsService.trackLogin('multi-factor');
      AnalyticsService.trackEvent('second_factor_login_success', parameters: {
        'factor_type': 'sms',
        'login_method': 'multi-factor',
        'timestamp': DateTime.now().toIso8601String(),
      });
      await AnalyticsService.setUserId(userCredential.user!.uid);
      await AnalyticsService.setUserProperties({
        'user_type': 'authenticated',
        'has_second_factor': true,
      });

      setState(() {
        _showRegisterOption = false;
        _showSmsVerification = false;
        _isVerifyingSms = false;
      });

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
    } catch (e) {
      debugPrint('❌ [DEBUG] Error completando segundo factor: $e');
      setState(() {
        _smsError = 'Error completando verificación. Intenta de nuevo.';
        _isVerifyingSms = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkUserExistence();
  }

  Future<void> _checkUserExistence() async {
    try {
      final currentUser = AuthService.currentUser;
      setState(() {
        _showRegisterOption = currentUser == null;
      });
    } catch (e) {
      setState(() {
        _showRegisterOption = true;
      });
    }
  }

  /// Devuelve null si todo está bien; si hay problema, devuelve el mensaje.
  /// Acepta variantes de proveedor (como 'google', 'google.com').
  Future<String?> _validateUserDocument(
      User user, String expectedProvider) async {
    try {
      debugPrint('🔍 [DEBUG] Validando documento para usuario: ${user.uid}');
      debugPrint('🔍 [DEBUG] Email del usuario: ${user.email}');
      debugPrint('🔍 [DEBUG] Proveedor esperado: $expectedProvider');

      // PRIMERA VERIFICACIÓN: ¿Existe el email en Firestore? (solo si tenemos email)
      if (user.email != null) {
        final emailExists = await _checkEmailExistsInFirestore(user.email!);

        if (!emailExists) {
          debugPrint('❌ [DEBUG] Email NO existe en Firestore: ${user.email}');
          // NOTA: Si las reglas impiden leer, `_checkEmailExistsInFirestore` devolverá true.
          // Sólo si realmente no existe el email continuamos, pero NO eliminamos la cuenta aquí.
          return 'Este email no está registrado en Tourify. Crea una cuenta primero desde la pantalla de bienvenida.';
        }
      } else {
        debugPrint(
            'ℹ️ [DEBUG] No hay email para verificar - continuando con validación por UID');
      }

      // SEGUNDA VERIFICACIÓN: ¿Existe el documento del usuario por UID?
      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      try {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
              '⚠️ [DEBUG] Permiso denegado al leer user doc; confiando en validación de servidor');
          return null; // Confiar en validación de backend y continuar
        }
        rethrow;
      }

      debugPrint(
          '🔍 [DEBUG] Documento existe en Firestore por UID: ${userDoc.exists}');

      if (!userDoc.exists) {
        debugPrint(
            '❌ [DEBUG] Usuario en Auth pero NO en Firestore por UID - LIMPIANDO');
        try {
          final ok = await AuthService.deleteAccount();
          if (ok) {
            debugPrint('✅ [DEBUG] Cuenta eliminada por backend');
          } else {
            debugPrint(
                '⚠️ [DEBUG] Backend no eliminó cuenta; intentando borrar Auth local');
            try {
              await user.delete();
              debugPrint('✅ [DEBUG] Usuario eliminado de Auth');
            } catch (e) {
              debugPrint('⚠️ [DEBUG] Error eliminando usuario de Auth: $e');
            }
            await FirebaseAuth.instance.signOut();
            debugPrint('✅ [DEBUG] Sesión cerrada');
          }
        } catch (e) {
          debugPrint('⚠️ [DEBUG] Error eliminando cuenta vía backend: $e');
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
        }
        return 'Usuario no válido. Regístrate para continuar.';
      }

      final userData = userDoc.data();
      debugPrint('🔍 [DEBUG] Datos del documento: $userData');

      if (userData == null || userData.isEmpty) {
        debugPrint('❌ [DEBUG] Documento vacío - LIMPIANDO');
        try {
          final ok = await AuthService.deleteAccount();
          if (ok) {
            debugPrint('✅ [DEBUG] Cuenta eliminada por backend');
          } else {
            debugPrint(
                '⚠️ [DEBUG] Backend no eliminó cuenta; intentando borrar Auth local');
            try {
              await user.delete();
              debugPrint('✅ [DEBUG] Usuario eliminado de Auth');
            } catch (e) {
              debugPrint('⚠️ [DEBUG] Error eliminando usuario de Auth: $e');
            }
            await FirebaseAuth.instance.signOut();
            debugPrint('✅ [DEBUG] Sesión cerrada');
          }
        } catch (e) {
          debugPrint('⚠️ [DEBUG] Error eliminando cuenta vía backend: $e');
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
        }
        return 'Usuario no válido. Regístrate para continuar.';
      }

      final originalProviderRaw = (userData['authProvider'] as String?) ?? '';
      final originalProvider = originalProviderRaw.toLowerCase();
      debugPrint(
          '🔍 [DEBUG] Proveedor original en documento: $originalProvider');

      final expectedVariants = <String>[];
      if (expectedProvider.toLowerCase() == 'google') {
        expectedVariants.addAll(['google', 'google.com']);
      } else if (expectedProvider.toLowerCase() == 'apple') {
        expectedVariants.addAll(['apple', 'apple.com']);
      } else {
        expectedVariants.add(expectedProvider.toLowerCase());
      }
      debugPrint('🔍 [DEBUG] Variantes esperadas: $expectedVariants');

      final hasCompletedOnboarding =
          (userData['hasCompletedOnboarding'] as bool?) ?? false;
      final hasBasicData =
          userData['name'] != null || userData['phone'] != null;

      debugPrint('🔍 [DEBUG] hasCompletedOnboarding: $hasCompletedOnboarding');
      debugPrint('🔍 [DEBUG] hasBasicData: $hasBasicData');

      if (!hasCompletedOnboarding && !hasBasicData) {
        debugPrint(
            '❌ [DEBUG] Usuario sin onboarding ni datos básicos - LIMPIANDO');
        try {
          final ok = await AuthService.deleteAccount();
          if (ok) {
            debugPrint('✅ [DEBUG] Cuenta eliminada por backend');
          } else {
            debugPrint(
                '⚠️ [DEBUG] Backend no eliminó cuenta; intentando borrar Auth local');
            try {
              await user.delete();
              debugPrint('✅ [DEBUG] Usuario eliminado de Auth');
            } catch (e) {
              debugPrint('⚠️ [DEBUG] Error eliminando usuario de Auth: $e');
            }
            await FirebaseAuth.instance.signOut();
            debugPrint('✅ [DEBUG] Sesión cerrada');
          }
        } catch (e) {
          debugPrint('⚠️ [DEBUG] Error eliminando cuenta vía backend: $e');
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
        }
        return 'Usuario no válido. Regístrate para continuar.';
      }

      if (originalProvider.isNotEmpty &&
          !expectedVariants.contains(originalProvider)) {
        debugPrint(
            '❌ [DEBUG] Proveedor incorrecto: $originalProvider vs $expectedVariants - LIMPIANDO');
        try {
          final ok = await AuthService.deleteAccount();
          if (ok) {
            debugPrint('✅ [DEBUG] Cuenta eliminada por backend');
          } else {
            debugPrint(
                '⚠️ [DEBUG] Backend no eliminó cuenta; intentando borrar Auth local');
            try {
              await user.delete();
              debugPrint('✅ [DEBUG] Usuario eliminado de Auth');
            } catch (e) {
              debugPrint('⚠️ [DEBUG] Error eliminando usuario de Auth: $e');
            }
            await FirebaseAuth.instance.signOut();
            debugPrint('✅ [DEBUG] Sesión cerrada');
          }
        } catch (e) {
          debugPrint('⚠️ [DEBUG] Error eliminando cuenta vía backend: $e');
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
        }
        return 'Esta cuenta fue creada con $originalProvider. Inicia sesión con tu método original.';
      }

      debugPrint('✅ [DEBUG] Validación exitosa - usuario puede continuar');
      return null; // OK
    } catch (e) {
      debugPrint('❌ [DEBUG] Error en validación: $e');
      // No cerrar sesión automáticamente aquí; devolver error para UI sin borrar al usuario
      return 'Error validando la cuenta. Intenta de nuevo más tarde.';
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('🚀 [DEBUG] Iniciando flujo de login con Google');

      // PASO 1: Obtener información de Google SIN autenticar con Firebase
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (!mounted) return;

      if (googleUser == null) {
        debugPrint('❌ [DEBUG] Google Sign In cancelado por el usuario');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final String email = googleUser.email;
      debugPrint('🔍 [DEBUG] Email obtenido de Google: $email');
      // Omitimos verificación previa en Firestore (puede fallar por reglas). Autenticar y validar después.
      debugPrint(
          'ℹ️ [DEBUG] Omitiendo pre-chequeo de Firestore; autenticando con Firebase...');

      // PASO 3: AHORA SÍ, AUTENTICAR CON FIREBASE
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user == null) {
        debugPrint(
            '❌ [DEBUG] No se pudo obtener usuario después de autenticación');
        await _cleanupAuthAfterError();
        setState(() {
          _error = 'No se pudo iniciar sesión con Google.';
          _isLoading = false;
        });
        return;
      }

      // PASO 4: VALIDACIÓN ADICIONAL DEL DOCUMENTO (UID, proveedor, etc.)
      debugPrint(
          '🔍 [DEBUG] Usuario autenticado, validando documento completo...');
      // Validación servidor para evitar problemas de reglas
      final _api = ApiService();
      final _serverValidation =
          await _api.validateLogin(expectedProvider: 'google');
      if (_serverValidation['success'] != true) {
        final msg = _serverValidation['message'] ?? 'Error validando la cuenta';
        debugPrint('❌ [DEBUG] Error validación servidor (Google): $msg');
        await _cleanupAuthAfterError();
        setState(() {
          _error = msg;
          _isLoading = false;
        });
        return;
      }
      final validationError =
          await _validateUserDocument(userCredential.user!, 'google');

      if (validationError != null) {
        debugPrint(
            '❌ [DEBUG] Error en validación del documento: $validationError');
        await _cleanupAuthAfterError();
        setState(() {
          _error = validationError;
          _isLoading = false;
        });
        return;
      }

      debugPrint('✅ [DEBUG] Login exitoso, navegando a HomeScreen...');
      AnalyticsService.trackLogin('google');
      await AnalyticsService.setUserId(userCredential.user!.uid);
      await AnalyticsService.setUserProperties({
        'user_type': 'authenticated',
      });

      setState(() {
        _showRegisterOption = false;
      });

      // Si hay un join pendiente (deeplink), procesarlo antes de ir al Home
      if (NavigationService.hasPendingJoin) {
        debugPrint(
            '🔗 [DEBUG] Procesando join pendiente tras login exitoso...');
        await NavigationService.processPendingJoinIfAny();
        return; // processPendingJoinIfAny ya navega a la guía
      }

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
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [DEBUG] Error en flujo de Google login: $e');

      if (e.code == 'second-factor-required') {
        debugPrint('🔐 [DEBUG] Segundo factor requerido para Google login');
        // Cast to FirebaseAuthMultiFactorException to access resolver
        if (e is FirebaseAuthMultiFactorException) {
          _multiFactorResolver = e.resolver;
          await _handleSecondFactorRequired('google');
        } else {
          await _cleanupAuthAfterError();
          setState(() {
            _error = 'Error de configuración de segundo factor.';
          });
        }
      } else {
        AnalyticsService.trackEvent('login_failed', parameters: {
          'method': 'google',
          'error_message': e.toString(),
        });
        await _cleanupAuthAfterError();
        setState(() {
          _error = _getFirebaseErrorMessage(e.code);
        });
      }
    } catch (e) {
      debugPrint('❌ [DEBUG] Error general en flujo de Google login: $e');
      AnalyticsService.trackEvent('login_failed', parameters: {
        'method': 'google',
        'error_message': e.toString(),
      });
      await _cleanupAuthAfterError();
      setState(() {
        _error = 'Error al iniciar sesión con Google.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('🚀 [DEBUG] Iniciando flujo de login con Apple');

      // PASO 1: Obtener información de Apple SIN autenticar con Firebase
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (!mounted) return;

      final String? email = appleCredential.email;
      debugPrint('🔍 [DEBUG] Email obtenido de Apple: $email');

      // En LOGIN, si Apple no proporciona email (normal después del primer uso),
      // procedemos directamente con la autenticación
      if (email != null) {
        // Omitimos verificación previa en Firestore por posibles permisos; validamos después de autenticar
        debugPrint(
            'ℹ️ [DEBUG] Omitiendo pre-chequeo Firestore con Apple; autenticando...');
      } else {
        debugPrint(
            'ℹ️ [DEBUG] Apple no proporcionó email - procediendo con autenticación directa');
      }

      // PASO 3: AUTENTICAR CON FIREBASE
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      if (userCredential.user == null) {
        debugPrint(
            '❌ [DEBUG] No se pudo obtener usuario después de autenticación con Apple');
        setState(() {
          _error = 'No se pudo iniciar sesión con Apple.';
          _isLoading = false;
        });
        return;
      }

      // PASO 4: VALIDACIÓN ADICIONAL DEL DOCUMENTO (UID, proveedor, etc.)
      debugPrint(
          '🔍 [DEBUG] Usuario autenticado con Apple, validando documento completo...');
      final _api = ApiService();
      final _serverValidation =
          await _api.validateLogin(expectedProvider: 'apple');
      if (_serverValidation['success'] != true) {
        final msg = _serverValidation['message'] ?? 'Error validando la cuenta';
        debugPrint('❌ [DEBUG] Error validación servidor (Apple): $msg');
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = msg;
          _isLoading = false;
        });
        return;
      }
      final validationError =
          await _validateUserDocument(userCredential.user!, 'apple');

      if (validationError != null) {
        debugPrint(
            '❌ [DEBUG] Error en validación del documento: $validationError');
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = validationError;
          _isLoading = false;
        });
        return;
      }

      debugPrint(
          '✅ [DEBUG] Login con Apple exitoso, navegando a HomeScreen...');
      AnalyticsService.trackLogin('apple');
      await AnalyticsService.setUserId(userCredential.user!.uid);
      await AnalyticsService.setUserProperties({
        'user_type': 'authenticated',
      });

      setState(() {
        _showRegisterOption = false;
      });

      // Si hay un join pendiente (deeplink), procesarlo antes de ir al Home
      if (NavigationService.hasPendingJoin) {
        debugPrint(
            '🔗 [DEBUG] Procesando join pendiente tras login con Apple...');
        await NavigationService.processPendingJoinIfAny();
        return; // processPendingJoinIfAny ya navega a la guía
      }

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
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [DEBUG] Error en flujo de Apple login: $e');
      await _cleanupAuthAfterError();
      setState(() {
        _error = _getFirebaseErrorMessage(e.code);
      });
    } catch (e) {
      debugPrint('❌ [DEBUG] Error general en flujo de Apple login: $e');
      AnalyticsService.trackEvent('login_failed', parameters: {
        'method': 'apple',
        'error_message': e.toString(),
      });
      await _cleanupAuthAfterError();
      setState(() {
        _error = 'Error al iniciar sesión con Apple.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToWelcome() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WelcomeScreen(),
        transitionDuration: Duration.zero,
      ),
      (route) => false,
    );
  }

  Widget _buildSmsVerificationUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40), // Espacio extra arriba
          const Icon(
            Icons.phone_android,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          const Text(
            'Verificación SMS requerida 📱',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu cuenta tiene verificación en dos pasos habilitada.\nIngresa el código que enviamos a tu móvil.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Campo para código SMS
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

          const SizedBox(height: 20),

          // Botón verificar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _smsCode.length == 6 && !_isVerifyingSms
                  ? _verifySmsSecondFactor
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: _smsCode.length == 6 ? 4 : 0,
              ),
              child: _isVerifyingSms
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text(
                      'Verificar código',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          // Error SMS
          if (_smsError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                _smsError!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Botón cancelar
          TextButton(
            onPressed: () {
              setState(() {
                _showSmsVerification = false;
                _smsCode = '';
                _smsError = null;
                _multiFactorResolver = null;
              });
            },
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 40), // Espacio extra abajo
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              children: [
                // Cerrar
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: _navigateToWelcome,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Logo y texto / SMS Verification
                Expanded(
                  flex: 4,
                  child: _showSmsVerification
                      ? _buildSmsVerificationUI()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/icon.png',
                              width: 180,
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '¡Bienvenido de vuelta!',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Inicia sesión para continuar con tus viajes',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),

                // Botones sociales + error
                if (!_showSmsVerification)
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_error != null) ...[
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
                                      _error!,
                                      style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleGoogleLogin,
                              icon: Image.asset(
                                'assets/images/google_logo.png',
                                height: 24,
                              ),
                              label: const Text(
                                'Continuar con Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor: Colors.black.withOpacity(0.2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (Platform.isIOS) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isLoading ? null : _handleAppleLogin,
                                icon: const Icon(
                                  Icons.apple,
                                  size: 24,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Continuar con Apple',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                  shadowColor: Colors.black.withOpacity(0.2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_showRegisterOption) ...[
                            TextButton(
                              onPressed: _navigateToWelcome,
                              child: const Text(
                                '¿No tienes cuenta? Regístrate',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: screenHeight * 0.03),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Verifica si un email existe en la colección de usuarios
  Future<bool> _checkEmailExistsInFirestore(String email) async {
    try {
      debugPrint(
          '🔍 [DEBUG] Verificando si el email existe en Firestore: $email');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      final exists = querySnapshot.docs.isNotEmpty;

      if (exists) {
        debugPrint('✅ [DEBUG] Email encontrado en Firestore: $email');
      } else {
        debugPrint('❌ [DEBUG] Email NO encontrado en Firestore: $email');
      }

      return exists;
    } on FirebaseException catch (e) {
      debugPrint('⚠️ [DEBUG] Error verificando email en Firestore: $e');
      if (e.code == 'permission-denied') {
        // Las reglas pueden impedir lectura; como ya validamos contra el backend,
        // asumimos que el email existe para no bloquear ni borrar la cuenta.
        return true;
      }
      return true; // Fail-open: evitar falsos negativos que borren la cuenta
    } catch (e) {
      debugPrint('⚠️ [DEBUG] Error verificando email en Firestore: $e');
      return true; // Fail-open para no expulsar al usuario por errores transitorios
    }
  }

  Future<void> _fullSignOutGoogleAuth() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await GoogleSignIn().disconnect();
    } catch (_) {}
  }

  Future<void> _cleanupAuthAfterError() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final ok = await AuthService.deleteAccount();
          if (ok) {
            return; // Backend ya limpió Auth + credenciales
          }
        } catch (_) {
          // Ignorar y continuar con fallback
        }
        try {
          await user.delete();
        } catch (_) {}
      }
    } catch (_) {}
    await _fullSignOutGoogleAuth();
  }
}
