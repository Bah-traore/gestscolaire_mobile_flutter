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

    // 401 sur login = identifiants invalides. La gestion "session expirée" se fait
    // plutôt côté appels authentifiés (refresh token) via l'interceptor.
    if (status == 401) {
      return 'Email/téléphone ou mot de passe incorrect.';
    }
    if (status == 404) {
      return 'Service indisponible pour le moment. Veuillez réessayer plus tard.';
    }
    if (status != null && status >= 500) {
      return 'Le serveur rencontre un problème. Veuillez réessayer plus tard.';
    }

    final data = e.response?.data;
    if (data is Map) {
      final mapped = Map<String, dynamic>.from(data);
      final reasonCode = mapped['reason_code']?.toString();
      final subscription = mapped['subscription'];
      final raw =
          mapped['error'] ??
          mapped['message'] ??
          mapped['detail'] ??
          (subscription is Map ? subscription['message'] : null);
      final safe = _sanitize(raw?.toString());
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
