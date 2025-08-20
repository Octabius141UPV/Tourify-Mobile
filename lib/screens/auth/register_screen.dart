import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourify_flutter/screens/auth/verify_email_screen.dart';
import 'package:tourify_flutter/screens/auth/login_screen.dart';
import '../../utils/email_validator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  final Map<String, String> _firebaseErrorMessages = {
    'auth/email-already-in-use':
        'Ya existe una cuenta con este correo electrónico. ¿Quieres iniciar sesión en su lugar?',
    'auth/invalid-email': 'El formato del correo electrónico no es válido.',
    'auth/operation-not-allowed':
        'El registro con email/contraseña está deshabilitado temporalmente.',
    'auth/weak-password':
        'La contraseña es demasiado débil. Debe tener al menos 6 caracteres.',
    'auth/network-request-failed':
        'Error de conexión. Verifica tu conexión a internet e intenta de nuevo.',
    'auth/internal-error':
        'Error interno del servidor. Por favor, intenta de nuevo más tarde.',
    'auth/too-many-requests':
        'Demasiados intentos fallidos. Intenta de nuevo más tarde.',
    'auth/user-disabled':
        'Esta cuenta ha sido deshabilitada por un administrador.',
    'auth/requires-recent-login':
        'Esta operación requiere una autenticación reciente. Por favor, inicia sesión de nuevo.',
    'auth/credential-already-in-use':
        'Esta credencial ya está asociada con otra cuenta de usuario.',
    'auth/invalid-credential':
        'Las credenciales proporcionadas son incorrectas o han expirado.',
    'auth/account-exists-with-different-credential':
        'Ya existe una cuenta con el mismo correo pero con un proveedor de autenticación diferente.',
    'auth/auth-domain-config-required':
        'Error de configuración. Por favor, contacta al soporte técnico.',
    'auth/cancelled-popup-request':
        'Solicitud cancelada. Solo se permite una solicitud de ventana emergente a la vez.',
    'auth/popup-blocked':
        'La ventana emergente fue bloqueada por el navegador. Por favor, permite ventanas emergentes para este sitio.',
    'auth/popup-closed-by-user':
        'La ventana emergente fue cerrada antes de completar la operación.',
    'auth/unauthorized-domain':
        'Este dominio no está autorizado para esta operación.',
    'auth/user-token-expired':
        'La sesión del usuario ha expirado. Por favor, inicia sesión de nuevo.',
    'auth/invalid-api-key':
        'Error de configuración de la API. Por favor, contacta al soporte técnico.',
    'auth/app-deleted':
        'Esta instancia de la aplicación Firebase ha sido eliminada.',
    'auth/invalid-user-token':
        'El token del usuario no es válido. Por favor, inicia sesión de nuevo.',
    'auth/user-not-found':
        'No se encontró ningún usuario con estas credenciales.',
    'auth/invalid-tenant-id': 'El ID del inquilino proporcionado no es válido.',
    'auth/unsupported-tenant-operation':
        'Esta operación no es compatible con la configuración actual.',
    'auth/tenant-id-mismatch':
        'El ID del inquilino proporcionado no coincide con la configuración.',
  };

  Future<void> _handleRegister() async {
    // Validación básica de campos vacíos
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _error = 'Por favor, completa todos los campos obligatorios.';
      });
      return;
    }

    // Validación del nombre
    if (_nameController.text.trim().length < 2) {
      setState(() {
        _error = 'El nombre debe tener al menos 2 caracteres.';
      });
      return;
    }

    // Validación básica del email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() {
        _error = 'Por favor, ingresa un correo electrónico válido.';
      });
      return;
    }

    // Validación de email temporal
    final emailValidationResult =
        EmailValidator.validateEmail(_emailController.text.trim());
    if (!emailValidationResult.isValid) {
      setState(() {
        _error = emailValidationResult.error!;
      });
      return;
    }

    // Validación de contraseñas
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _error =
            'Las contraseñas no coinciden. Por favor, verifica que sean idénticas.';
      });
      return;
    }

    // Validación robusta de la contraseña
    if (_passwordController.text.length < 8) {
      setState(() {
        _error = 'La contraseña debe tener al menos 8 caracteres.';
      });
      return;
    }

    // Verificar que la contraseña tenga al menos una letra y un número
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(_passwordController.text);
    final hasNumber = RegExp(r'[0-9]').hasMatch(_passwordController.text);

    if (!hasLetter || !hasNumber) {
      setState(() {
        _error = 'La contraseña debe contener al menos una letra y un número.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Crear usuario con Firebase Auth
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Actualizar el perfil del usuario con el nombre
      if (userCredential.user != null) {
        await userCredential.user!
            .updateDisplayName(_nameController.text.trim());

        // Enviar email de verificación
        await userCredential.user!.sendEmailVerification();
      }

      if (mounted && userCredential.user != null) {
        print('Registro exitoso: ${userCredential.user?.email}');
        print(
            '📧 Correo de verificación enviado, redirigiendo a VerifyEmailScreen');

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
      }
    } on FirebaseAuthException catch (e) {
      print('Error en registro: ${e.code}');

      if (e.code == 'email-already-in-use') {
        // Caso especial para email ya existente - mostrar diálogo
        await _showEmailAlreadyExistsDialog();
      } else {
        setState(() {
          _error = _firebaseErrorMessages[e.code] ??
              'Error desconocido al registrarse: ${e.message ?? e.code}';
        });
      }
    } catch (e) {
      print('Error general en registro: $e');
      setState(() {
        _error =
            'Error inesperado al crear la cuenta. Por favor, intenta de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showEmailAlreadyExistsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Cuenta existente',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Ya existe una cuenta con este correo electrónico. ¿Te gustaría iniciar sesión en su lugar?',
            style: TextStyle(color: Colors.black87),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const LoginScreen(),
                    transitionDuration: Duration.zero,
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Iniciar sesión'),
            ),
          ],
        );
      },
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
            colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
          ),
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
                          'Crear cuenta',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Únete a Tourify',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Nombre completo',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
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
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordObscured
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordObscured = !_isPasswordObscured;
                                });
                              },
                            ),
                          ),
                          obscureText: _isPasswordObscured,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            hintText: 'Confirmar contraseña',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordObscured
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordObscured =
                                      !_isConfirmPasswordObscured;
                                });
                              },
                            ),
                          ),
                          obscureText: _isConfirmPasswordObscured,
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
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
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
                                        'Creando cuenta...',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Crear cuenta',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const LoginScreen(),
                                transitionDuration: Duration.zero,
                              ),
                              (route) => false,
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            '¿Ya tienes cuenta? Inicia sesión',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
