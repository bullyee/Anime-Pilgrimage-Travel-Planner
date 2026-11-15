// Export the correct implementation based on the current compilation target.
export 'unsupported.dart'
    if (dart.library.ffi) 'native.dart'
    if (dart.library.js_interop) 'web.dart';
