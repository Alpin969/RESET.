import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_preferences.dart';
import '../models/push_device.dart';
import '../utils/reminder_schedule.dart';

class NotificationRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException('Sesi tidak ditemukan. Silakan login ulang.');
    }
    return uid;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return Map<String, dynamic>.from(value as Map);
  }

  Future<List<PushDevice>> getMyPushSubscriptions() async {
    _requireUid();
    final data = await _client.rpc('push_list_my');
    return (data as List)
        .map((row) => PushDevice.fromMap(_asMap(row)))
        .toList();
  }

  Future<void> registerPushSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
    String? deviceName,
    String? userAgent,
  }) async {
    _requireUid();

    if (!endpoint.startsWith('https://')) {
      throw AuthException('Endpoint subscription tidak valid.');
    }
    if (p256dh.trim().length < 20 || auth.trim().length < 20) {
      throw AuthException('Kunci subscription tidak valid.');
    }

    await _client.rpc('push_register', params: {
      'p_endpoint': endpoint,
      'p_p256dh': p256dh,
      'p_auth': auth,
      'p_device_name': deviceName,
      'p_user_agent': userAgent,
    });
  }

  Future<void> unregisterPushSubscription(String endpoint) async {
    _requireUid();
    if (endpoint.trim().isEmpty) {
      throw AuthException('Endpoint subscription tidak valid.');
    }
    await _client.rpc('push_unregister', params: {'p_endpoint': endpoint});
  }

  Future<void> unregisterAllPushSubscriptions() async {
    _requireUid();
    await _client.rpc('push_unregister_all');
  }

  Future<String> getPushPublicKey() async {
    _requireUid();
    final data = await _client.rpc('push_public_key_get');
    return data?.toString() ?? '';
  }

  Future<NotificationPreferences> getNotificationPreferences() async {
    _requireUid();
    final data = await _client.rpc('notification_prefs_get');
    final map = _asMap(data);
    if (map.isEmpty) {
      return const NotificationPreferences(
        notificationsEnabled: true,
        reminderDefaultTime: '08:00',
      );
    }
    return NotificationPreferences.fromMap(map);
  }

  Future<void> updateNotificationPreferences({
    bool? notificationsEnabled,
    String? reminderDefaultTime,
  }) async {
    _requireUid();

    String? normalizedTime;
    if (reminderDefaultTime != null) {
      normalizedTime = ReminderSchedule.normalizeTimeFlexible(
        reminderDefaultTime,
      );
      if (normalizedTime == null) {
        throw AuthException('Waktu default tidak valid.');
      }
    }

    if (notificationsEnabled == null && normalizedTime == null) {
      throw AuthException('Tidak ada perubahan preferensi.');
    }

    await _client.rpc('notification_prefs_update', params: {
      'p_enabled': notificationsEnabled,
      'p_default_time': normalizedTime == null ? null : '$normalizedTime:00',
    });
  }
}
