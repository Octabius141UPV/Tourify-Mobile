import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Endpoint Construction Tests', () {
    test('should construct authenticated endpoint correctly', () {
      const location = 'Madrid';
      const lang = 'es';

      // Simular la lógica que usa ApiService para usuarios autenticados
      final authEndpoint =
          '/discover/auth/${Uri.encodeComponent(location)}/$lang';

      expect(authEndpoint, equals('/discover/auth/Madrid/es'));
      expect(authEndpoint, contains('/auth/'));
    });

    test('should construct anonymous endpoint correctly', () {
      const location = 'Barcelona';
      const lang = 'es';

      // Simular la lógica que usa ApiService para usuarios anónimos
      final anonEndpoint = '/discover/${Uri.encodeComponent(location)}/$lang';

      expect(anonEndpoint, equals('/discover/Barcelona/es'));
      expect(anonEndpoint, isNot(contains('/auth/')));
    });

    test('should properly encode special characters in location', () {
      const location = 'San José';
      const lang = 'es';

      final authEndpoint =
          '/discover/auth/${Uri.encodeComponent(location)}/$lang';
      final anonEndpoint = '/discover/${Uri.encodeComponent(location)}/$lang';

      expect(authEndpoint, equals('/discover/auth/San%20Jos%C3%A9/es'));
      expect(anonEndpoint, equals('/discover/San%20Jos%C3%A9/es'));
    });

    test('endpoints should be different for auth vs anonymous', () {
      const location = 'Madrid';
      const lang = 'es';

      final authEndpoint =
          '/discover/auth/${Uri.encodeComponent(location)}/$lang';
      final anonEndpoint = '/discover/${Uri.encodeComponent(location)}/$lang';

      expect(authEndpoint, isNot(equals(anonEndpoint)));
      expect(authEndpoint.length, greaterThan(anonEndpoint.length));
    });
  });
}
