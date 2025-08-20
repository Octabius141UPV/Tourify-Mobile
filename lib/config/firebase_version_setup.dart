import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuración básica de versiones en Firebase
class FirebaseVersionSetup {
  static const String _collection = 'app_versions';
  static const String _document = 'config';

  /// Obtiene la configuración actual de versiones
  static Future<Map<String, dynamic>?> getCurrentConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_document)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }
}
