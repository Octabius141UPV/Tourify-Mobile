import 'dart:convert';
import 'package:tourify_flutter/config/api_config.dart';
import 'package:http/http.dart' as http;

/// Servicio para crear y compartir MyMaps de Google
class MyMapsService {
  static String get _baseUrl => ApiConfig.baseUrl;

  /// Crea un MyMap y devuelve el enlace compartido
  /// Retorna un Map con el resultado de la operación
  static Future<Map<String, dynamic>> createMyMap({
    required String mapName,
    required List<Map<String, dynamic>> places,
  }) async {
    try {
      print('🗺️ Iniciando creación de MyMap...');
      print('📝 Nombre del mapa: $mapName');
      print('📍 Número de lugares: ${places.length}');

      // Validar datos de entrada
      if (mapName.trim().isEmpty) {
        return {
          'success': false,
          'error': 'El nombre del mapa no puede estar vacío',
        };
      }

      if (places.isEmpty) {
        return {
          'success': false,
          'error': 'No hay lugares para añadir al mapa',
        };
      }

      if (places.length > 2000) {
        return {
          'success': false,
          'error': 'El máximo de lugares por mapa es 2000',
        };
      }

      // Preparar datos para el backend
      final requestData = {
        'mapName': mapName.trim(),
        'places': places,
      };

      print('📤 Enviando datos al backend...');
      print('🔗 URL del endpoint: $_baseUrl/my-maps/create');

      // Realizar petición al backend
      final response = await http.post(
        Uri.parse('$_baseUrl/my-maps/create'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('📥 Respuesta del servidor: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ MyMap creado exitosamente');

        return {
          'success': true,
          'mapId': data['mapId'],
          'mapName': data['mapName'],
          'placesCount': data['placesCount'],
          'sharedLink': data['sharedLink'],
          'editLink': data['editLink'],
          'searchLink': data['searchLink'],
          'coordinatesLink': data['coordinatesLink'],
          'message': data['message'],
          'instructions': data['instructions'],
          'added': data['added'],
          'totalPlaces': data['totalPlaces'],
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ Error del backend: ${errorData['error']}');

        return {
          'success': false,
          'error': errorData['error'] ?? 'Error desconocido del servidor',
          'details': errorData['details'],
        };
      }
    } catch (error) {
      print('❌ Error en createMyMap: $error');
      return {
        'success': false,
        'error': 'Error de conexión. Verifica tu conexión a internet.',
        'details': error.toString(),
      };
    }
  }

  /// Obtiene información de un MyMap existente
  static Future<Map<String, dynamic>> getMyMapInfo(String mapId) async {
    try {
      print('🔍 Obteniendo información del MyMap: $mapId');

      final response = await http.get(
        Uri.parse('$_baseUrl/my-maps/$mapId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('📥 Respuesta del servidor: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Información del MyMap obtenida');

        return {
          'success': true,
          'mapInfo': data['mapInfo'],
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ Error del backend: ${errorData['error']}');

        return {
          'success': false,
          'error': errorData['error'] ?? 'Error desconocido del servidor',
          'details': errorData['details'],
        };
      }
    } catch (error) {
      print('❌ Error en getMyMapInfo: $error');
      return {
        'success': false,
        'error': 'Error de conexión. Verifica tu conexión a internet.',
        'details': error.toString(),
      };
    }
  }
}
