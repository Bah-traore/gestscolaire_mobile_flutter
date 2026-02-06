## Solution de Gestion de Session Expirée - GestScolaire Mobile

### Problème
L'application mobile gestscolaire rencontrait un problème persistant de "session expirée" sans gestion appropriée, forçant les utilisateurs à fermer et rouvrir l'application.

### Solution Implémentée

#### 1. Amélioration du gestionnaire d'erreurs dans `api_service.dart`
- Détection des erreurs 401 (Unauthorized)
- Gestion spécifique des échecs de refresh token
- Déclenchement automatique de la déconnexion lorsque la session est vraiment expirée

#### 2. Création de `SessionExpiredHandler`
- Utilitaire centralisé pour gérer l'expiration de session
- Nettoyage complet des données locales
- Navigation automatique vers l'écran de login
- Affichage d'un message utilisateur convivial
- Protection contre les traitements multiples

#### 3. Mise à jour de `AuthProvider`
- Ajout de la méthode `handleSessionExpired()`
- Synchronisation de l'état de l'application
- Message d'erreur explicite pour l'utilisateur

### Fonctionnalités

#### Détection Automatique
- Erreur 401 sur endpoint de refresh → session expirée
- Échec de refresh après tentative 401 → session expirée
- Erreur lors du refresh → session expirée

#### Gestion Utilisateur
- Message clair : "Votre session a expiré. Veuillez vous reconnecter."
- Redirection automatique vers l'écran de login
- Nettoyage complet de la pile de navigation

#### Sécurité
- Protection contre les appels multiples
- Nettoyage complet des tokens et données utilisateur
- Gestion des erreurs silencieuse en cas de problème

### Fichiers Modifiés

1. **`lib/services/api_service.dart`**
   - Import de `SessionExpiredHandler`
   - Amélioration du gestionnaire d'erreurs 401
   - Déclenchement automatique de la déconnexion

2. **`lib/utils/session_expired_handler.dart`** (Nouveau)
   - Logique centralisée de gestion d'expiration
   - Navigation et messages utilisateur
   - Synchronisation avec AuthProvider

3. **`lib/providers/auth_provider.dart`**
   - Ajout de `handleSessionExpired()`
   - Mise à jour de l'état d'authentification
   - Message d'erreur spécifique

### Avantages

- **Expérience utilisateur améliorée** : Plus besoin de fermer l'application
- **Sécurité renforcée** : Nettoyage complet des données de session
- **Robustesse** : Gestion des cas limites et erreurs
- **Maintenance facile** : Logique centralisée et réutilisable

### Tests Recommandés

1. **Test d'expiration manuelle** : Supprimer le refresh token et tenter une requête
2. **Test d'expiration automatique** : Attendre l'expiration naturelle du token
3. **Test de navigation** : Vérifier la redirection vers login
4. **Test de messages** : Confirmer l'affichage du SnackBar
5. **Test de robustesse** : Simuler des erreurs réseau pendant le refresh

Cette solution élimine définitivement le problème de "session expirée" en offrant une gestion automatique et transparente pour l'utilisateur.