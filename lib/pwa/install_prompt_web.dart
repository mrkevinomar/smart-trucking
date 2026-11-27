import 'dart:js_interop';

@JS('window.smartTruckingInstall')
external _InstallBridge? get _bridge;

extension type _InstallBridge(JSObject _) implements JSObject {
  external bool get available;
  external bool get standalone;
  external JSPromise<JSBoolean> prompt();
}

/// Web implementation backed by the small script in `web/index.html` that
/// stores the deferred `beforeinstallprompt` event.
class InstallPrompt {
  const InstallPrompt._();

  static bool get isAvailable => _bridge?.available ?? false;

  static bool get isStandalone => _bridge?.standalone ?? false;

  static Future<bool> show() async {
    final b = _bridge;
    if (b == null || !b.available) return false;
    final result = await b.prompt().toDart;
    return result.toDart;
  }
}
