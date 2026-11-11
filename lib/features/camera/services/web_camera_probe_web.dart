import 'dart:js_interop';

@JS('navigator')
external JSObject? get _navigator;

extension type _NavigatorMedia(JSObject _) implements JSObject {
  external JSAny? get mediaDevices;
}

/// True when the browser exposes `navigator.mediaDevices` (secure HTTPS or
/// localhost contexts) so the in-app Web camera can request access on demand
/// without prompting at app startup.
bool get webCameraAvailable {
  final nav = _navigator;
  if (nav == null) return false;
  return _NavigatorMedia(nav).mediaDevices != null;
}
