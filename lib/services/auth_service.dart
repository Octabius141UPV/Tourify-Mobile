import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

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
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
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

      // Sign in the user with Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Update the user's display name if it's not set and we have it from Apple
      if (userCredential.user != null &&
          userCredential.user!.displayName == null) {
        final String displayName = _buildDisplayNameFromApple(appleCredential);
        if (displayName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(displayName);
        }
      }

      // Create or update user document
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }

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

      print('🔍 Debug credenciales:');
      print('  - hasEmail: $hasEmail');
      print('  - hasPassword: $hasPassword');
      print(
          '  - savedEmail: ${savedEmail != null ? "✅ SÍ (${savedEmail.substring(0, 3)}...)" : "❌ NO"}');
      print(
          '  - savedPassword: ${savedPassword != null ? "✅ SÍ (${savedPassword.length} chars)" : "❌ NO"}');

      final result = hasEmail &&
          hasPassword &&
          savedEmail != null &&
          savedPassword != null;
      print('  - Resultado final: $result');

      return result;
    } catch (e) {
      print('❌ Error en hasStoredCredentials: $e');
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
}
