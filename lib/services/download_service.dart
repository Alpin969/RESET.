import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Blob')
external JSObject _createBlob(JSAny parts, JSObject options);

@JS('URL.createObjectURL')
external String _createObjectUrl(JSObject blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

@JS('document.createElement')
external JSObject _createElement(String tag);

@JS('document.body')
external JSObject get _documentBody;

void downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) {
  final blobParts = <JSAny>[content.toJS].toJS;
  final options = JSObject();
  options['type'] = mimeType.toJS;
  final blob = _createBlob(blobParts, options);
  final url = _createObjectUrl(blob);
  try {
    final anchor = _createElement('a');
    anchor['href'] = url.toJS;
    anchor['download'] = filename.toJS;
    _documentBody.callMethod<JSAny?>('appendChild'.toJS, anchor);
    try {
      anchor.callMethod<JSAny?>('click'.toJS);
    } finally {
      _documentBody.callMethod<JSAny?>('removeChild'.toJS, anchor);
    }
  } finally {
    _revokeObjectUrl(url);
  }
}

void downloadExportFile({
  required String filename,
  required String content,
  required String mimeType,
}) {
  try {
    downloadTextFile(
      filename: filename,
      content: content,
      mimeType: mimeType,
    );
  } catch (_) {
    throw StateError('Gagal mengunduh file export "$filename".');
  }
}
