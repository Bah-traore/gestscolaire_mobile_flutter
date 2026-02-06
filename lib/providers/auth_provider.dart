import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/user_friendly_errors.dart';
import '../utils/session_expired_handler.dart';

/// Provider pour la gestion de l'authentification
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  AuthProvider(this._authService) {
    _isAuthenticated = _authService.isAuthenticated;
    _currentUser = _authService.currentUser;
  }

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> _reloadUserFromStorage() async {
    _currentUser = _authService.currentUser;
    notifyListeners();
  }

  /// Initialiser le provider
  Future<void> init() async {
    await _authService.init();
    _isAuthenticated = _authService.isAuthenticated;
    _currentUser = _authService.currentUser;
    notifyListeners();
  }

  /// Connexion
  Future<bool> login({
    required String identifier,
    required String password,
    String? tenantId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        identifier: identifier,
        password: password,
        tenantId: tenantId,
      );

      _currentUser = response.user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();

      return false;
    }
  }

  Future<bool> confirmResetPasswordEmail({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.confirmResetPasswordEmail(
        email: email,
        token: token,
        newPassword: newPassword,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Inscription
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    String? tenantId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phoneNumber ?? '',
      );

      _currentUser = response.user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();

      return false;
    }
  }

  /// Connexion avec Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.signInWithGoogle();

      _currentUser = response.user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();

      return false;
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();

      _currentUser = null;
      _isAuthenticated = false;
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Gérer l'expiration de session (appelé par SessionExpiredHandler)
  Future<void> handleSessionExpired() async {
    if (!_isAuthenticated) return; // Déjà déconnecté
    
    _currentUser = null;
    _isAuthenticated = false;
    _error = 'Votre session a expiré. Veuillez vous reconnecter.';
    _isLoading = false;
    notifyListeners();
  }

  /// Réinitialiser le mot de passe
  Future<bool> resetPassword({required String email}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email: email);

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();

      return false;
    }
  }

  /// Confirmer la réinitialisation du mot de passe
  Future<bool> confirmResetPassword({
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.confirmResetPassword(
        token: token,
        newPassword: newPassword,
      );

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();

      return false;
    }
  }

  /// Vérifier l'email
  Future<bool> verifyEmail({required String token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.verifyEmail(token: token);

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();

      return false;
    }
  }

  /// Effacer l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> updatePhone({required String phone}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _authService.updatePhone(phone: phone);
      await _reloadUserFromStorage();
      _isLoading = false;
      notifyListeners();
      return resp;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.setPassword(
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = UserFriendlyErrors.from(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
