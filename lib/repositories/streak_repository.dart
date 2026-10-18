import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/streak_info.dart';
import '../utils/streak_calculator.dart';
import '../utils/task_progress.dart';

class StreakRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException('Sesi tidak ditemukan. Silakan login ulang.');
    }
    return uid;
  }

  Future<DateTime> getLocalToday() async {
    _requireUid();
    final data = await _client.rpc('get_local_today');
    return TaskProgress.normalize(DateTime.parse(data.toString()));
  }

  Future<List<DateTime>> getActiveDates({int limit = 2000}) async {
    _requireUid();

    final safeLimit = limit.clamp(1, StreakCalculator.maxActiveDateLimit);
    final data = await _client.rpc(
      'get_active_dates',
      params: {'p_limit': safeLimit},
    );

    return (data as List)
        .map((value) => DateTime.parse(value.toString()))
        .toList();
  }

  Future<StreakInfo> getStreakInfo() async {
    final today = await getLocalToday();
    final activeDates = await getActiveDates();
    return StreakCalculator.compute(activeDates: activeDates, today: today);
  }

  Future<int> getCurrentStreak() async {
    final info = await getStreakInfo();
    return info.currentStreak;
  }
}
