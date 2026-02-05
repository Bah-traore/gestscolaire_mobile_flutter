import 'package:dio/dio.dart';

class UserFriendlyErrors {
  static String from(dynamic error) {
    if (error is DioException) {
      return fromDio(error);
    }

    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  static String fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'La connexion est trop lente. Veuillez réessayer.';
      case DioExceptionType.connectionError:
        return 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.';
      case DioExceptionType.cancel:
        return 'Requête annulée.';
      case DioExceptionType.badCertificate:
        return 'Connexion sécurisée impossible. Veuillez réessayer.';
      case DioExceptionType.unknown:
        return 'Impossible de se connecter. Vérifiez votre connexion Internet.';
      case DioExceptionType.badResponse:
        break;
    }

    final status = e.response?.statusCode;

    final data = e.response?.data;
    final Map<String, dynamic>? mapped = data is Map
        ? Map<String, dynamic>.from(data)
        : null;
    final raw = mapped?['error'] ?? mapped?['message'] ?? mapped?['detail'];

    final path = e.requestOptions.path;
    final isGoogleAuth =
        path == '/auth/google/' || path.endsWith('/auth/google/');

    // 401 sur login = identifiants invalides. La gestion "session expirée" se fait
    // plutôt côté appels authentifiés (refresh token) via l'interceptor.
    if (status == 401) {
      if (isGoogleAuth) {
        final data = e.response?.data;
        if (data is Map) {
          final mapped = Map<String, dynamic>.from(data);
          final errorCode = mapped['error_code']?.toString();
          final authReason = (mapped['details'] is Map)
              ? (mapped['details']['auth_reason']?.toString())
              : null;

          // Messages orientés utilisateur pour les cas fréquents en Google Auth.
          if (authReason == 'OAUTH_CONFIG_MISSING') {
            return 'Connexion Google indisponible pour le moment. Veuillez réessayer plus tard.';
          }
          if (authReason == 'TOKEN_EXPIRED') {
            return 'Votre session Google a expiré. Veuillez réessayer.';
          }
          if (authReason == 'TOKEN_INVALID') {
            return 'Impossible de vérifier votre connexion Google. Veuillez réessayer.';
          }

          // Fallback sur message backend s'il est déjà "safe".
          final raw = mapped['error'] ?? mapped['message'] ?? mapped['detail'];
          final safe = _sanitize(raw?.toString());
          if (safe != null && safe.isNotEmpty) {
            return safe;
          }

          // Cas 401 générique mais identifié.
          if (errorCode == 'AUTHENTICATION_ERROR') {
            return 'Échec de la connexion Google. Veuillez réessayer.';
          }
        }

        return 'Échec de la connexion Google. Veuillez réessayer.';
      }

      final data = e.response?.data;
      if (data is Map) {
        final mapped = Map<String, dynamic>.from(data);
        final errorCode = mapped['error_code']?.toString();
        if (errorCode == 'ACCOUNT_INACTIVE') {
          return 'Votre compte n\'est pas encore activé. Vérifiez votre email puis réessayez.';
        }
      }

      return 'Email/téléphone ou mot de passe incorrect.';
    }
    if (status == 404) {
      final safe = _sanitize(raw?.toString());
      if (safe != null && safe.isNotEmpty) {
        return safe;
      }
      return 'Service indisponible pour le moment. Veuillez réessayer plus tard.';
    }
    if (status == 409) {
      final data = e.response?.data;
      if (data is Map) {
        final mapped = Map<String, dynamic>.from(data);
        final errorCode = mapped['error_code']?.toString();
        final details = mapped['details'] is Map
            ? Map<String, dynamic>.from(mapped['details'])
            : null;

        if (errorCode == 'DUPLICATE_RESOURCE') {
          final field = details?['duplicate_field']?.toString() ?? '';
          if (field == 'telephone' || field == 'phone') {
            return 'Ce numéro de téléphone est déjà utilisé. Veuillez en choisir un autre.';
          }
          if (field == 'email') {
            return 'Cet email est déjà utilisé. Veuillez en choisir un autre.';
          }
          return 'Cette information existe déjà. Veuillez en choisir une autre.';
        }
      }

      final safe = _sanitize(raw?.toString());
      if (safe != null && safe.isNotEmpty) {
        return safe;
      }
      return 'Cette information existe déjà.';
    }

    if (mapped != null) {
      final reasonCode = mapped['reason_code']?.toString();
      final subscription = mapped['subscription'];
      final rawWithSubscription =
          raw ?? (subscription is Map ? subscription['message'] : null);
      final safe = _sanitize(rawWithSubscription?.toString());
      if (safe != null && safe.isNotEmpty) {
        return safe;
      }

      if (status == 403 && reasonCode == 'CSRF cookie not set.') {
        return 'Les cookies de sécurité sont bloqués. Activez-les puis réessayez.';
      }
    }

    if (status == 403) {
      return 'Accès refusé.';
    }

    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  static String? _sanitize(String? msg) {
    if (msg == null) return null;
    final s = msg.trim();
    if (s.isEmpty) return null;

    // Mappings for common technical backend messages.
    final lowerFull = s.toLowerCase();
    if (lowerFull.contains('tenant_id') && lowerFull.contains('requis')) {
      return 'Veuillez choisir une école, puis réessayer.';
    }
    if (lowerFull.contains('eleve_id') && lowerFull.contains('requis')) {
      return 'Veuillez sélectionner un enfant, puis réessayer.';
    }

    // Drop obviously technical/internal strings.
    final lower = s.toLowerCase();
    if (lower.contains('exception') ||
        lower.contains('stack trace') ||
        lower.contains('traceback') ||
        lower.contains('dioexception') ||
        lower.contains('null') ||
        lower.contains('keyerror') ||
        lower.contains('attributeerror') ||
        lower.contains('typeerror') ||
        lower.contains('valueerror') ||
        lower.contains('tenant_id') ||
        lower.contains('eleve_id')) {
      return null;
    }

    return s;
  }
}
