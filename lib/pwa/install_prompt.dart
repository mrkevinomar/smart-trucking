// Bridge to the browser's `beforeinstallprompt` event captured in
// `web/index.html`. On non-web platforms (tests) the stub reports that the
// prompt is unavailable, so the install sheet shows the manual steps.
export 'install_prompt_stub.dart'
    if (dart.library.js_interop) 'install_prompt_web.dart';
