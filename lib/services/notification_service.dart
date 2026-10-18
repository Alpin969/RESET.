import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/notification_repository.dart';
import 'web_push_interop.dart';

enum PushSetupStatus {
  success,
  unsupported,
  permissionDenied,
  configMissing,
  failure,
}

class PushSetupResult {
  final PushSetupStatus status;
  final String message;

  const PushSetupResult(this.status, this.message);
}

class NotificationService {
  NotificationService({NotificationRepository? notificationRepository})
    : _repository = notificationRepository ?? NotificationRepository();

  final NotificationRepository _repository;

  static const String _endpointStorageKey = 'reset_push_endpoint';
  static const String _serviceWorkerFile = 'push-sw.js';

  bool get isSupported => isWebPushSupported();

  String get permissionStatus => currentNotificationPermission();

  Future<PushSetupResult> enableNotifications() async {
    if (!isSupported) {
      return const PushSetupResult(
        PushSetupStatus.unsupported,
        'Browser ini tidak mendukung notifikasi.',
      );
    }

    if (currentNotificationPermission() == 'denied') {
      return const PushSetupResult(
        PushSetupStatus.permissionDenied,
        'Izin notifikasi ditolak. Ubah izin lewat pengaturan browser.',
      );
    }

    if (currentNotificationPermission() != 'granted') {
      final permission = await requestNotificationPermission();
      if (permission != 'granted') {
        return const PushSetupResult(
          PushSetupStatus.permissionDenied,
          'Izin notifikasi belum diberikan.',
        );
      }
    }

    final publicKey = await _repository.getPushPublicKey();
    if (publicKey.trim().isEmpty) {
      return const PushSetupResult(
        PushSetupStatus.configMissing,
        'Konfigurasi push belum lengkap di server.',
      );
    }

    try {
      await registerPushServiceWorker(_serviceWorkerFile);
      await waitForServiceWorker();

      final subscription = await getOrCreateSubscription(publicKey);
      final data = decodeSubscription(subscription);
      if (data == null) {
        return const PushSetupResult(
          PushSetupStatus.failure,
          'Gagal membaca subscription perangkat.',
        );
      }

      await _repository.registerPushSubscription(
        endpoint: data.endpoint,
        p256dh: data.p256dh,
        auth: data.auth,
        deviceName: 'Web',
        userAgent: jsUserAgent,
      );
      localStorageWrite(_endpointStorageKey, data.endpoint);

      return const PushSetupResult(
        PushSetupStatus.success,
        'Notifikasi berhasil diaktifkan.',
      );
    } on AuthException catch (error) {
      return PushSetupResult(PushSetupStatus.failure, error.message);
    } catch (_) {
      return const PushSetupResult(
        PushSetupStatus.failure,
        'Gagal mengaktifkan notifikasi.',
      );
    }
  }

  Future<PushSetupResult> disableNotifications() async {
    if (!isSupported) {
      localStorageRemove(_endpointStorageKey);
      return const PushSetupResult(
        PushSetupStatus.success,
        'Browser ini tidak mendukung notifikasi.',
      );
    }

    try {
      final subscription = await getPushSubscription();
      if (subscription != null) {
        final data = decodeSubscription(subscription);
        if (data != null) {
          await _repository.unregisterPushSubscription(data.endpoint);
        } else {
          final stored = localStorageRead(_endpointStorageKey);
          if (stored != null && stored.isNotEmpty) {
            await _repository.unregisterPushSubscription(stored);
          }
        }
        await unsubscribePush(subscription);
      } else {
        final stored = localStorageRead(_endpointStorageKey);
        if (stored != null && stored.isNotEmpty) {
          await _repository.unregisterPushSubscription(stored);
        }
      }
      localStorageRemove(_endpointStorageKey);

      return const PushSetupResult(
        PushSetupStatus.success,
        'Notifikasi dimatikan di perangkat ini.',
      );
    } on AuthException catch (error) {
      return PushSetupResult(PushSetupStatus.failure, error.message);
    } catch (_) {
      return const PushSetupResult(
        PushSetupStatus.failure,
        'Gagal mematikan notifikasi.',
      );
    }
  }

  Future<void> syncOnAppStart() async {
    if (!isSupported) {
      return;
    }

    if (currentNotificationPermission() == 'granted') {
      try {
        final subscription = await getPushSubscription();
        if (subscription == null) {
          return;
        }
        final data = decodeSubscription(subscription);
        if (data == null) {
          return;
        }
        await _repository.registerPushSubscription(
          endpoint: data.endpoint,
          p256dh: data.p256dh,
          auth: data.auth,
          deviceName: 'Web',
          userAgent: jsUserAgent,
        );
        localStorageWrite(_endpointStorageKey, data.endpoint);
      } catch (_) {}
      return;
    }

    final stored = localStorageRead(_endpointStorageKey);
    if (stored != null && stored.isNotEmpty) {
      try {
        await _repository.unregisterPushSubscription(stored);
      } catch (_) {}
      localStorageRemove(_endpointStorageKey);
    }
  }

  Future<void> cleanupOnSignOut() async {
    if (isSupported) {
      try {
        final subscription = await getPushSubscription();
        if (subscription != null) {
          await unsubscribePush(subscription);
        }
      } catch (_) {}
    }

    try {
      await _repository.unregisterAllPushSubscriptions();
    } catch (_) {}

    if (isSupported) {
      localStorageRemove(_endpointStorageKey);
    }
  }

  Future<PushSubscription> getOrCreateSubscription(String publicKey) async {
    final existing = await getPushSubscription();
    if (existing != null) {
      return existing;
    }
    final applicationServerKey = urlBase64ToUint8Array(publicKey);
    return subscribePush(applicationServerKey);
  }
}
