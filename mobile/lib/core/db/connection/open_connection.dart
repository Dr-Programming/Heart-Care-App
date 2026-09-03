/// Platform-aware picker for the on-device database connection.
///
/// Dart's conditional imports resolve `openDatabaseConnection()` to the native
/// implementation everywhere except web (`dart.library.js_interop`), where the
/// WebAssembly implementation is used instead. This split keeps `dart:io` and
/// `dart:ffi` (pulled in by `package:drift/native.dart`) out of the web
/// compilation, which cannot resolve them.
library;

export 'open_connection_native.dart'
    if (dart.library.js_interop) 'open_connection_web.dart';
