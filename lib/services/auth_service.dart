import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'analytics_service.dart';
import 'navigation_service.dart';
import '../config/api_config.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Check if user is authenticated
  static bool get isAuthenticated => _auth.currentUser != null;

  // Get user ID
  static String? get userId => _auth.currentUser?.uid;

  // Listen to auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get Firebase ID token for authentication
  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user authenticated');
        return null;
      }

      return await user.getIdToken(forceRefresh);
    } catch (e) {
      print('Error getting ID token: $e');
      return null;
    }
  }

  // ========== SMS VERIFICATION ==========

  /// Verifica un número de teléfono enviando un SMS
  static Future<Map<String, dynamic>> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String, int?) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
    MultiFactorSession? multiFactorSession,
  }) async {
    try {
      print('📱 Iniciando verificación SMS para: $phoneNumber');

      // Configurar timeout más largo para desarrollo
      const timeout = Duration(seconds: 90);

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        multiFactorSession: multiFactorSession,
        verificationCompleted: onVerificationCompleted,
        verificationFailed: onVerificationFailed,
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
        timeout: timeout,
      );

      return {'success': true};
    } catch (e) {
      print('❌ Error en verifyPhoneNumber: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verifica el código SMS recibido
  static Future<Map<String, dynamic>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      print('🔐 Verificando código SMS: $smsCode');

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Intentar iniciar sesión con la credencial
      final userCredential = await _auth.signInWithCredential(credential);

      print(
          '✅ Verificación SMS exitosa para: ${userCredential.user?.phoneNumber}');

      // Crear documento de usuario si no existe
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
        // Registrar el login para analytics
        AnalyticsService.trackLogin('sms');
      }

      return {
        'success': true,
        'user': userCredential.user,
        'credential': credential,
      };
    } catch (e) {
      print('❌ Error verificando código SMS: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Formatea un número de teléfono para Firebase
  static String formatPhoneNumber(String phoneNumber) {
    // Remover espacios, guiones y paréntesis
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Si no empieza con +, añadir +34 automáticamente
    if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('+')) {
      return '+34$cleanPhone';
    }

    return cleanPhone;
  }

  /// Valida un número de teléfono
  static bool isValidPhoneNumber(String phoneNumber) {
    // Patrón para números españoles
    final phoneRegex = RegExp(r'^(\+34|34)?[6-9]\d{8}$');
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return phoneRegex.hasMatch(cleanPhone);
  }

  /// Maneja errores específicos de Firebase Auth
  static String getFirebaseAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-phone-number':
        return 'El número de teléfono no es válido. Asegúrate de incluir el código de país (+34)';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos antes de volver a intentar';
      case 'quota-exceeded':
        return 'Cuota de SMS excedida. Intenta más tarde';
      case 'credential-already-in-use':
        return 'Este número de teléfono ya está asociado con otra cuenta';
      case 'operation-not-allowed':
        return 'La autenticación por SMS no está habilitada en Firebase';
      case 'missing-phone-number':
        return 'Número de teléfono requerido';
      case 'web-network-request-failed':
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu internet y vuelve a intentar';
      case 'app-not-authorized':
        return 'La aplicación no está autorizada para usar autenticación SMS';
      case 'captcha-check-failed':
        return 'Verificación reCAPTCHA fallida. Intenta de nuevo';
      case 'invalid-verification-code':
        return 'Código de verificación incorrecto. Verifica el código SMS';
      case 'invalid-verification-id':
        return 'ID de verificación inválido. Solicita un nuevo código';
      case 'session-expired':
        return 'Sesión expirada. Solicita un nuevo código SMS';
      default:
        return 'Error de verificación: $errorCode';
    }
  }

  // Sign in with email and password
  static Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document if it doesn't exist
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
        // Registrar el login para analytics
        AnalyticsService.trackLogin('email');
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with email and password: $e');
      return null;
    }
  }

  // Register with email and password
  static Future<UserCredential?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
        // Registrar el registro para analytics
        AnalyticsService.trackLogin('email_register');
      }

      return userCredential;
    } catch (e) {
      print('Error registering with email and password: $e');
      return null;
    }
  }

  // Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Google Sign In was canceled by user');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Create or update user document
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
        // Registrar el login para analytics
        AnalyticsService.trackLogin('google');
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      // Re-lanzar el error para que el código llamador pueda manejarlo
      rethrow;
    }
  }

  // Sign in with Google WITHOUT creating document automatically
  static Future<UserCredential?> signInWithGoogleNoDocument() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Google Sign In was canceled by user');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // NO create document automatically - let the calling code handle it
      print('Google Sign In completed without creating document automatically');

      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      // Re-lanzar el error para que el código llamador pueda manejarlo
      rethrow;
    }
  }

  // Sign in with Apple
  static Future<UserCredential?> signInWithApple() async {
    try {
      // Check if Apple Sign In is available
      if (!Platform.isIOS) {
        print('Apple Sign In is only available on iOS');
        return null;
      }

      // Check if Apple Sign In is available on this device
      final bool isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        print('Apple Sign In is not available on this device');
        return null;
      }

      // Request credential for the currently signed in Apple ID
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create an `OAuthCredential` from the credential returned by Apple
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Create or update user document
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
        // Registrar el login para analytics
        AnalyticsService.trackLogin('apple');
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Apple: $e');
      // Re-lanzar el error para que el código llamador pueda manejarlo
      rethrow;
    }
  }

  // Sign in with Apple WITHOUT creating document automatically
  static Future<UserCredential?> signInWithAppleNoDocument() async {
    try {
      // Check if Apple Sign In is available
      if (!Platform.isIOS) {
        print('Apple Sign In is only available on iOS');
        return null;
      }

      // Check if Apple Sign In is available on this device
      final bool isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        print('Apple Sign In is not available on this device');
        return null;
      }

      // Request credential for the currently signed in Apple ID
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create an `OAuthCredential` from the credential returned by Apple
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Update the user's display name if it's not set and we have it from Apple
      if (userCredential.user != null &&
          userCredential.user!.displayName == null) {
        final String displayName = _buildDisplayNameFromApple(appleCredential);
        if (displayName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(displayName);
        }
      }

      // NO create document automatically - let the calling code handle it
      print('Apple Sign In completed without creating document automatically');

      return userCredential;
    } catch (e) {
      print('Error signing in with Apple: $e');
      return null;
    }
  }

  // Helper method to build display name from Apple ID credential
  static String _buildDisplayNameFromApple(
      AuthorizationCredentialAppleID credential) {
    if (credential.givenName != null && credential.familyName != null) {
      return '${credential.givenName} ${credential.familyName}';
    } else if (credential.givenName != null) {
      return credential.givenName!;
    } else if (credential.familyName != null) {
      return credential.familyName!;
    }
    return '';
  }

  // Sign out (handles Google Sign In and Apple Sign In)
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      // Note: Apple Sign In doesn't require explicit sign out
      // as it's handled automatically by Firebase Auth
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Create user document in Firestore
  static Future<void> _createUserDocument(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'email': user.email,
          'displayName': user.displayName,
          'name': user.displayName ?? 'Usuario',
          'username': user.email?.split('@')[0] ?? 'usuario',
          'photoURL': user.photoURL,
          'location': '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last login and ensure all fields are present
        final updates = <String, dynamic>{
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add missing fields if they don't exist
        final existingData = docSnapshot.data() as Map<String, dynamic>;
        if (!existingData.containsKey('name') || existingData['name'] == null) {
          updates['name'] = user.displayName ?? 'Usuario';
        }
        if (!existingData.containsKey('username') ||
            existingData['username'] == null) {
          updates['username'] = user.email?.split('@')[0] ?? 'usuario';
        }
        if (!existingData.containsKey('location')) {
          updates['location'] = '';
        }

        await userDoc.update(updates);
      }
    } catch (e) {
      print('Error creating/updating user document: $e');
    }
  }

  // Get user data from Firestore
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // ========== REMEMBER ME FUNCTIONALITY ==========

  // Save credentials for remember me functionality
  static Future<void> saveCredentialsForRememberMe(
      String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
    } catch (e) {
      print('Error guardando credenciales: $e');
    }
  }

  // Save remember me status
  static Future<void> saveRememberMeStatus(bool remember) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', remember);
    } catch (e) {
      print('Error guardando estado de recordar: $e');
    }
  }

  // Get remember me status
  static Future<bool> getRememberMeStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('remember_me') ?? false;
    } catch (e) {
      print('Error obteniendo estado de recordar: $e');
      return false;
    }
  }

  // Get saved credentials
  static Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'email': prefs.getString('saved_email'),
        'password': prefs.getString('saved_password'),
      };
    } catch (e) {
      print('Error obteniendo credenciales guardadas: $e');
      return {'email': null, 'password': null};
    }
  }

  // Check if user should be remembered
  static Future<bool> shouldRememberUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('remember_me') ?? false;
    } catch (e) {
      return false;
    }
  }

  // Check if has valid session (user logged + remember me active)
  static Future<bool> hasValidSession() async {
    try {
      final user = _auth.currentUser;
      final shouldRemember = await shouldRememberUser();

      return user != null && shouldRemember;
    } catch (e) {
      return false;
    }
  }

  // Clear all remembered credentials and status
  static Future<void> clearRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.remove('remember_me');
    } catch (e) {
      print('Error limpiando credenciales recordadas: $e');
    }
  }

  // Check if stored credentials exist
  static Future<bool> hasStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasEmail = prefs.containsKey('saved_email');
      final hasPassword = prefs.containsKey('saved_password');
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');

      final result = hasEmail &&
          hasPassword &&
          savedEmail != null &&
          savedPassword != null;

      return result;
    } catch (e) {
      return false;
    }
  }

  // Enhanced sign out that also clears remember me if needed
  static Future<void> signOutAndClearRememberMe() async {
    try {
      await clearRememberedCredentials();
      await _googleSignIn.signOut();
      // Note: Apple Sign In doesn't require explicit sign out
      // as it's handled automatically by Firebase Auth
      await _auth.signOut();
    } catch (e) {
      print('Error signing out and clearing remember me: $e');
    }
  }

  // Delete user account completely
  static Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Obtener el token de autenticación
      final idToken = await user.getIdToken();
      if (idToken == null) {
        throw Exception('No se pudo obtener el token de autenticación');
      }

      // Llamar al nuevo endpoint del backend para eliminar la propia cuenta
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        // Si el backend eliminó exitosamente la cuenta, limpiar datos locales y cerrar sesión en cliente
        await clearRememberedCredentials();
        await _googleSignIn.signOut();
        try {
          await _auth.signOut();
        } catch (_) {}

        print('✅ Cuenta eliminada exitosamente por el backend');
        return true;
      } else {
        final errorData = json.decode(response.body);
        print('❌ Error del backend: ${errorData['error']}');
        throw Exception(errorData['error'] ?? 'Error al eliminar la cuenta');
      }
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  // ========== DEEP LINK HANDLING ==========

  // Callback para cuando se completa el captcha durante onboarding
  static Function()? _onCaptchaCompleted;

  /// Registra un callback para cuando se complete el captcha durante onboarding
  static void registerOnCaptchaCompleted(Function() callback) {
    _onCaptchaCompleted = callback;
    print('📱 Callback de captcha registrado para onboarding');
  }

  /// Limpia el callback de captcha
  static void clearOnCaptchaCompleted() {
    _onCaptchaCompleted = null;
    print('📱 Callback de captcha limpiado');
  }

  /// Verifica si el callback de captcha está registrado
  static bool get isCaptchaCallbackRegistered => _onCaptchaCompleted != null;

  /// Fuerza la navegación de vuelta al onboarding después del captcha
  static void forceReturnToOnboarding() {
    print('📱 Forzando retorno al onboarding después del captcha');

    // Navegar de vuelta al onboarding usando el método correcto
    NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/onboarding',
      (route) => false,
    );

    // Ejecutar callback si existe
    if (_onCaptchaCompleted != null) {
      print('📱 Ejecutando callback de captcha completado');
      _onCaptchaCompleted!();
    }
  }

  /// Maneja deep links de Firebase Auth de manera segura
  static Future<void> handleFirebaseAuthDeepLink(String deepLink,
      {bool preserveOnboarding = false}) async {
    try {
      print(
          '🔗 Procesando deep link de Firebase Auth: ${deepLink.substring(0, 100)}...');
      print('📱 Preservar onboarding: $preserveOnboarding');

      // Verificar si es un deep link de verificación de app
      print('🔍 Evaluando condiciones del deep link:');
      print('  - Contiene deep_link_id: ${deepLink.contains('deep_link_id=')}');
      print(
          '  - Contiene authType=verifyApp: ${deepLink.contains('authType=verifyApp')}');
      print(
          '  - Contiene auth/callback: ${deepLink.contains('auth/callback')}');

      if (deepLink.contains('deep_link_id=')) {
        print(
            '✅ Deep link con deep_link_id detectado (probablemente captcha completado)');

        AnalyticsService.trackEvent('auth_deep_link', parameters: {
          'type': 'captcha_completed',
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Si estamos preservando el onboarding, ejecutar callback
        if (preserveOnboarding && _onCaptchaCompleted != null) {
          print('📱 Ejecutando callback de captcha completado');
          _onCaptchaCompleted!();
          return;
        } else if (preserveOnboarding) {
          print(
              '📱 Preservando onboarding pero no hay callback, forzando retorno');
          forceReturnToOnboarding();
          return;
        }
      } else if (deepLink.contains('authType=verifyApp')) {
        print('✅ Deep link de verificación de app detectado');

        // Registrar evento de analytics sin exponer datos sensibles
        AnalyticsService.trackEvent('auth_deep_link', parameters: {
          'type': 'verify_app',
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Procesar el deep link de manera segura
        await _processVerifyAppDeepLink(deepLink);

        // Si estamos preservando el onboarding, ejecutar callback
        if (preserveOnboarding && _onCaptchaCompleted != null) {
          print('📱 Ejecutando callback de captcha completado');
          _onCaptchaCompleted!();
          return;
        } else if (preserveOnboarding) {
          print(
              '📱 Preservando onboarding pero no hay callback, forzando retorno');
          forceReturnToOnboarding();
          return;
        }
      } else if (deepLink.contains('auth/callback')) {
        print('✅ Deep link de callback de auth detectado');

        AnalyticsService.trackEvent('auth_deep_link', parameters: {
          'type': 'auth_callback',
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Si estamos preservando el onboarding, ejecutar callback
        if (preserveOnboarding && _onCaptchaCompleted != null) {
          print('📱 Ejecutando callback de captcha completado');
          _onCaptchaCompleted!();
          return;
        } else if (preserveOnboarding) {
          print(
              '📱 Preservando onboarding pero no hay callback, forzando retorno');
          forceReturnToOnboarding();
          return;
        }
      } else {
        print('ℹ️ Deep link de Firebase Auth no reconocido');

        AnalyticsService.trackEvent('auth_deep_link', parameters: {
          'type': 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Solo navegar a home si no estamos preservando el onboarding
      if (!preserveOnboarding) {
        print('🏠 Navegando a home después del deep link');
        // Aquí podrías agregar la navegación a home si es necesaria
      }
    } catch (e) {
      print('❌ Error procesando deep link de Firebase Auth: $e');

      AnalyticsService.trackEvent('auth_deep_link_error', parameters: {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Procesa deep links de verificación de app de manera segura
  static Future<void> _processVerifyAppDeepLink(String deepLink) async {
    try {
      // Extraer información relevante sin exponer tokens sensibles
      final uri = Uri.parse(deepLink);
      final authType = uri.queryParameters['authType'];
      final eventId = uri.queryParameters['eventId'];

      print('🔍 Parámetros extraídos del deep link:');
      print('  - authType: $authType');
      print('  - eventId: $eventId');

      // Registrar evento de verificación exitosa
      if (authType == 'verifyApp') {
        AnalyticsService.trackEvent('app_verification_success', parameters: {
          'event_id': eventId ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('❌ Error procesando deep link de verificación: $e');
    }
  }

  /// Verifica si una URL es un deep link de Firebase Auth
  static bool isFirebaseAuthDeepLink(String url) {
    final containsFirebaseAuth = url.contains('firebaseauth');
    final containsAuthCallback = url.contains('auth/callback');
    final containsRecaptchaToken = url.contains('recaptchaToken');
    final containsAuthTypeVerifyApp = url.contains('authType=verifyApp');
    final containsDeepLinkId = url.contains('deep_link_id=');

    print('🔍 Verificando si es deep link de Firebase Auth:');
    print(
        '  - URL: ${url.substring(0, url.length > 100 ? 100 : url.length)}...');
    print('  - Contiene firebaseauth: $containsFirebaseAuth');
    print('  - Contiene auth/callback: $containsAuthCallback');
    print('  - Contiene recaptchaToken: $containsRecaptchaToken');
    print('  - Contiene authType=verifyApp: $containsAuthTypeVerifyApp');
    print('  - Contiene deep_link_id: $containsDeepLinkId');

    final isFirebaseAuth = containsFirebaseAuth ||
        containsAuthCallback ||
        containsRecaptchaToken ||
        containsAuthTypeVerifyApp ||
        containsDeepLinkId;

    print('  - Es deep link de Firebase Auth: $isFirebaseAuth');

    return isFirebaseAuth;
  }

  /// Sanitiza una URL para analytics (remueve datos sensibles)
  static String sanitizeUrlForAnalytics(String url) {
    if (isFirebaseAuthDeepLink(url)) {
      return 'firebase_auth_deep_link';
    }

    if (url.startsWith('http') || url.contains('://')) {
      return 'external_deep_link';
    }

    if (url.length > 100) {
      return url.substring(0, 97) + '...';
    }

    return url;
  }

  // ========== MULTI-FACTOR AUTHENTICATION (2FA) ==========

  /// Verifica si el usuario tiene MFA habilitado (implementación básica)
  static bool get hasMultiFactor {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Por ahora, verificamos si el usuario tiene un número de teléfono verificado
    // En el futuro, esto se puede expandir para usar la API MFA real
    return user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
  }

  /// Obtiene información del MFA del usuario
  static Map<String, dynamic> getMultiFactorInfo() {
    final user = _auth.currentUser;
    if (user == null) return {};

    return {
      'hasPhone': user.phoneNumber != null && user.phoneNumber!.isNotEmpty,
      'phoneNumber': user.phoneNumber,
      'isEmailVerified': user.emailVerified,
      'providerData': user.providerData.map((p) => p.providerId).toList(),
    };
  }

  /// Configura SMS como segundo factor (implementación básica)
  static Future<Map<String, dynamic>> setupSMSAsSecondFactor({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String, int?) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No hay usuario autenticado',
        };
      }

      print('🔐 Configurando SMS como segundo factor para: $phoneNumber');

      // Obtener sesión MFA para enrolamiento de segundo factor
      MultiFactorSession session = await user.multiFactor.getSession();

      // Usar el método de verificación SMS con sesión MFA
      final result = await verifyPhoneNumber(
        phoneNumber: phoneNumber,
        multiFactorSession: session,
        onVerificationCompleted: onVerificationCompleted,
        onVerificationFailed: onVerificationFailed,
        onCodeSent: onCodeSent,
        onCodeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      );

      if (result['success']) {
        print('✅ Configuración de SMS iniciada correctamente');
      }

      return result;
    } catch (e) {
      print('❌ Error configurando SMS como segundo factor: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verifica código SMS para configurar como segundo factor
  static Future<Map<String, dynamic>> verifySMSAsSecondFactor({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      print('🔐 Verificando código SMS para segundo factor: $smsCode');

      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No hay usuario autenticado',
        };
      }

      // Crear la credencial de teléfono
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      try {
        // Intentar enrolear el segundo factor
        final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
        await user.multiFactor.enroll(assertion);

        print('✅ SMS enrolando como segundo factor exitosamente');

        // Registrar el evento de analytics
        AnalyticsService.trackEvent('second_factor_sms_setup', parameters: {
          'method': 'sms',
          'timestamp': DateTime.now().toIso8601String(),
        });

        return {
          'success': true,
          'message': 'Segundo factor configurado exitosamente',
        };
      } on FirebaseAuthException catch (e) {
        // Si requiere reautenticación reciente
        if (e.code == 'requires-recent-login' ||
            e.code == 'auth/requires-recent-login' ||
            (e.message?.toLowerCase().contains('recent login') ?? false)) {
          print('⚠️ Sesión expirada, requiriendo reautenticación');

          // Intentar reautenticar con el proveedor actual
          try {
            final providerData = user.providerData;
            if (providerData.isNotEmpty) {
              final providerId = providerData.first.providerId;

              if (providerId == 'google.com') {
                // Reautenticar con Google
                final googleCredential = await _getGoogleCredential();
                if (googleCredential != null) {
                  await user.reauthenticateWithCredential(googleCredential);

                  // Intentar enrolear de nuevo
                  final assertion =
                      PhoneMultiFactorGenerator.getAssertion(credential);
                  await user.multiFactor.enroll(assertion);

                  print(
                      '✅ SMS enrolando como segundo factor después de reautenticación');

                  return {
                    'success': true,
                    'message': 'Segundo factor configurado exitosamente',
                  };
                }
              } else if (providerId == 'apple.com') {
                // Reautenticar con Apple
                final appleCredential = await _getAppleCredential();
                if (appleCredential != null) {
                  await user.reauthenticateWithCredential(appleCredential);

                  // Intentar enrolear de nuevo
                  final assertion =
                      PhoneMultiFactorGenerator.getAssertion(credential);
                  await user.multiFactor.enroll(assertion);

                  print(
                      '✅ SMS enrolando como segundo factor después de reautenticación');

                  return {
                    'success': true,
                    'message': 'Segundo factor configurado exitosamente',
                  };
                }
              }
            }
          } catch (reauthError) {
            print('❌ Error en reautenticación: $reauthError');
            return {
              'success': false,
              'error': 'Sesión expirada. Por favor, inicia sesión de nuevo.',
            };
          }
        }

        return {
          'success': false,
          'error': e.message ?? 'Error configurando segundo factor',
        };
      }
    } catch (e) {
      print('❌ Error verificando SMS como segundo factor: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Enrola el segundo factor directamente con una credencial de teléfono (auto-verificación)
  static Future<Map<String, dynamic>> enrollSecondFactorWithCredential({
    required PhoneAuthCredential credential,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No hay usuario autenticado',
        };
      }

      final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
      await user.multiFactor.enroll(assertion);

      AnalyticsService.trackEvent('second_factor_sms_setup', parameters: {
        'method': 'sms',
        'timestamp': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'Segundo factor configurado exitosamente',
      };
    } on FirebaseAuthException catch (e) {
      // Reautenticación si es necesario
      if (e.code == 'requires-recent-login' ||
          e.code == 'auth/requires-recent-login' ||
          (e.message?.toLowerCase().contains('recent login') ?? false)) {
        try {
          final user = _auth.currentUser;
          if (user != null && user.providerData.isNotEmpty) {
            final providerId = user.providerData.first.providerId;
            if (providerId == 'google.com') {
              final googleCredential = await _getGoogleCredential();
              if (googleCredential != null) {
                await user.reauthenticateWithCredential(googleCredential);
              }
            } else if (providerId == 'apple.com') {
              final appleCredential = await _getAppleCredential();
              if (appleCredential != null) {
                await user.reauthenticateWithCredential(appleCredential);
              }
            }
            // Enrolar de nuevo
            final assertion =
                PhoneMultiFactorGenerator.getAssertion(credential);
            await user.multiFactor.enroll(assertion);
            return {
              'success': true,
              'message': 'Segundo factor configurado exitosamente',
            };
          }
        } catch (reauthError) {
          print('❌ Error en reautenticación (auto-verificación): $reauthError');
          return {
            'success': false,
            'error': 'Sesión expirada. Por favor, inicia sesión de nuevo.',
          };
        }
      }
      return {
        'success': false,
        'error': e.message ?? 'Error configurando segundo factor',
      };
    } catch (e) {
      print('❌ Error enrolando segundo factor con credencial: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Obtiene credencial de Google para reautenticación
  static Future<AuthCredential?> _getGoogleCredential() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      return GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
    } catch (e) {
      print('❌ Error obteniendo credencial de Google: $e');
      return null;
    }
  }

  /// Obtiene credencial de Apple para reautenticación
  static Future<AuthCredential?> _getAppleCredential() async {
    try {
      if (!Platform.isIOS) return null;

      final bool isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) return null;

      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      return OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
    } catch (e) {
      print('❌ Error obteniendo credencial de Apple: $e');
      return null;
    }
  }

  /// Maneja el inicio de sesión con segundo factor requerido
  static Future<Map<String, dynamic>> handleSecondFactorSignIn({
    required String phoneNumber,
    required Function(String, int?) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    try {
      print('🔐 Manejando inicio de sesión con segundo factor requerido');

      // Enviar SMS para el segundo factor
      final result = await verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onVerificationCompleted: (credential) async {
          print('📱 Auto-verificación completada para segundo factor');
          // Aquí podrías manejar la auto-verificación
        },
        onVerificationFailed: onVerificationFailed,
        onCodeSent: onCodeSent,
        onCodeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      );

      return result;
    } catch (e) {
      print('❌ Error manejando segundo factor sign-in: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verifica si el usuario necesita segundo factor
  static bool requiresSecondFactor() {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Por ahora, verificamos si el usuario tiene email pero no teléfono
    // Esto es una implementación básica
    return user.email != null &&
        user.email!.isNotEmpty &&
        (user.phoneNumber == null || user.phoneNumber!.isEmpty);
  }

  /// Obtiene el número de teléfono del usuario para segundo factor
  static String? getSecondFactorPhone() {
    final user = _auth.currentUser;
    return user?.phoneNumber;
  }
}
