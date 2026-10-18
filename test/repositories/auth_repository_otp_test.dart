import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final repository = AuthRepository();

  group('AuthRepository.verifySignupOtp validation', () {
    test('throws when email is empty', () {
      expect(
        () => repository.verifySignupOtp(email: '', otp: '123456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('throws when email format is invalid', () {
      expect(
        () => repository.verifySignupOtp(email: 'not-an-email', otp: '123456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('throws when otp is empty', () {
      expect(
        () => repository.verifySignupOtp(email: 'user@example.com', otp: ''),
        throwsA(isA<AuthException>()),
      );
    });

    test('throws when otp is not 6 digits', () {
      expect(
        () => repository.verifySignupOtp(
          email: 'user@example.com',
          otp: '12345',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('throws when otp contains letters', () {
      expect(
        () => repository.verifySignupOtp(
          email: 'user@example.com',
          otp: '12a456',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('AuthRepository.resendSignupOtp validation', () {
    test('throws when email is empty', () {
      expect(
        () => repository.resendSignupOtp(email: '   '),
        throwsA(isA<AuthException>()),
      );
    });

    test('throws when email format is invalid', () {
      expect(
        () => repository.resendSignupOtp(email: 'invalid-email'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
