import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:io';

/// Diálogo automático para iniciar sesión en Google y obtener cookies
class GoogleMapsLoginDialog extends StatefulWidget {
  final Function(String cookies) onLoginSuccess;
  final VoidCallback onCancel;

  const GoogleMapsLoginDialog({
    super.key,
    required this.onLoginSuccess,
    required this.onCancel,
  });

  @override
  State<GoogleMapsLoginDialog> createState() => _GoogleMapsLoginDialogState();
}

class _GoogleMapsLoginDialogState extends State<GoogleMapsLoginDialog> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String _statusMessage = 'Cargando...';
  int _checkAttempts = 0;
  static const int maxCheckAttempts = 3;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    // Limpiar el estado cuando el widget se destruye
    print('🛑 GoogleMapsLoginDialog dispose - limpiando estado');
    super.dispose();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            _isLoading = true;
            _statusMessage = 'Cargando Google...';
          });
        },
        onPageFinished: (String url) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Verificando sesión...';
          });
          _checkLoginStatus();
        },
        onNavigationRequest: (NavigationRequest request) {
          // Permitir navegación a Google
          if (request.url.contains('google.com') ||
              request.url.contains('accounts.google.com')) {
            return NavigationDecision.navigate;
          }

          // Detectar intentos de usar biometría
          if (request.url.contains('biometric') ||
              request.url.contains('fingerprint') ||
              request.url.contains('face-unlock')) {
            setState(() {
              _statusMessage =
                  'Por favor, usa tu contraseña en lugar de la huella digital';
            });
            return NavigationDecision.prevent;
          }

          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse('https://maps.google.com'));
  }

  Future<void> _checkLoginStatus() async {
    try {
      // Verificar si el widget aún está montado
      if (!mounted) {
        print('🛑 Widget no montado, cancelando verificación');
        return;
      }

      _checkAttempts++;
      print(
          '🔍 Verificando estado de login... (intento $_checkAttempts/$maxCheckAttempts)');

      // Ejecutar JavaScript para verificar si el usuario está logueado
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          try {
            // Verificar si hay cookies de sesión de Google
            const cookies = document.cookie;
            console.log('🔍 Cookies disponibles:', cookies);
            
            // Verificar si hay errores de biometría en la página
            const pageText = document.body ? document.body.innerText : '';
            const hasBiometricError = pageText.includes('huella') || 
                                    pageText.includes('fingerprint') ||
                                    pageText.includes('biometric') ||
                                    pageText.includes('Face Unlock');
            
            if (hasBiometricError) {
              console.log('⚠️ Error de biometría detectado');
              return JSON.stringify({
                isLoggedIn: false,
                cookies: null,
                error: 'biometric_error',
                message: 'Por favor, usa tu contraseña en lugar de la huella digital'
              });
            }
            
            // Verificar si estamos en la página de login
            const isOnLoginPage = window.location.href.includes('accounts.google.com/signin') ||
                                 document.title.includes('Sign in') ||
                                 document.title.includes('Iniciar sesión');
            
            // Verificar si estamos en Gmail (lo que indicaría que ya estamos logueados)
            const isOnGmail = window.location.href.includes('mail.google.com') ||
                              document.title.includes('Gmail');
            
            // Verificar si estamos en Google Maps (lo que indicaría que ya estamos logueados)
            const isOnGoogleMaps = window.location.href.includes('maps.google.com') ||
                                  window.location.href.includes('google.com/maps') ||
                                  document.title.includes('Google Maps');
            
            if (isOnLoginPage) {
              console.log('🔍 Usuario en página de login');
              return JSON.stringify({
                isLoggedIn: false,
                cookies: null,
                error: 'not_logged_in',
                message: 'Por favor, inicia sesión con tu cuenta de Google'
              });
            }
            
            // Si estamos en Gmail, probablemente ya estamos logueados
            if (isOnGmail) {
              console.log('🔍 Usuario en Gmail - obteniendo cookies...');
              
              // Extraer cookies específicas necesarias para Google Maps
              const cookiePairs = cookies.split(';');
              const requiredCookies = ['SAPISID', 'HSID', 'SID', 'APISID'];
              const extractedCookies = [];
              const foundCookies = [];
              
              for (const pair of cookiePairs) {
                const [name, value] = pair.trim().split('=');
                if (requiredCookies.includes(name)) {
                  extractedCookies.push(name + '=' + value);
                  foundCookies.push(name);
                }
              }
              
              console.log('🔍 Cookies encontradas en Gmail:', foundCookies);
              
              // Verificar si tenemos todas las cookies requeridas
              const hasAllCookies = foundCookies.includes('SAPISID') && 
                                   foundCookies.includes('HSID') && 
                                   foundCookies.includes('SID') && 
                                   foundCookies.includes('APISID');
              
              if (hasAllCookies && extractedCookies.length > 0) {
                return JSON.stringify({
                  isLoggedIn: true,
                  cookies: extractedCookies.join('; '),
                  message: 'Cookies obtenidas en Gmail',
                  foundCookies: foundCookies
                });
              } else {
                // Si faltan cookies, esperar un poco más
                const missingCookies = requiredCookies.filter(cookie => !foundCookies.includes(cookie));
                console.log('⚠️ Cookies faltantes en Gmail:', missingCookies);
                
                return JSON.stringify({
                  isLoggedIn: false,
                  cookies: null,
                  error: 'waiting_hsid',
                  message: 'Esperando que se generen todas las cookies en Gmail...',
                  foundCookies: foundCookies
                });
              }
            }
            
            // Si estamos en Google Maps, probablemente ya estamos logueados
            if (isOnGoogleMaps) {
              console.log('🔍 Usuario en Google Maps - verificando cookies...');
              
              // Extraer cookies específicas necesarias para Google Maps
              const cookiePairs = cookies.split(';');
              const requiredCookies = ['SAPISID', 'HSID', 'SID', 'APISID'];
              const extractedCookies = [];
              const foundCookies = [];
              
              for (const pair of cookiePairs) {
                const [name, value] = pair.trim().split('=');
                if (requiredCookies.includes(name)) {
                  extractedCookies.push(name + '=' + value);
                  foundCookies.push(name);
                }
              }
              
              console.log('🔍 Cookies encontradas en Maps:', foundCookies);
              
              // Verificar si tenemos todas las cookies requeridas
              const hasAllCookies = foundCookies.includes('SAPISID') && 
                                   foundCookies.includes('HSID') && 
                                   foundCookies.includes('SID') && 
                                   foundCookies.includes('APISID');
              
              if (hasAllCookies && extractedCookies.length > 0) {
                return JSON.stringify({
                  isLoggedIn: true,
                  cookies: extractedCookies.join('; '),
                  message: 'Sesión completa detectada en Google Maps',
                  foundCookies: foundCookies
                });
              } else {
                // Si faltan cookies, intentar navegar a Gmail para obtenerlas
                const missingCookies = requiredCookies.filter(cookie => !foundCookies.includes(cookie));
                console.log('⚠️ Cookies faltantes en Maps:', missingCookies);
                
                if (missingCookies.includes('HSID')) {
                  // HSID se genera mejor en Gmail
                  console.log('🔄 Navegando a Gmail para obtener HSID...');
                  window.location.href = 'https://mail.google.com/mail/u/0/#inbox';
                  return JSON.stringify({
                    isLoggedIn: false,
                    cookies: null,
                    error: 'missing_hsid',
                    message: 'Navegando a Gmail para obtener la cookie HSID...',
                    foundCookies: foundCookies
                  });
                }
                
                return JSON.stringify({
                  isLoggedIn: false,
                  cookies: null,
                  error: 'missing_cookies',
                  message: 'Faltan cookies necesarias. Por favor, inicia sesión nuevamente.',
                  foundCookies: foundCookies
                });
              }
            }
            
            const hasGoogleSession = cookies.includes('SAPISID') && 
                                   cookies.includes('HSID') && 
                                   cookies.includes('SID');
            
            console.log('🔍 ¿Tiene sesión de Google?', hasGoogleSession);
            
            if (hasGoogleSession) {
              // Extraer cookies específicas necesarias para Google Maps
              const cookiePairs = cookies.split(';');
              const requiredCookies = ['SAPISID', 'HSID', 'SID', 'SSID', 'APISID'];
              const extractedCookies = [];
              
              for (const pair of cookiePairs) {
                const [name, value] = pair.trim().split('=');
                if (requiredCookies.includes(name)) {
                  extractedCookies.push(name + '=' + value);
                }
              }
              
              console.log('🔍 Cookies extraídas:', extractedCookies);
              
              return JSON.stringify({
                isLoggedIn: true,
                cookies: extractedCookies.join('; ')
              });
            }
            
            return JSON.stringify({
              isLoggedIn: false,
              cookies: null,
              error: 'no_cookies',
              message: 'No se detectaron cookies de sesión. Por favor, inicia sesión.'
            });
          } catch (error) {
            return JSON.stringify({
              isLoggedIn: false,
              cookies: null,
              error: error.toString()
            });
          }
        })();
      ''');

      if (result != null) {
        try {
          final resultString = result.toString();
          print('🔍 Resultado JavaScript: $resultString');

          final data = json.decode(resultString);
          print('🔍 Datos parseados: $data');

          if (data['isLoggedIn'] == true && data['cookies'] != null) {
            setState(() {
              _isLoggedIn = true;
              _statusMessage = '¡Sesión iniciada! Exportando a Google Maps...';
            });

            // Pequeña pausa para mostrar el mensaje
            await Future.delayed(const Duration(seconds: 1));

            // Cerrar diálogo y pasar las cookies
            Navigator.of(context).pop(); // Cerrar automáticamente
            widget.onLoginSuccess(data['cookies']);
          } else if (data['error'] == 'biometric_error') {
            setState(() {
              _statusMessage = data['message'] ??
                  'Por favor, usa tu contraseña en lugar de la huella digital';
            });
          } else if (data['error'] == 'not_logged_in') {
            setState(() {
              _statusMessage =
                  'Por favor, inicia sesión con tu cuenta de Google';
            });

            // Solo reintentar si no hemos alcanzado el límite
            if (_checkAttempts < maxCheckAttempts) {
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                _checkLoginStatus();
              }
            } else {
              print(
                  '🛑 Límite de intentos alcanzado. Deteniendo verificaciones automáticas.');
            }
          } else if (data['error'] == 'no_cookies' ||
              data['error'] == 'missing_cookies' ||
              data['error'] == 'missing_hsid' ||
              data['error'] == 'waiting_hsid') {
            String message = data['message'] ??
                'No se detectaron cookies de sesión. Por favor, inicia sesión.';

            // Si tenemos información sobre las cookies encontradas, mostrarla
            if (data['foundCookies'] != null) {
              final foundCookies = List<String>.from(data['foundCookies']);
              final missingCookies = ['SAPISID', 'HSID', 'SID', 'APISID']
                  .where((cookie) => !foundCookies.contains(cookie))
                  .toList();

              if (missingCookies.isNotEmpty) {
                if (missingCookies.contains('HSID')) {
                  if (data['error'] == 'waiting_hsid') {
                    message =
                        'Esperando que se genere la cookie HSID en Gmail...';
                  } else {
                    message =
                        'Falta la cookie HSID. Navegando a Gmail para obtenerla...';
                  }
                } else {
                  message =
                      'Faltan cookies: ${missingCookies.join(', ')}. Por favor, inicia sesión nuevamente.';
                }
              }
            }

            setState(() {
              _statusMessage = message;
            });

            // Solo reintentar si no hemos alcanzado el límite
            if (_checkAttempts < maxCheckAttempts) {
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                _checkLoginStatus();
              }
            } else {
              print(
                  '🛑 Límite de intentos alcanzado. Deteniendo verificaciones automáticas.');
            }
          } else {
            setState(() {
              _statusMessage =
                  data['message'] ?? 'Por favor, inicia sesión en Google';
            });

            // Solo reintentar si no hemos alcanzado el límite
            if (_checkAttempts < maxCheckAttempts) {
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                _checkLoginStatus();
              }
            } else {
              print(
                  '🛑 Límite de intentos alcanzado. Deteniendo verificaciones automáticas.');
            }
          }
        } catch (e) {
          print('❌ Error parseando resultado: $e');
          print('❌ Resultado original: $result');
          setState(() {
            _statusMessage = 'Error verificando sesión';
          });
        }
      }
    } catch (e) {
      print('Error verificando login: $e');
      setState(() {
        _statusMessage = 'Error verificando sesión';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Header más compacto
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Exportar a Google Maps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.grey[600],
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),

            // WebView
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    Container(
                      color: Colors.white.withOpacity(0.8),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Cargando...'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Footer más compacto
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Inicia sesión con tu cuenta de Google para exportar la guía a una lista privada en Maps',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange[600],
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '⚠️ Usa tu contraseña, no la huella digital',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: Colors.blue[600],
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '💡 Si faltan cookies, el sistema navegará automáticamente a Gmail para obtenerlas',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.green[600],
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '🔐 Necesitamos las cookies SAPISID, HSID, SID y APISID para crear la lista privada',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoggedIn) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '¡Listo! La guía se exportará automáticamente',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _checkAttempts = 0;
                                _statusMessage = 'Recargando página...';
                              });
                              print('🔄 Usuario solicitó reintento manual');
                              _controller.reload();
                            },
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Reintentar',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
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
      ),
    );
  }
}
