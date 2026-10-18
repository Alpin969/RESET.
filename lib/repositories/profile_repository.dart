import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../utils/validators.dart';

class ProfileRepository {
  ProfileRepository({StorageService? storageService})
      : _storage = storageService ?? StorageService();

  final StorageService _storage;

  static const String avatarsBucket = 'avatars';

  SupabaseClient get _client => Supabase.instance.client;
  GoTrueClient get _auth => _client.auth;

  String _requireUid() {
    final uid = _auth.currentUser?.id;
    if (uid == null) {
      throw AuthException('Sesi tidak ditemukan. Silakan login ulang.');
    }
    return uid;
  }

  UserProfile _attachEmail(UserProfile profile) {
    return profile.copyWith(email: _auth.currentUser?.email);
  }

  Future<bool> isUsernameAvailable(String username, {String? excludeId}) async {
    final params = <String, dynamic>{'p_username': username};
    if (excludeId != null) params['p_exclude_id'] = excludeId;

    final available = await _client.rpc(
      'is_username_available',
      params: params,
    );
    return available == true;
  }

  Future<UserProfile> getMyProfile() async {
    final uid = _requireUid();

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (data == null) {
      throw AuthException('Profile tidak ditemukan.');
    }

    return _attachEmail(UserProfile.fromMap(data));
  }

  Future<UserProfile> updateUsername(String username) async {
    final uid = _requireUid();
    final normalized = Validators.normalizeUsername(username);

    final error = Validators.validateUsernameForUpdate(normalized);
    if (error != null) throw AuthException(error);

    final available = await isUsernameAvailable(normalized, excludeId: uid);
    if (!available) throw AuthException('Username sudah digunakan.');

    return _updateMyRow({'username': normalized});
  }

  Future<UserProfile> updateMotivation(String motivation) async {
    final cleaned = Validators.cleanMotivation(motivation);

    if (!Validators.isValidMotivation(cleaned)) {
      throw AuthException(
        'Kata motivasi maksimal ${Validators.maxMotivationLength} karakter.',
      );
    }

    return _updateMyRow({'motivation': cleaned});
  }

  Future<UserProfile> updateAgeGroup(String ageGroup) async {
    if (!Validators.isValidAgeGroup(ageGroup)) {
      throw AuthException("Kelompok usia hanya '13-17' atau '18+'.");
    }

    return _updateMyRow({'age_group': ageGroup});
  }

  Future<UserProfile> updateTimezone(String timezoneName) async {
    final cleaned = timezoneName.trim();

    if (!Validators.isValidTimezone(cleaned)) {
      throw AuthException(
        'Timezone IANA tidak valid. Contoh: Asia/Jakarta.',
      );
    }

    return _updateMyRow({'timezone': cleaned});
  }

  Future<UserProfile> uploadAvatar(List<int> bytes) async {
    final uid = _requireUid();

    final error = Validators.validateAvatarBytes(bytes);
    if (error != null) throw AuthException(error);

    final format = Validators.detectImageFormat(bytes)!;
    final extension = Validators.extensionFor(format);
    final path = '$uid/${_safeToken()}.$extension';

    final current = await getMyProfile();

    try {
      await _storage.uploadBytes(
        bucket: avatarsBucket,
        path: path,
        bytes: Uint8List.fromList(bytes),
        contentType: Validators.contentTypeFor(format),
      );
    } on StorageException catch (e) {
      throw AuthException('Gagal mengunggah foto: ${e.message}');
    }

    try {
      final updated = await _updateMyRow({'avatar_url': path});
      final oldPath = current.avatarUrl;
      if (oldPath != null && oldPath.isNotEmpty && oldPath != path) {
        await _removeOwnedAvatar(uid, oldPath);
      }
      return updated;
    } catch (_) {
      await _removeOwnedAvatar(uid, path);
      rethrow;
    }
  }

  Future<UserProfile> deleteAvatar() async {
    final uid = _requireUid();
    final current = await getMyProfile();
    final path = current.avatarUrl;

    if (path == null || path.trim().isEmpty) return current;

    final updated = await _updateMyRow({'avatar_url': null});
    await _removeOwnedAvatar(uid, path);
    return updated;
  }

  String? getAvatarUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final value = path.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return _storage.publicUrl(bucket: avatarsBucket, path: value);
  }

  Future<UserProfile> _updateMyRow(Map<String, dynamic> payload) async {
    final uid = _requireUid();

    try {
      final data = await _client
          .from('profiles')
          .update(payload)
          .eq('id', uid)
          .select()
          .maybeSingle();

      if (data == null) throw AuthException('Profile tidak ditemukan.');
      return _attachEmail(UserProfile.fromMap(data));
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw AuthException('Username sudah digunakan.');
      throw AuthException(e.message);
    }
  }

  Future<void> _removeOwnedAvatar(String uid, String path) async {
    final normalized = path.trim();
    if (!normalized.startsWith('$uid/') || normalized.contains('..')) return;

    try {
      await _storage.remove(avatarsBucket, normalized);
    } catch (_) {
      return;
    }
  }

  String _safeToken() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
