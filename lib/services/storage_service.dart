import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _client.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return path;
  }

  Future<void> remove(String bucket, String path) async {
    await _client.storage.from(bucket).remove([path]);
  }

  String publicUrl({required String bucket, required String path}) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<List<FileObject>> list(String bucket, String path) {
    return _client.storage.from(bucket).list(path: path);
  }
}
