import 'package:connectivity_plus/connectivity_plus.dart';

/// Service de gestion du réseau
class NetworkService {
  static final Connectivity _connectivity = Connectivity();
  
  /// Vérifier la connexion réseau
  static Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }
  
  /// Obtenir le type de connexion
  static Future<ConnectivityResult> getConnectionType() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      return ConnectivityResult.none;
    }
  }
  
  /// Vérifier si la connexion est WiFi
  static Future<bool> isWiFi() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.wifi;
    } catch (e) {
      return false;
    }
  }
  
  /// Vérifier si la connexion est mobile
  static Future<bool> isMobile() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.mobile;
    } catch (e) {
      return false;
    }
  }
  
  /// Écouter les changements de connexion
  static Stream<ConnectivityResult> onConnectivityChanged() {
    return _connectivity.onConnectivityChanged;
  }
  
  /// Obtenir le nom du type de connexion
  static String getConnectionTypeName(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Autre';
      case ConnectivityResult.none:
        return 'Aucune';
    }
  }
}

/// Classe pour les erreurs réseau
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalException;
  
  NetworkException({
    required this.message,
    this.statusCode,
    this.originalException,
  });
  
  @override
  String toString() => 'NetworkException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Classe pour les erreurs de timeout
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;
  
  TimeoutException({
    required this.message,
    required this.timeout,
  });
  
  @override
  String toString() => 'TimeoutException: $message (Timeout: ${timeout.inSeconds}s)';
}

/// Classe pour les erreurs de validation
class ValidationException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;
  
  ValidationException({
    required this.message,
    this.errors,
  });
  
  @override
  String toString() => 'ValidationException: $message';
}

/// Classe pour les erreurs d'authentification
class AuthenticationException implements Exception {
  final String message;
  final int? statusCode;
  
  AuthenticationException({
    required this.message,
    this.statusCode,
  });
  
  @override
  String toString() => 'AuthenticationException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Classe pour les erreurs d'autorisation
class AuthorizationException implements Exception {
  final String message;
  final int? statusCode;
  
  AuthorizationException({
    required this.message,
    this.statusCode,
  });
  
  @override
  String toString() => 'AuthorizationException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Classe pour les erreurs serveur
class ServerException implements Exception {
  final String message;
  final int statusCode;
  final dynamic response;
  
  ServerException({
    required this.message,
    required this.statusCode,
    this.response,
  });
  
  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}
