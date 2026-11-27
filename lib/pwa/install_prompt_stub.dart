/// Non-web implementation: the native install prompt never exists.
class InstallPrompt {
  const InstallPrompt._();

  static bool get isAvailable => false;

  static bool get isStandalone => false;

  /// Returns `true` when the user accepted the native prompt.
  static Future<bool> show() async => false;
}
