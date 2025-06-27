import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tourify_flutter/screens/login_screen.dart';

import '../config/app_colors.dart';
import '../utils/email_validator.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _emailSent = false;

  final Map<String, String> _firebaseErrorMessages = {
    'auth/invalid-email': 'El correo electrónico no es válido.',
    'auth/user-not-found': 'No existe ninguna cuenta con este correo.',
    'auth/network-request-failed':
        'Error de red. Revisa tu conexión a internet.',
    'auth/internal-error':
        'Error interno del servidor. Intenta de nuevo más tarde.',
    'auth/missing-email': 'Debes ingresar un correo electrónico.',
  };

  Future<void> _handleResetPassword() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Validar email antes de enviar
    final emailValidationResult =
        EmailValidator.validateEmail(_emailController.text.trim());
    if (!emailValidationResult.isValid) {
      setState(() {
        _error = emailValidationResult.error!;
        _isLoading = false;
      });
      return;
    }

    try {
      // TODO: Implementar lógica de recuperación de contraseña con Firebase
      await Future.delayed(const Duration(seconds: 2)); // Simulación de envío
      if (mounted) {
        setState(() {
          _emailSent = true;
        });
      }
    } catch (e) {
      setState(() {
        _error = _firebaseErrorMessages[e.toString()] ??
            'Error desconocido al enviar el correo de recuperación.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
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
                        const Icon(
                          Icons.lock_reset,
                          size: 64,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Recuperar contraseña',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_emailSent) ...[
                          const Text(
                            'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
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
                              onPressed:
                                  _isLoading ? null : _handleResetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.withOpacity(0.2),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: Colors.blue),
                                ),
                              ),
                              child: _isLoading
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Enviando...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Enviar correo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          const Text(
                            '¡Correo enviado!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Hemos enviado un correo con instrucciones para restablecer tu contraseña. Por favor, revisa tu bandeja de entrada.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const LoginScreen(),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          },
                          child: const Text(
                            'Volver al inicio de sesión',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
    super.dispose();
  }
}
