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

  // Función de reintento con backoff exponencial para errores de Firestore
  Future<T> _retryFirestoreOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        // Solo reintentar para errores de unavailable
        if (e.toString().contains('unavailable') ||
            e.toString().contains('UNAVAILABLE') ||
            e.toString().contains('service is currently unavailable')) {
          if (attempt == maxRetries - 1) {
            // Si es el último intento, lanzar la excepción
            throw Exception(
                'Servicio temporalmente no disponible. Por favor, inténtalo de nuevo en unos minutos.');
          }

          // Calcular delay con backoff exponencial: 1s, 2s, 4s...
          final delay = Duration(
              milliseconds: (initialDelay.inMilliseconds * (1 << attempt))
                  .clamp(1000, 10000));

          print(
              'Reintentando operación en ${delay.inSeconds}s (intento ${attempt + 1}/$maxRetries)');
          await Future.delayed(delay);
        } else {
          // Para otros errores, no reintentar
          rethrow;
        }
      }
    }

    // Esto no debería alcanzarse nunca
    throw Exception('Error inesperado en la operación de reintento');
  }

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

      // Debug info removed for performance

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
      // Error silencioso

      // Fallback a Firestore si el servidor no está disponible
      try {
        final doc = await _retryFirestoreOperation(
            () => _firestore.collection('guides').doc(guideId).get());
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
        // Error silencioso
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
      // Error silencioso

      // Fallback a Firestore con reintentos
      try {
        return await _retryFirestoreOperation(() async {
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
        });
      } catch (firestoreError) {
        // Error silencioso
        return {
          'success': false,
          'error': 'Error al añadir colaborador: ${firestoreError.toString()}',
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
        Uri.parse('$baseUrl/collaborators/remove'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'guideId': guideId,
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
      // Error silencioso

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
        // Error silencioso
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
        final List<dynamic> collaborators = data['collaborators'] ?? [];
        final String currentUserId = user.uid;
        final String? currentUserEmail = user.email;

        // Verificar también si hay colaboradores en subcolección
        try {
          final collaboratorsSubcollection = await _firestore
              .collection('guides')
              .doc(guideId)
              .collection('collaborators')
              .get();
        } catch (e) {
          // Error silencioso
        }

        // Verificar si es el propietario - 3 formas diferentes:
        bool isOwner = false;

        // 1. Verificar por userId (String)
        if (data['userId'] == currentUserId) {
          isOwner = true;
        }

        // 2. Verificar por authorId (String) - guías antiguas
        if (!isOwner && data['authorId'] == currentUserId) {
          isOwner = true;
        }

        // 3. Verificar por userRef (DocumentReference) - guías más recientes
        if (!isOwner && data['userRef'] != null) {
          try {
            final userRef = data['userRef'] as DocumentReference;
            final expectedUserRef =
                _firestore.collection('users').doc(currentUserId);
            if (userRef.path == expectedUserRef.path) {
              isOwner = true;
            }
          } catch (e) {
            // Error silencioso
          }
        }

        if (isOwner) {
          return {
            'success': true,
            'role': 'owner',
            'canEdit': true,
            'isOwner': true,
          };
        }

        // Verificar en colaboradores - TANTO en array como en subcolección
        if (currentUserEmail != null) {
          // 1. Verificar en el array principal
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

          // 2. Si no está en el array, verificar en la subcolección
          try {
            final collaboratorsSubcollection = await _firestore
                .collection('guides')
                .doc(guideId)
                .collection('collaborators')
                .where('email', isEqualTo: currentUserEmail)
                .limit(1)
                .get();

            if (collaboratorsSubcollection.docs.isNotEmpty) {
              final subcollectionData =
                  collaboratorsSubcollection.docs.first.data();
              final String role = subcollectionData['role'] ?? 'viewer';
              return {
                'success': true,
                'role': role,
                'canEdit': role == 'editor',
                'isOwner': false,
              };
            }
          } catch (e) {
            // Error silencioso
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
      return {
        'success': false,
        'error': e.toString(),
        'role': 'none',
        'canEdit': false,
        'isOwner': false,
      };
    }
  }

  // Obtener links de acceso activos desde el backend
  Future<List<Map<String, dynamic>>> getActiveAccessLinks(
      String guideId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse('$baseUrl/collaborators/active-links/$guideId'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['links'] ?? []);
    } else {
      throw Exception('Error al obtener links de acceso: ${response.body}');
    }
  }

  // Generar un link de acceso para una guía (solo vía backend)
  Future<Map<String, dynamic>> generateAccessLink(
      String guideId, String role) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$baseUrl/collaborators/generate-link'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'guideId': guideId,
        'role': role,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final result = json.decode(response.body);
      return result['link'] as Map<String, dynamic>;
    } else {
      throw Exception('Error al generar link de acceso: ${response.body}');
    }
  }

  // Revocar un link de acceso (solo vía backend)
  Future<void> revokeAccessLink(String guideId, String token) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$baseUrl/collaborators/revoke-link'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'guideId': guideId,
        'token': token,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al revocar link de acceso: ${response.body}');
    }
  }

  // Verificar un link de acceso y unirse como colaborador
  Future<bool> verifyAccessLink(String guideId, String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: Usuario no autenticado en verifyAccessLink');
        throw Exception('Usuario no autenticado');
      }

      print(
          'Verificando link de acceso y uniéndose como colaborador - Token: $token');

      // Usar el endpoint del servidor para verificar y unirse
      final idToken = await user.getIdToken();

      final response = await _retryFirestoreOperation(() async {
        final httpResponse = await http.post(
          Uri.parse('$baseUrl/collaborators/verify-and-join'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: json.encode({
            'token': token,
          }),
        );

        if (httpResponse.statusCode == 200) {
          final data = json.decode(httpResponse.body);
          print('Respuesta del servidor: ${data['message']}');
          return data;
        } else if (httpResponse.statusCode == 410) {
          throw Exception('Link expirado');
        } else if (httpResponse.statusCode == 404) {
          throw Exception('Token no válido o link inactivo');
        } else {
          final errorData = json.decode(httpResponse.body);
          throw Exception(errorData['error'] ?? 'Error al unirse a la guía');
        }
      });

      print(
          'Usuario agregado exitosamente como colaborador usando el servidor');
      return true;
    } catch (e) {
      print('Error en verifyAccessLink: $e');
      // Re-lanzar la excepción para que pueda ser manejada por el llamador
      rethrow;
    }
  }
}
