import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user data from Firestore
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Stream user data changes
  static Stream<DocumentSnapshot<Map<String, dynamic>>> getUserDataStream(
      String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Update user data
  static Future<bool> updateUserData(
      String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  // Create user document
  static Future<bool> createUserDocument(User user,
      {Map<String, dynamic>? additionalData}) async {
    try {
      final userData = {
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'name': user.displayName ?? 'Usuario',
        'username': user.email?.split('@')[0] ?? 'usuario',
        'location': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      await _firestore.collection('users').doc(user.uid).set(userData);
      return true;
    } catch (e) {
      print('Error creating user document: $e');
      return false;
    }
  }

  // Get user guides count
  static Future<int> getUserGuidesCount(String userId) async {
    try {
      // Crear referencia al documento del usuario
      final userRef = _firestore.collection('users').doc(userId);

      // Buscar guías donde userRef apunte a este usuario
      final snapshot = await _firestore
          .collection('guides')
          .where('userRef', isEqualTo: userRef)
          .get();

      print('Guides count for user $userId: ${snapshot.docs.length}');
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting guides count: $e');

      // Método alternativo: buscar por userId como string
      try {
        final alternativeSnapshot = await _firestore
            .collection('guides')
            .where('userId', isEqualTo: userId)
            .get();

        print(
            'Alternative guides count for user $userId: ${alternativeSnapshot.docs.length}');
        return alternativeSnapshot.docs.length;
      } catch (e2) {
        print('Error getting guides count with alternative method: $e2');
        return 0;
      }
    }
  }

  // Get user with stats
  static Future<Map<String, dynamic>?> getUserWithStats(String userId) async {
    try {
      final userData = await getUserData(userId);
      if (userData == null) return null;

      final guidesCount = await getUserGuidesCount(userId);

      return {
        ...userData,
        'stats': {
          'guides': guidesCount,
        },
      };
    } catch (e) {
      print('Error getting user with stats: $e');
      return null;
    }
  }

  // Update user profile in both Firestore and Firebase Auth
  static Future<bool> updateUserProfile({
    required String userId,
    String? name,
    String? username,
    String? location,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Prepare data for Firestore
      final firestoreData = <String, dynamic>{};
      if (name != null) firestoreData['name'] = name;
      if (username != null) firestoreData['username'] = username;
      if (location != null) firestoreData['location'] = location;
      if (photoURL != null) firestoreData['photoURL'] = photoURL;

      // Update Firestore
      await updateUserData(userId, firestoreData);

      // Update Firebase Auth profile if needed
      if (name != null && user.displayName != name) {
        await user.updateDisplayName(name);
      }
      if (photoURL != null && user.photoURL != photoURL) {
        await user.updatePhotoURL(photoURL);
      }

      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }
}
