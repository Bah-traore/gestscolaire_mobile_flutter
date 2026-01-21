/// Configuration centralisée de l'application
class AppConfig {
  // API Configuration
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api/';

  // App Info
  static const String appName = 'GestScolaire';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Feature Flags
  static const bool enableOfflineMode = true;
  static const bool enableDebugLogging = true;
  static const bool enableAnalytics = false;

  // Cache Configuration
  static const int cacheExpirationMinutes = 60;
  static const int maxCacheSize = 100; // MB

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 60);
  static const Duration connectionTimeout = Duration(seconds: 30);

  // Retry Configuration
  static const int maxRetries = 3;
  static const int retryDelayMs = 1000;

  // Environment
  static const String environment =
      'production'; // development, staging, production
  // Feature Availability
  static const Map<String, bool> features = {
    'offline_mode': true,
    'biometric_auth': true,
    'dark_mode': true,
    'notifications': true,
    'file_upload': true,
    'export_pdf': true,
  };

  /// Obtenir l'URL API complète
  static String getApiUrl(String endpoint) {
    return '$apiBaseUrl$endpoint';
  }

  /// Vérifier si une feature est activée
  static bool isFeatureEnabled(String feature) {
    return features[feature] ?? false;
  }

  /// Vérifier si on est en mode développement
  static bool isDevelopment() {
    return environment == 'development';
  }
}
