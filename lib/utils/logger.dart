import 'package:logger/logger.dart';
import '../config/app_config.dart';

/// Service de logging centralisé
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    filter: ProductionFilter(),
  );
  
  /// Logger un message de debug
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (AppConfig.enableDebugLogging) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }
  
  /// Logger un message d'information
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }
  
  /// Logger un message d'avertissement
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }
  
  /// Logger une erreur
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
  
  /// Logger une erreur critique
  static void critical(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.wtf(message, error: error, stackTrace: stackTrace);
  }
  
  /// Logger une requête API
  static void logApiRequest(String method, String url, {dynamic data}) {
    if (AppConfig.enableDebugLogging) {
      _logger.d(
        'API REQUEST: $method $url',
        error: data,
      );
    }
  }
  
  /// Logger une réponse API
  static void logApiResponse(String method, String url, int statusCode, {dynamic data}) {
    if (AppConfig.enableDebugLogging) {
      _logger.d(
        'API RESPONSE: $method $url ($statusCode)',
        error: data,
      );
    }
  }
  
  /// Logger une erreur API
  static void logApiError(String method, String url, int statusCode, {dynamic error}) {
    _logger.e(
      'API ERROR: $method $url ($statusCode)',
      error: error,
    );
  }
  
  /// Logger un événement utilisateur
  static void logUserEvent(String event, {Map<String, dynamic>? data}) {
    if (AppConfig.enableDebugLogging) {
      _logger.i(
        'USER EVENT: $event',
        error: data,
      );
    }
  }
  
  /// Logger une action
  static void logAction(String action, {String? details}) {
    if (AppConfig.enableDebugLogging) {
      _logger.i('ACTION: $action${details != null ? ' - $details' : ''}');
    }
  }
}

/// Filtre pour la production
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}
