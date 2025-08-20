import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:tourify_flutter/services/auth_service.dart';
import 'package:tourify_flutter/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // Usar ApiConfig en lugar de configuración local
  static String get baseUrl => ApiConfig.baseUrl;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Obtener headers para las peticiones
  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Si el usuario está autenticado, añadir token
    print('Debug AuthService.isAuthenticated: ${AuthService.isAuthenticated}');
    print('Debug AuthService.currentUser: ${AuthService.currentUser}');

    if (AuthService.isAuthenticated) {
      final token = await AuthService.currentUser?.getIdToken();
      print(
          'Debug token obtenido: ${token != null ? "Token presente (${token.length} chars)" : "Token es null"}');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        print('Debug headers con token: $headers');
      }
    } else {
      print('Debug: Usuario no está autenticado');
      // Añadir modo invitado con bypass seguro
      headers['x-guest-mode'] = 'true';
      final fingerprint = await _getOrCreateDeviceFingerprint();
      if (fingerprint != null && fingerprint.isNotEmpty) {
        headers['x-device-fingerprint'] = fingerprint;
      }
      final guestAppKey = dotenv.env['GUEST_APP_KEY'];
      if (guestAppKey != null && guestAppKey.isNotEmpty) {
        headers['x-app-key'] = guestAppKey;
      }
    }

    return headers;
  }

  // Obtener guías recientes desde el backend (evita reglas de Firestore en cliente)
  Future<List<Map<String, dynamic>>> fetchRecentGuides() async {
    try {
      final headers = await _getHeaders();
      final resp =
          await http.get(Uri.parse('$baseUrl/guides/recent'), headers: headers);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final List list = (data['guides'] ?? []) as List;
        return list
            .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
            .cast<Map<String, dynamic>>()
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Genera o recupera un fingerprint persistente para el dispositivo
  Future<String?> _getOrCreateDeviceFingerprint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('device_fingerprint');
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }
      // Generar string pseudo-aleatorio estable
      final rnd = Random.secure();
      final randomBytes = List<int>.generate(16, (_) => rnd.nextInt(256));
      final now = DateTime.now().millisecondsSinceEpoch;
      final seed =
          '${now}:${rnd.nextInt(1 << 32)}:${base64UrlEncode(randomBytes)}';
      final fp = base64UrlEncode(utf8.encode(seed)).replaceAll('=', '');
      await prefs.setString('device_fingerprint', fp);
      return fp;
    } catch (e) {
      print('Error generando fingerprint local: $e');
      return null;
    }
  }

  // Obtener actividades para descubrir con streaming
  Stream<List<dynamic>> fetchActivitiesStream({
    required String location,
    DateTime? startDate,
    DateTime? endDate,
    String lang = 'es',
    int? limit,
    List<String>? existingTitles,
    List<String>? discardedTitles,
    int? travelers,
    List<String>? travelModes,
    String? travelIntensity,
  }) async* {
    final activities = <dynamic>[];

    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'lang': lang,
      };

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }

      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }

      if (existingTitles != null && existingTitles.isNotEmpty) {
        queryParams['existingTitles'] = json.encode(existingTitles);
      }

      if (discardedTitles != null && discardedTitles.isNotEmpty) {
        queryParams['discardedTitles'] = json.encode(discardedTitles);
      }

      if (travelers != null) {
        queryParams['travelers'] = travelers.toString();
      }

      if (travelModes != null && travelModes.isNotEmpty) {
        queryParams['travelModes'] = json.encode(travelModes);
      }

      if (travelIntensity != null && travelIntensity.isNotEmpty) {
        queryParams['travelIntensity'] = travelIntensity;
      }

      // Usar endpoint autenticado si el usuario está logueado, anónimo si no
      final endpoint = AuthService.isAuthenticated
          ? '/discover/auth/${Uri.encodeComponent(location)}/$lang'
          : '/discover/${Uri.encodeComponent(location)}/$lang';

      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParams,
      );

      print('API Streaming Request:');
      print('  URL: $uri');
      print('  Headers: $headers');
      print('  Location: $location');
      print('  Limit: $limit');

      final request = http.Request('GET', uri);
      request.headers.addAll(headers);

      final client = http.Client();
      final response = await client.send(request);

      print('API Streaming Response:');
      print('  Status Code: ${response.statusCode}');
      print('  Content-Type: ${response.headers['content-type']}');

      if (response.statusCode == 200) {
        String buffer = '';

        await for (final chunk in response.stream.transform(utf8.decoder)) {
          buffer += chunk;

          // Procesar líneas completas
          final lines = buffer.split('\n');
          buffer = lines
              .removeLast(); // Guardar línea incompleta para siguiente chunk

          for (final line in lines) {
            final trimmedLine = line.trim();

            if (trimmedLine.isEmpty) continue;

            dynamic newActivity;

            if (trimmedLine.startsWith('data: ')) {
              final data = trimmedLine.substring(6).trim();

              if (data == '[DONE]') {
                print('Streaming completed with [DONE] marker');
                yield List<dynamic>.from(activities);
                client.close();
                return;
              }

              try {
                final messageData = json.decode(data);

                if (messageData is Map<String, dynamic> &&
                    messageData['type'] == 'activity') {
                  final activity = messageData['content'];
                  if (activity is Map<String, dynamic> &&
                      activity['title'] != null &&
                      activity['description'] != null) {
                    newActivity = activity;
                  }
                }
              } catch (e) {
                print(
                    '⚠️  Failed to parse streaming line: "$trimmedLine" - Error: $e');
                continue;
              }
            } else {
              // Intentar parsear líneas directas sin "data: " prefix
              try {
                final activityData = json.decode(trimmedLine);
                if (activityData is Map<String, dynamic> &&
                    activityData['title'] != null) {
                  newActivity = activityData;
                }
              } catch (e) {
                // Ignorar líneas que no se puedan parsear
                continue;
              }
            }

            // Si encontramos una nueva actividad, agregarla y emitir
            if (newActivity != null) {
              activities.add(newActivity);
              print(
                  'Activity streamed: ${newActivity['title']} (Total: ${activities.length})');
              yield List<dynamic>.from(activities);
            }
          }
        }

        // Procesar buffer restante
        if (buffer.trim().isNotEmpty) {
          // ... procesar última línea si es necesario
        }

        client.close();
        yield List<dynamic>.from(activities);
      } else if (response.statusCode == 429) {
        client.close();
        throw Exception('Límite diario alcanzado. Intenta de nuevo mañana.');
      } else {
        client.close();
        final bodyBytes = await response.stream.toBytes();
        final body = utf8.decode(bodyBytes);
        print('Error response body: $body');
        throw Exception('Error del servidor: ${response.statusCode} - $body');
      }
    } catch (e) {
      print('Error en fetchActivitiesStream: $e');
      throw Exception('Error al cargar actividades: $e');
    }
  }

  // Mantener método legacy para compatibilidad
  Future<List<dynamic>> fetchActivities({
    required String location,
    DateTime? startDate,
    DateTime? endDate,
    String lang = 'es',
    int? limit,
    List<String>? existingTitles,
    List<String>? discardedTitles,
    int? travelers,
    List<String>? travelModes,
    String? travelIntensity,
  }) async {
    // Usar el método de streaming pero esperar a todas las actividades
    List<dynamic> allActivities = [];

    await for (final activities in fetchActivitiesStream(
      location: location,
      startDate: startDate,
      endDate: endDate,
      lang: lang,
      limit: limit,
      existingTitles: existingTitles,
      discardedTitles: discardedTitles,
      travelers: travelers,
      travelModes: travelModes,
      travelIntensity: travelIntensity,
    )) {
      allActivities = activities;
    }

    return allActivities;
  }

  // Enviar valoraciones de actividades
  Future<bool> submitRatings(List<Map<String, dynamic>> ratings) async {
    try {
      final headers = await _getHeaders();

      final body = {
        'ratings': ratings,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/discover/likes/batch'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error al enviar valoraciones: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error en submitRatings: $e');
      return false;
    }
  }

  // Crear guía
  Future<String?> createGuide({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required List<dynamic> activities,
    required List<dynamic> rejectedActivities,
    required int travelers,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = {
        'destination': destination,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'activities': activities,
        'rejectedActivities': rejectedActivities,
        'travelers': travelers,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/guides/create'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['guideId'];
      } else {
        print('Error al crear guía: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error en createGuide: $e');
      return null;
    }
  }

  // Crear actividad usando Google Places
  Future<Map<String, dynamic>?> createActivityFromPlace({
    required String activityName,
    required String cityName,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = {
        'activityName': activityName,
        'cityName': cityName,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/activity/create'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else {
        print(
            'Error al crear actividad: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error en createActivityFromPlace: $e');
      return null;
    }
  }

  // Eliminar guía usando el endpoint del servidor
  Future<Map<String, dynamic>> deleteGuide(String guideId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/guides/$guideId'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Guía eliminada correctamente',
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Error al eliminar la guía',
        };
      }
    } catch (e) {
      print('Error en deleteGuide: $e');
      return {
        'success': false,
        'error': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Validar login en el backend (evita problemas de reglas en cliente)
  Future<Map<String, dynamic>> validateLogin({String? expectedProvider}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (expectedProvider != null && expectedProvider.isNotEmpty) {
        body['expectedProvider'] = expectedProvider;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/validate-login'),
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        return data;
      }

      // Devolver estructura uniforme de error
      return {
        'success': false,
        'error': data['error'] ?? 'unknown_error',
        'message': data['message'] ?? 'Error validando login',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'network_error',
        'message': e.toString(),
      };
    }
  }
}
