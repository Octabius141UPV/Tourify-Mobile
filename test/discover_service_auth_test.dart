import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:tourify_flutter/services/discover_service.dart';
import 'package:tourify_flutter/services/auth_service.dart';
import 'package:tourify_flutter/services/api_service.dart';

// Generar mocks
@GenerateMocks([AuthService, ApiService])
import 'discover_service_auth_test.mocks.dart';

void main() {
  group('DiscoverService Authentication Tests', () {
    setUpAll(() {
      // Configuración inicial si es necesaria
    });

    test('fetchActivitiesStream requires authentication', () async {
      // Test para verificar que fetchActivitiesStream requiere autenticación
      expect(
        () => DiscoverService.fetchActivitiesStream(
          destination: 'Madrid',
        ).first,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Se requiere autenticación'),
        )),
      );
    });

    test('fetchActivities requires authentication', () async {
      // Test para verificar que fetchActivities requiere autenticación
      await expectLater(
        DiscoverService.fetchActivities(destination: 'Madrid'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Se requiere autenticación'),
        )),
      );
    });

    test('createGuide requires authentication', () async {
      // Test para verificar que createGuide requiere autenticación
      final result = await DiscoverService.createGuide(
        destination: 'Madrid',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: 3)),
        travelers: 2,
      );

      // Debería retornar null porque no hay autenticación
      expect(result, isNull);
    });

    test('createGuideViaApi requires authentication', () async {
      // Test para verificar que createGuideViaApi requiere autenticación
      await expectLater(
        DiscoverService.createGuideViaApi(
          destination: 'Madrid',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: 3)),
          travelers: 2,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Se requiere autenticación'),
        )),
      );
    });

    test('_sendRating handles unauthenticated users gracefully', () {
      // Test para verificar que _sendRating maneja usuarios no autenticados
      // Este test es implícito ya que el método es privado, pero podemos verificar
      // que acceptActivity y rejectActivity no causan errores
      expect(() {
        // Simular actividad mock
        final mockActivity = MockActivity();
        DiscoverService.acceptActivity(mockActivity);
        DiscoverService.rejectActivity(mockActivity);
      }, returnsNormally);
    });
  });
}

// Mock class para Activity
class MockActivity {
  final String id = 'test-id';
  final String name = 'Test Activity';
  final String description = 'Test Description';
  final String imageUrl = 'test-url';
  final String category = 'test-category';
}
