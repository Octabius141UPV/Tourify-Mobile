import 'package:flutter_test/flutter_test.dart';
import 'package:tourify_flutter/utils/email_validator.dart';

void main() {
  group('EmailValidator Tests', () {
    test('should reject empty email', () {
      final result = EmailValidator.validateEmail('');
      expect(result.isValid, false);
      expect(result.error, 'Por favor, introduce un email');
    });

    test('should reject invalid email format', () {
      final result = EmailValidator.validateEmail('invalid-email');
      expect(result.isValid, false);
      expect(result.error, 'Por favor, introduce un email válido');
    });

    test('should accept valid email', () {
      final result = EmailValidator.validateEmail('usuario@gmail.com');
      expect(result.isValid, true);
      expect(result.error, null);
    });

    test('should reject yopmail email', () {
      final result = EmailValidator.validateEmail('test@yopmail.com');
      expect(result.isValid, false);
      expect(result.error,
          'No se permiten emails temporales o desechables.\nPor favor, usa un email permanente.');
      expect(result.isTemporary, true);
    });

    test('should reject 10minutemail email', () {
      final result = EmailValidator.validateEmail('user@10minutemail.com');
      expect(result.isValid, false);
      expect(result.isTemporary, true);
    });

    test('should reject guerrillamail email', () {
      final result = EmailValidator.validateEmail('user@guerrillamail.com');
      expect(result.isValid, false);
      expect(result.isTemporary, true);
    });

    test('should accept legitimate email domains', () {
      final validEmails = [
        'user@gmail.com',
        'test@outlook.com',
        'admin@company.es',
        'contact@university.edu',
        'support@business.org',
      ];

      for (final email in validEmails) {
        final result = EmailValidator.validateEmail(email);
        expect(result.isValid, true, reason: 'Email $email should be valid');
        expect(result.error, null);
        expect(result.isTemporary, false);
      }
    });

    test('isTemporaryEmail function should work correctly', () {
      expect(EmailValidator.isTemporaryEmail('test@yopmail.com'), true);
      expect(EmailValidator.isTemporaryEmail('user@gmail.com'), false);
      expect(EmailValidator.isTemporaryEmail('invalid-email'), false);
      expect(EmailValidator.isTemporaryEmail(''), false);
    });
  });
}
