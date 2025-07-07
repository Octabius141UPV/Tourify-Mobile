import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourify_flutter/screens/home_screen.dart';
import 'package:tourify_flutter/screens/register_screen.dart';
import 'package:tourify_flutter/screens/verify_email_screen.dart';
import 'package:tourify_flutter/services/auth_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../config/app_colors.dart';
import '../utils/safe_area_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLoading = false;
  bool _isBiometricLoading = false;
  bool _isBiometricAvailable = false;
  bool _rememberMe = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('LoginScreen inicializada');
    _checkBiometricAvailability();
    _loadRememberedCredentials();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      print('🔍 Verificando disponibilidad biométrica...');

      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      print('📱 Dispositivo soporta biometría: $isDeviceSupported');
      print('🔒 Puede verificar biometría: $isAvailable');
      print('🆔 Tipos disponibles: $availableBiometrics');

      setState(() {
        _isBiometricAvailable =
            isAvailable && isDeviceSupported && availableBiometrics.isNotEmpty;
      });

      print('✅ Biometría disponible: $_isBiometricAvailable');
    } catch (e) {
      print('❌ Error verificando biometría: $e');
      setState(() {
        _isBiometricAvailable = false;
      });
    }
  }

  Future<bool> _hasStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('saved_email') &&
          prefs.containsKey('saved_password');
    } catch (e) {
      return false;
    }
  }

  final Map<String, String> _firebaseErrorMessages = {
    'auth/invalid-email': 'El correo electrónico no es válido.',
    'auth/user-disabled': 'Esta cuenta ha sido deshabilitada.',
    'auth/user-not-found': 'No existe ninguna cuenta con este correo.',
    'auth/wrong-password': 'La contraseña es incorrecta.',
    'auth/too-many-requests':
        'Demasiados intentos fallidos. Intenta de nuevo más tarde.',
    'auth/network-request-failed':
        'Error de red. Revisa tu conexión a internet.',
    'auth/email-not-verified':
        'Debes verificar tu correo electrónico antes de iniciar sesión.',
    'auth/internal-error':
        'Error interno del servidor. Intenta de nuevo más tarde.',
    'auth/missing-password': 'Debes ingresar una contraseña.',
    'auth/missing-email': 'Debes ingresar un correo electrónico.',
    'auth/invalid-credential':
        'Las credenciales proporcionadas no son válidas.',
    'auth/operation-not-allowed':
        'El inicio de sesión está deshabilitado temporalmente.',
    'auth/invalid-action-code':
        'El código de verificación es inválido o ha expirado.',
    'auth/invalid-verification-code':
        'El código de verificación es inválido o ha expirado.',
    'auth/invalid-login-credentials':
        'La contraseña proporcionada no es válida.',
  };

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = 'Por favor, completa todos los campos';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Iniciar sesión con Firebase Auth
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted && userCredential.user != null) {
        print('Login exitoso: ${userCredential.user?.email}');

        // Verificar si el email está verificado
        await userCredential.user!.reload();
        if (!userCredential.user!.emailVerified) {
          print('❌ Email no verificado, redirigiendo a VerifyEmailScreen');

          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const VerifyEmailScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
            (route) => false,
          );
          return;
        }

        print('✅ Email verificado, continuando con el login');

        // Guardar o limpiar credenciales según la opción de recordar
        if (_rememberMe) {
          await AuthService.saveCredentialsForRememberMe(
            _emailController.text.trim(),
            _passwordController.text,
          );
          await AuthService.saveRememberMeStatus(true);
        } else {
          await AuthService.clearRememberedCredentials();
        }

        // Si hay biometría disponible, siempre guardar credenciales para Face ID
        // (independientemente de "Recordarme")
        if (_isBiometricAvailable) {
          await AuthService.saveCredentialsForRememberMe(
            _emailController.text.trim(),
            _passwordController.text,
          );
          print('✅ Credenciales guardadas para biometría');
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
      }
    } on FirebaseAuthException catch (e) {
      print('Error en login: ${e.code}');
      setState(() {
        _error = _firebaseErrorMessages[e.code] ??
            'Error desconocido al iniciar sesión.';
      });
    } catch (e) {
      print('Error en login: $e');
      setState(() {
        _error = 'Error desconocido al iniciar sesión.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userCredential = await AuthService.signInWithGoogle();

      if (mounted && userCredential?.user != null) {
        print('Login con Google exitoso: ${userCredential?.user?.email}');
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
      print('Error en login con Google: $e');
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
      final userCredential = await AuthService.signInWithApple();

      if (mounted && userCredential?.user != null) {
        print('Login con Apple exitoso: ${userCredential?.user?.email}');
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
      print('Error en login con Apple: $e');
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

  Future<void> _handleBiometricLogin() async {
    setState(() {
      _isBiometricLoading = true;
      _error = null;
    });

    try {
      print('🔐 Iniciando autenticación biométrica...');

      // Verificar que aún hay biometría disponible
      final bool canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        setState(() {
          _error = 'La biometría no está disponible en este momento.';
        });
        return;
      }

      // Verificar credenciales guardadas
      final credentials = await AuthService.getSavedCredentials();
      final savedEmail = credentials['email'];
      final savedPassword = credentials['password'];

      print('📧 Email guardado: ${savedEmail != null ? "SÍ" : "NO"}');
      print('🔑 Contraseña guardada: ${savedPassword != null ? "SÍ" : "NO"}');

      if (savedEmail == null || savedPassword == null) {
        setState(() {
          _error =
              'No hay credenciales guardadas. Inicia sesión primero con "Recordarme" activado.';
        });
        return;
      }

      print('🤳 Solicitando autenticación biométrica...');

      // Autenticar con biometría
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason:
            'Usa Touch ID o Face ID para iniciar sesión en Tourify',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      print('✅ Autenticación biométrica exitosa: $didAuthenticate');

      if (didAuthenticate) {
        print('🔥 Iniciando sesión con Firebase...');

        // Si la autenticación biométrica es exitosa, hacer login con Firebase
        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: savedEmail,
          password: savedPassword,
        );

        if (mounted && userCredential.user != null) {
          print('🎉 Login con Face ID exitoso: ${userCredential.user?.email}');
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
      } else {
        print('❌ Usuario canceló la autenticación biométrica');
      }
    } on FirebaseAuthException catch (e) {
      print(
          '❌ Error de Firebase en login con Face ID: ${e.code} - ${e.message}');
      setState(() {
        _error = _firebaseErrorMessages[e.code] ??
            'Error al iniciar sesión: ${e.message}';
      });
    } catch (e) {
      print('❌ Error en autenticación biométrica: $e');

      // Manejo específico de errores de local_auth
      String errorMessage = 'Error en autenticación biométrica.';

      if (e.toString().contains('UserCancel')) {
        errorMessage = 'Autenticación cancelada por el usuario.';
      } else if (e.toString().contains('NotAvailable')) {
        errorMessage = 'Face ID/Touch ID no está disponible.';
      } else if (e.toString().contains('NotEnrolled')) {
        errorMessage =
            'No hay datos biométricos configurados en el dispositivo.';
      } else if (e.toString().contains('LockedOut')) {
        errorMessage =
            'Face ID/Touch ID está bloqueado. Usa el código del dispositivo.';
      }

      setState(() {
        _error = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _error =
            'Por favor, ingresa tu correo electrónico para restablecer la contraseña';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        // Mostrar diálogo de confirmación
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Correo enviado'),
              content: Text(
                'Se ha enviado un enlace para restablecer tu contraseña a ${_emailController.text.trim()}.\n\nRevisa tu bandeja de entrada y carpeta de spam.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Entendido'),
                ),
              ],
            );
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Error en restablecimiento de contraseña: ${e.code}');
      String errorMessage;

      switch (e.code) {
        case 'user-not-found':
          errorMessage =
              'No existe ninguna cuenta con este correo electrónico.';
          break;
        case 'invalid-email':
          errorMessage = 'El correo electrónico no es válido.';
          break;
        case 'too-many-requests':
          errorMessage = 'Demasiados intentos. Intenta de nuevo más tarde.';
          break;
        default:
          errorMessage = 'Error al enviar el correo de restablecimiento.';
      }

      setState(() {
        _error = errorMessage;
      });
    } catch (e) {
      print('Error en restablecimiento de contraseña: $e');
      setState(() {
        _error = 'Error al enviar el correo de restablecimiento.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      final bool rememberMe = await AuthService.getRememberMeStatus();
      if (rememberMe) {
        final credentials = await AuthService.getSavedCredentials();
        final savedEmail = credentials['email'];

        if (savedEmail != null) {
          setState(() {
            _emailController.text = savedEmail;
            _rememberMe = true;
          });
        }
      }
    } catch (e) {
      print('Error cargando credenciales recordadas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Construyendo LoginScreen');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  color: Colors.white.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bienvenido de nuevo',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            hintText: 'Correo electrónico',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            hintText: 'Contraseña',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                fillColor: MaterialStateProperty.resolveWith(
                                  (states) {
                                    if (states
                                        .contains(MaterialState.selected)) {
                                      return Colors.white;
                                    }
                                    return Colors.transparent;
                                  },
                                ),
                                checkColor: const Color(0xFF2563EB),
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              const Text(
                                'Recordar mi sesión',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.black87),
                              ),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: _isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.black87,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Iniciando sesión...',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Iniciar sesión',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Enlace de "¿Olvidaste tu contraseña?" - centrado
                        Center(
                          child: TextButton(
                            onPressed:
                                _isLoading ? null : _handleForgotPassword,
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.5),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'O continúa con',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.5),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (Platform.isIOS) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleAppleLogin,
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
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_isBiometricAvailable) ...[
                          FutureBuilder<bool>(
                            future: AuthService.hasStoredCredentials(),
                            builder: (context, snapshot) {
                              print(
                                  '🔍 Debug biometría - hasStoredCredentials: ${snapshot.data}');
                              if (snapshot.data == true) {
                                print('✅ Mostrando botón de biometría');
                                return Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _isBiometricLoading
                                            ? null
                                            : _handleBiometricLogin,
                                        icon: _isBiometricLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.black87,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.face,
                                                size: 24,
                                                color: Colors.black87,
                                              ),
                                        label: Text(
                                          _isBiometricLoading
                                              ? 'Autenticando...'
                                              : 'Continuar con biometría',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black87,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: const BorderSide(
                                                color: Colors.black87),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              } else {
                                print(
                                    '❌ No hay credenciales guardadas - botón de biometría oculto');
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                        TextButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const RegisterScreen(),
                                transitionDuration: Duration.zero,
                              ),
                              (route) => false,
                            );
                          },
                          child: const Text(
                            '¿No tienes cuenta? Regístrate',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
