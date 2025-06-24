import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tourify_flutter/config/api_config.dart';

class CollaboratorsService {
  // Usar ApiConfig en lugar de configuración local
  static String get baseUrl => ApiConfig.baseUrl;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  // Obtener colaboradores de una guía
  Future<Map<String, dynamic>> getCollaborators(String guideId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('$baseUrl/collaborators/$guideId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print('Status: \\${response.statusCode}');
      print('Body: \\${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        // Si no hay colaboradores, retornar listas vacías
        return {
          'collaborators': [],
          'userRole': null,
          'success': false,
          'canEdit': false
        };
      } else {
        throw Exception(
            'Error al obtener colaboradores: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getCollaborators: $e');

      // Fallback a Firestore si el servidor no está disponible
      try {
        final doc = await _firestore.collection('guides').doc(guideId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'collaborators': data['collaborators'] ?? [],
            'userRole': null,
            'success': false,
            'canEdit': false
          };
        }
      } catch (firestoreError) {
        print('Error en Firestore fallback: $firestoreError');
      }

      return {
        'collaborators': [],
        'userRole': null,
        'success': false,
        'canEdit': false
      };
    }
  }

  // Añadir colaborador
  Future<Map<String, dynamic>> addCollaborator({
    required String guideId,
    required String email,
    required String role,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/collaborators/add'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'guideId': guideId,
          'email': email,
          'role': role,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message':
              responseData['message'] ?? 'Colaborador añadido correctamente',
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Error al añadir colaborador',
        };
      }
    } catch (e) {
      print('Error en addCollaborator: $e');

      // Fallback a Firestore
      try {
        final docRef = _firestore.collection('guides').doc(guideId);
        final doc = await docRef.get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final List<dynamic> collaborators =
              List.from(data['collaborators'] ?? []);

          // Verificar si el colaborador ya existe
          final existingIndex = collaborators.indexWhere(
            (collab) => collab['email'] == email,
          );

          if (existingIndex >= 0) {
            // Actualizar el rol si ya existe
            collaborators[existingIndex]['role'] = role;
          } else {
            // Añadir nuevo colaborador
            collaborators.add({
              'email': email,
              'role': role,
              'addedAt': FieldValue.serverTimestamp(),
            });
          }

          await docRef.update({'collaborators': collaborators});

          return {
            'success': true,
            'message': 'Colaborador añadido correctamente',
          };
        } else {
          throw Exception('Guía no encontrada');
        }
      } catch (firestoreError) {
        print('Error en Firestore fallback: $firestoreError');
        return {
          'success': false,
          'error':
              'Error al añadir colaborador: \\${firestoreError.toString()}',
        };
      }
    }
  }

  // Eliminar colaborador
  Future<Map<String, dynamic>> removeCollaborator(
    String guideId,
    String email,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final idToken = await user.getIdToken();

      final response = await http.delete(
        Uri.parse('$baseUrl/collaborators/$guideId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message':
              responseData['message'] ?? 'Colaborador eliminado correctamente',
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Error al eliminar colaborador',
        };
      }
    } catch (e) {
      print('Error en removeCollaborator: $e');

      // Fallback a Firestore
      try {
        final docRef = _firestore.collection('guides').doc(guideId);
        final doc = await docRef.get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final List<dynamic> collaborators =
              List.from(data['collaborators'] ?? []);

          // Eliminar el colaborador
          collaborators.removeWhere((collab) => collab['email'] == email);

          await docRef.update({'collaborators': collaborators});

          return {
            'success': true,
            'message': 'Colaborador eliminado correctamente',
          };
        } else {
          throw Exception('Guía no encontrada');
        }
      } catch (firestoreError) {
        print('Error en Firestore fallback: $firestoreError');
        return {
          'success': false,
          'error':
              'Error al eliminar colaborador: ${firestoreError.toString()}',
        };
      }
    }
  }

  // Verificar permisos del usuario actual
  Future<Map<String, dynamic>> getUserRole(String guideId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Usar directamente Firestore en lugar de la API
      final doc = await _firestore.collection('guides').doc(guideId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final String ownerId = data['userId'] ?? '';
        final List<dynamic> collaborators = data['collaborators'] ?? [];

        final String currentUserId = user.uid;
        final String? currentUserEmail = user.email;

        // Verificar si es el propietario
        if (ownerId == currentUserId) {
          return {
            'success': true,
            'role': 'owner',
            'canEdit': true,
            'isOwner': true,
          };
        }

        // Verificar en colaboradores
        if (currentUserEmail != null) {
          final collaborator = collaborators.firstWhere(
            (collab) => collab['email'] == currentUserEmail,
            orElse: () => null,
          );

          if (collaborator != null) {
            final String role = collaborator['role'] ?? 'viewer';
            return {
              'success': true,
              'role': role,
              'canEdit': role == 'editor',
              'isOwner': false,
            };
          }
        }

        // Sin permisos
        return {
          'success': true,
          'role': 'none',
          'canEdit': false,
          'isOwner': false,
        };
      } else {
        return {
          'success': false,
          'error': 'Guía no encontrada',
          'role': 'none',
          'canEdit': false,
          'isOwner': false,
        };
      }
    } catch (e) {
      print('Error en getUserRole: $e');
      return {
        'success': false,
        'error': e.toString(),
        'role': 'none',
        'canEdit': false,
        'isOwner': false,
      };
    }
  }

  // Generar un link de acceso para una guía
  Future<Map<String, dynamic>> generateAccessLink(
      String guideId, String role) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar que el usuario tiene permisos para generar links
      final guideDoc = await _firestore.collection('guides').doc(guideId).get();
      if (!guideDoc.exists) {
        throw Exception('La guía no existe');
      }

      final guideData = guideDoc.data()!;
      final String ownerId = guideData['userId'] ?? '';

      // Verificar si el usuario es el propietario
      if (ownerId != user.uid) {
        throw Exception('No tienes permisos para generar links de acceso');
      }

      // Generar token único
      final token = _uuid.v4();
      final expiresAt = DateTime.now().add(const Duration(days: 7));

      // Guardar el link en Firestore
      await _firestore
          .collection('guides')
          .doc(guideId)
          .collection('accessLinks')
          .doc(token)
          .set({
        'token': token,
        'role': role,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': true,
      });

      // Construir el link de acceso
      final accessLink = 'tourify://guide/$guideId?token=$token';

      return {
        'link': accessLink,
        'role': role,
        'expiresAt': expiresAt,
      };
    } catch (e) {
      print('Error al generar link de acceso: $e');
      rethrow;
    }
  }

  // Verificar un link de acceso
  Future<bool> verifyAccessLink(String guideId, String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Buscar el link en Firestore
      final linkDoc = await _firestore
          .collection('guides')
          .doc(guideId)
          .collection('accessLinks')
          .doc(token)
          .get();

      if (!linkDoc.exists) {
        return false;
      }

      final linkData = linkDoc.data()!;

      // Verificar que el link está activo y no ha expirado
      if (!linkData['isActive'] ||
          (linkData['expiresAt'] as Timestamp)
              .toDate()
              .isBefore(DateTime.now())) {
        return false;
      }

      // Agregar al usuario como colaborador
      await addCollaborator(
        guideId: guideId,
        email: user.email!,
        role: linkData['role'],
      );

      // Desactivar el link después de usarlo
      await linkDoc.reference.update({'isActive': false});

      return true;
    } catch (e) {
      print('Error al verificar link de acceso: $e');
      return false;
    }
  }

  // Obtener links de acceso activos
  Future<List<Map<String, dynamic>>> getActiveAccessLinks(
      String guideId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Solo comprobar que la guía existe
      final guideDoc = await _firestore.collection('guides').doc(guideId).get();
      if (!guideDoc.exists) {
        throw Exception('La guía no existe');
      }

      // Obtener links activos
      final linksSnapshot = await _firestore
          .collection('guides')
          .doc(guideId)
          .collection('accessLinks')
          .where('isActive', isEqualTo: true)
          .get();

      return linksSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'token': data['token'],
          'role': data['role'],
          'createdAt': data['createdAt'],
          'expiresAt': data['expiresAt'],
          'link': 'tourify://guide/$guideId?token=${data['token']}',
        };
      }).toList();
    } catch (e) {
      print('Error al obtener links de acceso: $e');
      rethrow;
    }
  }

  // Revocar un link de acceso
  Future<void> revokeAccessLink(String guideId, String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar que el usuario tiene permisos para revocar links
      final guideDoc = await _firestore.collection('guides').doc(guideId).get();
      if (!guideDoc.exists) {
        throw Exception('La guía no existe');
      }

      final guideData = guideDoc.data()!;
      if (guideData['userRef'] != user.uid) {
        throw Exception('No tienes permisos para revocar links de acceso');
      }

      // Desactivar el link
      await _firestore
          .collection('guides')
          .doc(guideId)
          .collection('accessLinks')
          .doc(token)
          .update({'isActive': false});
    } catch (e) {
      print('Error al revocar link de acceso: $e');
      rethrow;
    }
  }
}
