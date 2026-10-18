import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/utils/validators.dart';

void main() {
  group('Validators.normalizeUsername', () {
    test('trims and lowercases', () {
      expect(Validators.normalizeUsername('  Alvin_Doe  '), 'alvin_doe');
    });
  });

  group('username validation', () {
    test('accepts valid usernames', () {
      final twenty = List.filled(20, 'a').join();
      expect(Validators.isValidUsername('alvin'), isTrue);
      expect(Validators.isValidUsername('a_b9'), isTrue);
      expect(Validators.isValidUsername(twenty), isTrue);
    });

    test('rejects invalid usernames', () {
      final twentyOne = List.filled(21, 'a').join();
      expect(Validators.isValidUsername('ab'), isFalse);
      expect(Validators.isValidUsername('Alvin'), isFalse);
      expect(Validators.isValidUsername('al vin'), isFalse);
      expect(Validators.isValidUsername('alvin!'), isFalse);
      expect(Validators.isValidUsername(twentyOne), isFalse);
    });
  });

  group('email validation', () {
    test('accepts valid emails', () {
      expect(Validators.isValidEmail('user@example.com'), isTrue);
      expect(Validators.isValidEmail(' user@example.co.id '), isTrue);
    });

    test('rejects invalid emails', () {
      expect(Validators.isValidEmail(''), isFalse);
      expect(Validators.isValidEmail('user@'), isFalse);
      expect(Validators.isValidEmail('user example.com'), isFalse);
      expect(Validators.isValidEmail('@example.com'), isFalse);
    });
  });

  group('password validation', () {
    test('requires at least 6 characters', () {
      expect(Validators.isValidPassword('12345'), isFalse);
      expect(Validators.isValidPassword('123456'), isTrue);
    });
  });

  group('motivation validation', () {
    test('trims motivation text', () {
      expect(Validators.cleanMotivation('  Tetap konsisten  '),
          'Tetap konsisten');
    });

    test('accepts up to 160 characters', () {
      final maxed = List.filled(160, 'x').join();
      final over = List.filled(161, 'x').join();
      expect(Validators.isValidMotivation(maxed), isTrue);
      expect(Validators.isValidMotivation(over), isFalse);
      expect(Validators.isValidMotivation(''), isTrue);
    });
  });

  group('age group validation', () {
    test('accepts only allowed groups', () {
      expect(Validators.isValidAgeGroup('13-17'), isTrue);
      expect(Validators.isValidAgeGroup('18+'), isTrue);
      expect(Validators.isValidAgeGroup('12-16'), isFalse);
      expect(Validators.isValidAgeGroup('adult'), isFalse);
      expect(Validators.isValidAgeGroup(''), isFalse);
    });
  });

  group('image format detection', () {
    test('detects jpeg', () {
      final bytes = <int>[0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(20, 0)];
      expect(Validators.detectImageFormat(bytes), 'jpeg');
    });

    test('detects png', () {
      final bytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(20, 0)];
      expect(Validators.detectImageFormat(bytes), 'png');
    });

    test('detects webp', () {
      final bytes = <int>[0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50, ...List.filled(20, 0)];
      expect(Validators.detectImageFormat(bytes), 'webp');
    });

    test('rejects unknown and short data', () {
      expect(Validators.detectImageFormat([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B]), isNull);
      expect(Validators.detectImageFormat([0xFF, 0xD8, 0xFF]), isNull);
      expect(Validators.detectImageFormat([]), isNull);
    });
  });

  group('avatar bytes validation', () {
    test('accepts a small valid png', () {
      final bytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(32, 1)];
      expect(Validators.validateAvatarBytes(bytes), isNull);
    });

    test('rejects empty file', () {
      expect(Validators.validateAvatarBytes([]), isNotNull);
    });

    test('rejects files above 5 MB', () {
      final bytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(Validators.maxAvatarBytes, 1)];
      expect(Validators.validateAvatarBytes(bytes), isNotNull);
    });

    test('rejects non image data', () {
      final bytes = List<int>.filled(64, 7);
      expect(Validators.validateAvatarBytes(bytes), isNotNull);
    });
  });

  group('timezone validation', () {
    test('accepts IANA timezone names', () {
      expect(Validators.isValidTimezone('Asia/Jakarta'), isTrue);
      expect(Validators.isValidTimezone('America/Sao_Paulo'), isTrue);
      expect(Validators.isValidTimezone('Etc/GMT+5'), isTrue);
      expect(Validators.isValidTimezone('UTC'), isTrue);
      expect(Validators.isValidTimezone('GMT'), isTrue);
      expect(Validators.isValidTimezone(' Asia/Jakarta '), isTrue);
    });

    test('rejects invalid timezone names', () {
      expect(Validators.isValidTimezone(''), isFalse);
      expect(Validators.isValidTimezone('Jakarta'), isFalse);
      expect(Validators.isValidTimezone('Asia..Jakarta'), isFalse);
      expect(Validators.isValidTimezone('/Asia/Jakarta'), isFalse);
      expect(Validators.isValidTimezone('Asia/Jakarta;'), isFalse);
      expect(Validators.isValidTimezone(List.filled(65, 'a').join()), isFalse);
    });
  });

  group('content type mapping', () {
    test('maps formats to content types and extensions', () {
      expect(Validators.contentTypeFor('jpeg'), 'image/jpeg');
      expect(Validators.contentTypeFor('png'), 'image/png');
      expect(Validators.contentTypeFor('webp'), 'image/webp');
      expect(Validators.extensionFor('jpeg'), 'jpg');
      expect(Validators.extensionFor('png'), 'png');
      expect(Validators.extensionFor('webp'), 'webp');
    });
  });
}
