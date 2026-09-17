import 'dart:developer' as developer;

/// 轻量日志封装。
///
/// 基于 `dart:developer`，不依赖 Flutter，可在引擎层（纯 Dart）直接使用。
/// M1 采用极简实现，后续可接入统一日志通道。
class Logger {
  Logger._();

  /// 全局开关，便于发布时静默。
  static bool enabled = true;

  static void d(String tag, String message) {
    if (enabled) developer.log(message, name: tag, level: 500);
  }

  static void i(String tag, String message) {
    if (enabled) developer.log(message, name: tag, level: 800);
  }

  static void w(String tag, String message) {
    if (enabled) developer.log(message, name: tag, level: 900);
  }

  static void e(String tag, String message, [Object? error]) {
    if (enabled) {
      developer.log(
        error == null ? message : '$message -> $error',
        name: tag,
        level: 1000,
      );
    }
  }
}
