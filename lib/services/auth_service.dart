import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'google_auth_service.dart';

/// Service d'authentification
class AuthService {
  final ApiService _apiService;
  late SharedPreferences _prefs;

  Future<bool>? _refreshInFlight;

  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _lastTokenRefreshKey = 'last_token_refresh_ms';
  static const String _userKey = 'user_data';

  AuthService(this._apiService);

  /// Initialiser le service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Charger le token sauvegardé
    final token = _prefs.getString(_tokenKey);
    if (token != null) {
      _apiService.setAuthToken(token);
    }
  }

  /// Connexion
  Future<AuthResponse> login({
    required String email,
    required String password,
    String? tenantId,
  }) async {
    try {
      final request = LoginRequest(
        email: email,
        password: password,
        tenantId: tenantId,
      );

      final response = await _apiService.post<Map<String, dynamic>>(
        '/auth/login/',
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response);

      // Sauvegarder les tokens
      if (authResponse.accessToken != null) {
        await _prefs.setString(_tokenKey, authResponse.accessToken!);
      }
      if (authResponse.refreshToken != null) {
        await _prefs.setString(_refreshTokenKey, authResponse.refreshToken!);
      }

      // Sauvegarder les données utilisateur (JSON encodé correctement)
      if (authResponse.user != null) {
        await _prefs.setString(
          _userKey,
          jsonEncode(authResponse.user!.toJson()),
        );
      }

      // Définir le token dans le service API
      if (authResponse.accessToken != null) {
        _apiService.setAuthToken(authResponse.accessToken!);
      }

      return authResponse;
    } catch (e) {
      rethrow;
    }
  }

  /// Inscrire un nouvel utilisateur
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      final response = await _apiService.post(
        '/auth/register/',
        data: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
        },
      );

      return AuthResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Se connecter avec Google
  Future<AuthResponse> signInWithGoogle() async {
    try {
      final googleAuthService = GoogleAuthService();

      // Se connecter avec Google
      final googleUser = await googleAuthService.signInWithGoogle();
      if (googleUser == null) {
        throw Exception('Connexion Google annulée');
      }

      // Obtenir les informations d'authentification
      final googleAuth = await googleUser.authentication;

      // Envoyer les informations au backend Django
      final response = await _apiService.post(
        '/auth/google/',
        data: {
          'id_token': googleAuth.idToken,
          'access_token': googleAuth.accessToken,
          'email': googleUser.email,
          'name': googleUser.displayName,
          'photo_url': googleUser.photoUrl,
        },
      );

      final authResponse = AuthResponse.fromJson(response);

      // Si le backend renvoie des tokens, les sauvegarder.
      // Sinon, c'est un flow onboarding (requires_onboarding=true).
      if (authResponse.accessToken != null) {
        await _prefs.setString(_tokenKey, authResponse.accessToken!);
        _apiService.setAuthToken(authResponse.accessToken!);
      }
      if (authResponse.refreshToken != null) {
        await _prefs.setString(_refreshTokenKey, authResponse.refreshToken!);
      }
      if (authResponse.user != null) {
        await _prefs.setString(
          _userKey,
          jsonEncode(authResponse.user!.toJson()),
        );
      }

      return authResponse;
    } catch (e) {
      rethrow;
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    try {
      await _apiService.post('/auth/logout/', data: {});
    } catch (e) {
      // Continuer même si l'appel échoue
    }

    // Effacer les données locales
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.remove(_userKey);

    // Effacer le token du service API
    _apiService.clearAuthToken();
  }

  /// Finaliser l'onboarding téléphone (sans SMS)
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required int userId,
    String? otp,
    String? firebaseToken,
  }) async {
    try {
      final response = await _apiService.post(
        '/auth/google/verify-phone/',
        data: {
          'phone': phone,
          'user_id': userId,
          if (otp != null) 'otp': otp,
          if (firebaseToken != null) 'firebase_token': firebaseToken,
        },
      );

      final authResponse = AuthResponse.fromJson(response);

      // Sauvegarder les tokens et l'utilisateur
      if (authResponse.accessToken != null) {
        await _prefs.setString(_tokenKey, authResponse.accessToken!);
      }
      if (authResponse.refreshToken != null) {
        await _prefs.setString(_refreshTokenKey, authResponse.refreshToken!);
      }
      if (authResponse.user != null) {
        await _prefs.setString(
          _userKey,
          jsonEncode(authResponse.user!.toJson()),
        );
      }

      if (authResponse.accessToken != null) {
        _apiService.setAuthToken(authResponse.accessToken!);
      }

      return authResponse;
    } catch (e) {
      rethrow;
    }
  }

  /// Vérifier si l'utilisateur est connecté
  bool get isAuthenticated {
    return _prefs.containsKey(_tokenKey);
  }

  /// Mettre à jour les tokens (ex: après switch-establishment)
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _prefs.setString(_tokenKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _prefs.setString(_refreshTokenKey, refreshToken);
    }
    _apiService.setAuthToken(accessToken);
  }

  /// Obtenir le token actuel
  String? get token {
    return _prefs.getString(_tokenKey);
  }

  /// Obtenir le refresh token actuel
  String? get refreshToken {
    return _prefs.getString(_refreshTokenKey);
  }

  /// Rafraîchir l'access token (et mettre à jour le refresh token si renvoyé)
  Future<bool> refreshAccessToken() async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }

    final refresh = refreshToken;
    if (refresh == null || refresh.isEmpty) {
      return false;
    }

    _refreshInFlight = () async {
      // garde une trace du dernier refresh uniquement à titre indicatif
      final now = DateTime.now().millisecondsSinceEpoch;
      await _prefs.setInt(_lastTokenRefreshKey, now);

      final response = await _apiService.post<Map<String, dynamic>>(
        '/auth/refresh/',
        data: {'refresh_token': refresh},
      );

      final access = response['access_token'];
      final newRefresh = response['refresh_token'];
      if (access is String && access.isNotEmpty) {
        await setTokens(
          accessToken: access,
          refreshToken: newRefresh is String ? newRefresh : null,
        );
        return true;
      }

      return false;
    }();

    try {
      return await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Obtenir l'utilisateur actuel
  User? get currentUser {
    final userJson = _prefs.getString(_userKey);
    if (userJson == null) return null;

    try {
      final Map<String, dynamic> userMap = jsonDecode(userJson);
      return User.fromJson(userMap);
    } catch (e) {
      return null;
    }
  }

  /// Réinitialiser le mot de passe
  Future<void> resetPassword({required String email}) async {
    try {
      await _apiService.post('/auth/reset-password/', data: {'email': email});
    } catch (e) {
      rethrow;
    }
  }

  /// Confirmer la réinitialisation du mot de passe
  Future<void> confirmResetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _apiService.post(
        '/auth/confirm-reset-password/',
        data: {'token': token, 'new_password': newPassword},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Vérifier l'email
  Future<void> verifyEmail({required String token}) async {
    try {
      await _apiService.post('/auth/verify-email/', data: {'token': token});
    } catch (e) {
      rethrow;
    }
  }
}
