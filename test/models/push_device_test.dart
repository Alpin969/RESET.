import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/push_device.dart';

void main() {
  group('PushDevice.fromMap', () {
    test('parses full subscription row', () {
      final device = PushDevice.fromMap({
        'id': 'sub-1',
        'endpoint': 'https://fcm.googleapis.com/fcm/send/abc',
        'device_name': 'Web',
        'user_agent': 'Mozilla/5.0',
        'last_success_at': '2026-10-17T08:00:00.000Z',
        'created_at': '2026-10-16T08:00:00.000Z',
      });

      expect(device.id, 'sub-1');
      expect(device.endpoint, 'https://fcm.googleapis.com/fcm/send/abc');
      expect(device.deviceName, 'Web');
      expect(device.userAgent, 'Mozilla/5.0');
      expect(device.lastSuccessAt, isNotNull);
      expect(device.createdAt, isNotNull);
    });

    test('parses subscription with optional values missing', () {
      final device = PushDevice.fromMap({
        'id': 'sub-2',
        'endpoint': 'https://push.example.com/p/xyz',
      });

      expect(device.deviceName, isNull);
      expect(device.userAgent, isNull);
      expect(device.lastSuccessAt, isNull);
      expect(device.createdAt, isNull);
    });

    test('toMap keeps endpoint and device name', () {
      final device = PushDevice.fromMap({
        'id': 'sub-3',
        'endpoint': 'https://push.example.com/p/123',
        'device_name': 'Chrome Desktop',
      });

      final map = device.toMap();

      expect(map['id'], 'sub-3');
      expect(map['endpoint'], 'https://push.example.com/p/123');
      expect(map['device_name'], 'Chrome Desktop');
    });
  });
}
