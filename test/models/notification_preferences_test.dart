import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/notification_preferences.dart';

void main() {
  group('NotificationPreferences.fromMap', () {
    test('parses full preferences row', () {
      final prefs = NotificationPreferences.fromMap({
        'notifications_enabled': false,
        'reminder_default_time': '21:30:00',
        'timezone': 'Asia/Jakarta',
      });

      expect(prefs.notificationsEnabled, isFalse);
      expect(prefs.reminderDefaultTime, '21:30');
      expect(prefs.timezone, 'Asia/Jakarta');
    });

    test('applies defaults when values missing', () {
      final prefs = NotificationPreferences.fromMap({});

      expect(prefs.notificationsEnabled, isTrue);
      expect(prefs.reminderDefaultTime, '08:00');
      expect(prefs.timezone, isNull);
    });

    test('falls back to default time on invalid value', () {
      final prefs = NotificationPreferences.fromMap({
        'notifications_enabled': true,
        'reminder_default_time': 'bukan-waktu',
      });

      expect(prefs.reminderDefaultTime, '08:00');
    });

    test('copyWith updates only provided fields', () {
      const prefs = NotificationPreferences(
        notificationsEnabled: true,
        reminderDefaultTime: '08:00',
        timezone: 'Asia/Jakarta',
      );

      final updated = prefs.copyWith(
        notificationsEnabled: false,
        reminderDefaultTime: '07:15',
      );

      expect(updated.notificationsEnabled, isFalse);
      expect(updated.reminderDefaultTime, '07:15');
      expect(updated.timezone, 'Asia/Jakarta');
    });
  });
}
