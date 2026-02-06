import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../main.dart';

/// Utilitaire pour gérer l'expiration de session
class SessionExpiredHandler {
  static bool _isHandling = false;

  /// Gérer l'expiration de session de manière centralisée
  static Future<void> handleSessionExpired(AuthService authService) async {
    // Éviter les traitements multiples
    if (_isHandling) return;
    _isHandling = true;

    try {
      // Effacer les données locales
      await authService.logout();

      // Notifier le AuthProvider pour mettre à jour l'état
      final context = MyApp.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.handleSessionExpired();

        // Afficher un message à l'utilisateur
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre session a expiré. Veuillez vous reconnecter.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );

          // Rediriger vers l'écran de login en nettoyant la pile de navigation
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      // En cas d'erreur, forcer la déconnexion sans navigation
      try {
        await authService.logout();
      } catch (_) {
        // Ignorer les erreurs de déconnexion
      }
    } finally {
      _isHandling = false;
    }
  }

  /// Réinitialiser le flag (utilisé pour les tests)
  static void reset() {
    _isHandling = false;
  }
}