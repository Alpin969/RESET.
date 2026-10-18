import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('window')
external JSObject get jsWindow;

@JS('navigator')
external JSObject get jsNavigator;

@JS('navigator.userAgent')
external String get jsUserAgent;

@JS('Notification.permission')
external String get jsNotificationPermission;

@JS('Notification.requestPermission')
external JSPromise<JSString> jsNotificationRequestPermission();

@JS('localStorage')
external JSObject get jsLocalStorage;

@JS('JSON.stringify')
external String jsJsonStringify(JSAny? value);

extension type ServiceWorkerContainer._(JSObject _) implements JSObject {
  external JSPromise<ServiceWorkerRegistration> get ready;
  external JSPromise<ServiceWorkerRegistration> register(String scriptUrl);
}

extension type ServiceWorkerRegistration._(JSObject _) implements JSObject {
  external PushManager get pushManager;
}

extension type PushManager._(JSObject _) implements JSObject {
  external JSPromise<PushSubscription?> getSubscription();
  external JSPromise<PushSubscription> subscribe(JSObject options);
}

extension type PushSubscription._(JSObject _) implements JSObject {
  external String get endpoint;
  external JSObject toJSON();
  external JSPromise<JSBoolean> unsubscribe();
}

bool isWebPushSupported() {
  return jsWindow.has('Notification') &&
      jsNavigator.has('serviceWorker') &&
      jsWindow.has('PushManager');
}

String currentNotificationPermission() {
  if (!jsWindow.has('Notification')) {
    return 'unsupported';
  }
  return jsNotificationPermission;
}

Future<String> requestNotificationPermission() async {
  final result = await jsNotificationRequestPermission().toDart;
  return result.toDart;
}

ServiceWorkerContainer serviceWorkerContainer() {
  return jsNavigator['serviceWorker'] as ServiceWorkerContainer;
}

Uint8List urlBase64ToUint8Array(String input) {
  var normalized = input.trim().replaceAll('-', '+').replaceAll('_', '/');
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  return base64.decode(normalized);
}

JSObject buildSubscribeOptions(Uint8List applicationServerKey) {
  final options = JSObject();
  options['userVisibleOnly'] = true.toJS;
  options['applicationServerKey'] = applicationServerKey.toJS;
  return options;
}

Future<ServiceWorkerRegistration> registerPushServiceWorker(
  String scriptUrl,
) async {
  final container = serviceWorkerContainer();
  return container.register(scriptUrl).toDart;
}

Future<ServiceWorkerRegistration> waitForServiceWorker() async {
  final container = serviceWorkerContainer();
  return container.ready.toDart;
}

Future<PushSubscription?> getPushSubscription() async {
  final registration = await waitForServiceWorker();
  return registration.pushManager.getSubscription().toDart;
}

Future<PushSubscription> subscribePush(Uint8List applicationServerKey) async {
  final registration = await waitForServiceWorker();
  return registration.pushManager
      .subscribe(buildSubscribeOptions(applicationServerKey))
      .toDart;
}

Future<bool> unsubscribePush(PushSubscription subscription) async {
  final result = await subscription.unsubscribe().toDart;
  return result.toDart;
}

({String endpoint, String p256dh, String auth})? decodeSubscription(
  PushSubscription subscription,
) {
  final json = jsJsonStringify(subscription.toJSON());
  final decoded = jsonDecode(json);
  if (decoded is! Map) {
    return null;
  }
  final endpoint = decoded['endpoint'] as String?;
  final keys = decoded['keys'];
  if (endpoint == null || keys is! Map) {
    return null;
  }
  final p256dh = keys['p256dh'] as String?;
  final auth = keys['auth'] as String?;
  if (p256dh == null || auth == null) {
    return null;
  }
  return (endpoint: endpoint, p256dh: p256dh, auth: auth);
}

String? localStorageRead(String key) {
  final value = jsLocalStorage.callMethod<JSString?>(
    'getItem'.toJS,
    key.toJS,
  );
  return value?.toDart;
}

void localStorageWrite(String key, String value) {
  jsLocalStorage.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
}

void localStorageRemove(String key) {
  jsLocalStorage.callMethod<JSAny?>('removeItem'.toJS, key.toJS);
}
