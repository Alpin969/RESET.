import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/user_profile.dart';

void main() {
  final createdAt = DateTime.parse('2026-10-17T08:00:00.000Z');
  final updatedAt = DateTime.parse('2026-10-18T09:30:00.000Z');

  Map<String, dynamic> sampleMap() {
    return {
      'id': 'uid-1',
      'username': 'alvin',
      'avatar_url': 'alvin/avatar.png',
      'motivation': 'Tetap konsisten.',
      'age_group': '18+',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  group('UserProfile.fromMap', () {
    test('parses full row', () {
      final profile = UserProfile.fromMap(sampleMap());

      expect(profile.id, 'uid-1');
      expect(profile.username, 'alvin');
      expect(profile.avatarUrl, 'alvin/avatar.png');
      expect(profile.motivation, 'Tetap konsisten.');
      expect(profile.ageGroup, '18+');
      expect(profile.timezone, 'Asia/Jakarta');
      expect(profile.createdAt, createdAt);
      expect(profile.updatedAt, updatedAt);
      expect(profile.email, isNull);
    });

    test('parses row with optional values missing', () {
      final profile = UserProfile.fromMap({
        'id': 'uid-2',
        'username': 'budi',
      });

      expect(profile.avatarUrl, isNull);
      expect(profile.motivation, isNull);
      expect(profile.ageGroup, isNull);
      expect(profile.timezone, 'Asia/Jakarta');
      expect(profile.createdAt, isNull);
      expect(profile.updatedAt, isNull);
    });

    test('parses invalid date strings as null', () {
      final profile = UserProfile.fromMap({
        'id': 'uid-3',
        'username': 'citra',
        'created_at': 'not-a-date',
      });

      expect(profile.createdAt, isNull);
    });
  });

  group('UserProfile.toMap', () {
    test('serializes profile fields', () {
      final profile = UserProfile.fromMap(sampleMap());
      final map = profile.toMap();

      expect(map['id'], 'uid-1');
      expect(map['username'], 'alvin');
      expect(map['avatar_url'], 'alvin/avatar.png');
      expect(map['motivation'], 'Tetap konsisten.');
      expect(map['age_group'], '18+');
      expect(map.containsKey('email'), isFalse);
    });

    test('round trips through fromMap', () {
      final profile = UserProfile.fromMap(sampleMap());
      final restored = UserProfile.fromMap(profile.toMap());

      expect(restored.id, profile.id);
      expect(restored.username, profile.username);
      expect(restored.avatarUrl, profile.avatarUrl);
      expect(restored.motivation, profile.motivation);
      expect(restored.ageGroup, profile.ageGroup);
    });
  });

  group('UserProfile.copyWith', () {
    test('updates only provided fields', () {
      final profile = UserProfile.fromMap(sampleMap());
      final updated = profile.copyWith(username: 'alvin2');

      expect(updated.username, 'alvin2');
      expect(updated.motivation, profile.motivation);
      expect(updated.ageGroup, profile.ageGroup);
      expect(updated.avatarUrl, profile.avatarUrl);
      expect(updated.id, profile.id);
      expect(updated.createdAt, profile.createdAt);
    });

    test('updates motivation and age group', () {
      final profile = UserProfile.fromMap(sampleMap());
      final updated = profile.copyWith(motivation: 'Baru', ageGroup: '13-17');

      expect(updated.motivation, 'Baru');
      expect(updated.ageGroup, '13-17');
    });
  });
}
