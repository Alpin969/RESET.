class Validators {
  static final RegExp usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');
  static final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp timezonePattern = RegExp(
    r'^(?:[A-Za-z][A-Za-z0-9_+-]*(?:/[A-Za-z][A-Za-z0-9_+-]*)+|UTC|GMT)$',
  );

  static const int minPasswordLength = 6;
  static const int maxMotivationLength = 160;
  static const int maxAvatarBytes = 5 * 1024 * 1024;
  static const List<String> ageGroups = ['13-17', '18+'];

  static String normalizeUsername(String value) {
    return value.trim().toLowerCase();
  }

  static bool isValidUsername(String value) {
    return usernamePattern.hasMatch(value);
  }

  static bool isValidEmail(String value) {
    return emailPattern.hasMatch(value.trim());
  }

  static bool isValidPassword(String value) {
    return value.length >= minPasswordLength;
  }

  static String cleanMotivation(String value) {
    return value.trim();
  }

  static bool isValidMotivation(String value) {
    return cleanMotivation(value).length <= maxMotivationLength;
  }

  static bool isValidAgeGroup(String value) {
    return ageGroups.contains(value);
  }

  static bool isValidTimezone(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned.length > 64) return false;
    if (cleaned.contains('..')) return false;
    return timezonePattern.hasMatch(cleaned);
  }

  static String? detectImageFormat(List<int> bytes) {
    if (bytes.length < 12) return null;

    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpeg';
    }

    final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    var isPng = true;
    for (var i = 0; i < png.length; i++) {
      if (bytes[i] != png[i]) {
        isPng = false;
        break;
      }
    }
    if (isPng) return 'png';

    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }

    return null;
  }

  static String contentTypeFor(String format) {
    if (format == 'jpeg') return 'image/jpeg';
    if (format == 'png') return 'image/png';
    return 'image/webp';
  }

  static String extensionFor(String format) {
    if (format == 'jpeg') return 'jpg';
    if (format == 'png') return 'png';
    return 'webp';
  }

  static String? validateAvatarBytes(List<int> bytes) {
    if (bytes.isEmpty) return 'File foto kosong.';
    if (bytes.length > maxAvatarBytes) return 'Ukuran foto maksimal 5 MB.';
    if (detectImageFormat(bytes) == null) {
      return 'Format foto harus JPEG, PNG, atau WebP.';
    }
    return null;
  }

  static String? validateUsernameForUpdate(String value) {
    final normalized = normalizeUsername(value);
    if (!isValidUsername(normalized)) {
      return 'Username 3-20 karakter, hanya huruf kecil, angka, dan underscore.';
    }
    return null;
  }
}
