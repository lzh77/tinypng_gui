import 'package:logger/logger.dart';

class LoggerService {
  /// 日志开关
  static bool enabled = true;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Debug log
  static void d(String message) {
    if (!enabled) return;
    _logger.d(message);
  }

  /// Info log
  static void i(String message) {
    if (!enabled) return;
    _logger.i(message);
  }

  /// Warning log
  static void w(String message) {
    if (!enabled) return;
    _logger.w(message);
  }

  /// Error log
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!enabled) return;
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
