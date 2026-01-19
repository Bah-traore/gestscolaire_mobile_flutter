import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  /// Obtenir l'utilisateur actuellement connecté
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Écouter les changements d'état de connexion
  Stream<GoogleSignInAccount?> get authStateChanges =>
      _googleSignIn.onCurrentUserChanged;

  /// Initialiser le service Google Sign-In
  Future<void> initialize() async {
    await _googleSignIn.signInSilently();
  }

  /// Se connecter avec Google
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Pour le web, utiliser la connexion web
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        return googleUser;
      } else {
        // Pour mobile
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        return googleUser;
      }
    } catch (error) {
      debugPrint('Google Sign-In Error: $error');
      rethrow;
    }
  }

  /// Se déconnecter de Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint('Google Sign-Out Error: $error');
      rethrow;
    }
  }

  /// Vérifier si l'utilisateur est connecté
  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// Obtenir les informations d'authentification
  Future<GoogleSignInAuthentication?> getAuthentication() async {
    final GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
    if (googleUser == null) return null;

    return await googleUser.authentication;
  }

  /// Rafraîchir la session de manière silencieuse
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (error) {
      debugPrint('Silent Sign-In Error: $error');
      return null;
    }
  }

  /// Révoquer l'accès
  Future<void> revokeAccess() async {
    try {
      await _googleSignIn.disconnect();
    } catch (error) {
      debugPrint('Revoke Access Error: $error');
      rethrow;
    }
  }
}
