import 'dart:convert';
import 'package:tourify_flutter/config/api_config.dart';
import 'package:http/http.dart' as http;

/// Servicio para exportar guías a listas privadas de Google Maps
class GoogleMapsExportService {
  static String get _baseUrl => ApiConfig.baseUrl;

  /// Exporta una guía a Google Maps creando una lista compartida
  /// Retorna un Map con el resultado de la operación
  static Future<Map<String, dynamic>> exportToGoogleMaps({
    required String listName,
    required List<String> placeIds,
  }) async {
    try {
      print('🚀 Iniciando exportación a Google Maps...');
      print('📝 Nombre de la lista: $listName');
      print('📍 Número de lugares: ${placeIds.length}');

      // Validar datos de entrada
      if (listName.trim().isEmpty) {
        return {
          'success': false,
          'error': 'El nombre de la lista no puede estar vacío',
        };
      }

      if (placeIds.isEmpty) {
        return {
          'success': false,
          'error': 'No hay lugares para exportar',
        };
      }

      if (placeIds.length > 500) {
        return {
          'success': false,
          'error': 'El máximo de lugares por lista es 500',
        };
      }

      // Preparar datos para el backend
      final requestData = {
        'listName': listName.trim(),
        'places': placeIds,
      };

      print('📤 Enviando datos al backend...');
      print('🔗 URL del endpoint: $_baseUrl/google-maps/create-list');

      // Realizar petición al backend
      final response = await http.post(
        Uri.parse('$_baseUrl/google-maps/create-list'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('📥 Respuesta del servidor: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Lista creada exitosamente en Google Maps (backend)');

        return {
          'success': true,
          'listId': data['listId'],
          'listName': data['listName'],
          'placesCount': data['placesCount'],
          'sharedLink': data['sharedLink'],
          'message': data['message'],
          'added': data['added'],
          'method': 'backend',
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ Error del backend: ${errorData['error']}');

        return {
          'success': false,
          'error': errorData['error'] ?? 'Error desconocido del servidor',
          'details': errorData['details'],
          'method': 'backend',
        };
      }
    } catch (error) {
      print('❌ Error en exportToGoogleMaps: $error');
      return {
        'success': false,
        'error': 'Error de conexión. Verifica tu conexión a internet.',
        'details': error.toString(),
      };
    }
  }

  /// Exporta una guía a Google My Maps (MyMaps) creando un mapa compartido
  /// Retorna un Map con el resultado de la operación
  static Future<Map<String, dynamic>> exportToMyMaps({
    required String mapName,
    required List<Map<String, dynamic>> places,
  }) async {
    try {
      print('🚀 Iniciando exportación a Google My Maps...');
      print('📝 Nombre del mapa: $mapName');
      print('�� Número de lugares: ${places.length}');

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
          'error': 'No hay lugares para exportar',
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
        print('✅ Mapa creado exitosamente en Google My Maps (backend)');

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
          'added': data['added'],
          'method': 'backend',
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ Error del backend: ${errorData['error']}');

        return {
          'success': false,
          'error': errorData['error'] ?? 'Error desconocido del servidor',
          'details': errorData['details'],
          'method': 'backend',
        };
      }
    } catch (error) {
      print('❌ Error en exportToMyMaps: $error');
      return {
        'success': false,
        'error': 'Error de conexión. Verifica tu conexión a internet.',
        'details': error.toString(),
      };
    }
  }
}
