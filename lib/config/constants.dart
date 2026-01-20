/// Constantes de l'application
class AppConstants {
  // Messages
  static const String appName = 'GestScolaire';
  static const String appVersion = '1.0.0';
  
  // Erreurs
  static const String errorGeneral = 'Une erreur inattendue est survenue';
  static const String errorNetwork = 'Erreur de connexion réseau';
  static const String errorTimeout = 'La requête a expiré';
  static const String errorUnauthorized = 'Accès non autorisé';
  static const String errorNotFound = 'Ressource non trouvée';
  static const String errorServerError = 'Erreur serveur';
  
  // Validation
  static const String errorEmailRequired = 'L\'email est requis';
  static const String errorEmailInvalid = 'Email invalide';
  static const String errorPasswordRequired = 'Le mot de passe est requis';
  static const String errorPasswordTooShort = 'Le mot de passe doit contenir au moins 8 caractères';
  static const String errorPasswordMismatch = 'Les mots de passe ne correspondent pas';
  static const String errorPhoneRequired = 'Le numéro de téléphone est requis';
  static const String errorPhoneInvalid = 'Numéro de téléphone invalide';
  static const String errorNameRequired = 'Le nom est requis';
  
  // Succès
  static const String successLogin = 'Connexion réussie';
  static const String successLogout = 'Déconnexion réussie';
  static const String successRegister = 'Inscription réussie';
  static const String successUpdate = 'Mise à jour réussie';
  static const String successDelete = 'Suppression réussie';
  
  // Durées
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration dialogDuration = Duration(milliseconds: 500);
  
  // Tailles
  static const double minPasswordLength = 8;
  static const double maxPasswordLength = 128;
  static const double minNameLength = 2;
  static const double maxNameLength = 50;
  
  // Regex
  static const String emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phoneRegex = r'^[+]?[0-9]{7,15}$';
  static const String urlRegex = r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$';
  
  // API Endpoints
  static const String loginEndpoint = '/auth/login/';
  static const String registerEndpoint = '/auth/register/';
  static const String logoutEndpoint = '/auth/logout/';
  static const String refreshTokenEndpoint = '/auth/refresh/';
  static const String resetPasswordEndpoint = '/auth/reset-password/';
  static const String verifyEmailEndpoint = '/auth/verify-email/';
  
  // Clés SharedPreferences
  static const String prefKeyAuthToken = 'auth_token';
  static const String prefKeyRefreshToken = 'refresh_token';
  static const String prefKeyUserData = 'user_data';
  static const String prefKeyThemeMode = 'theme_mode';
  static const String prefKeyLanguage = 'language';
  
  // Types d'utilisateurs
  static const String userTypeAdmin = 'admin';
  static const String userTypeParent = 'parent';
  static const String userTypeStudent = 'student';
  static const String userTypeTeacher = 'teacher';
  
  // Statuts
  static const String statusActive = 'active';
  static const String statusInactive = 'inactive';
  static const String statusPending = 'pending';
  static const String statusArchived = 'archived';
  
  // Langues supportées
  static const List<String> supportedLanguages = ['fr', 'en', 'ar'];
  static const String defaultLanguage = 'fr';
  
  // Thèmes
  static const String themeLight = 'light';
  static const String themeDark = 'dark';
  static const String themeSystem = 'system';
}

/// Messages de l'application
class AppMessages {
  // Authentification
  static const String welcomeMessage = 'Bienvenue dans GestEcole';
  static const String loginMessage = 'Connectez-vous à votre compte';
  static const String registerMessage = 'Créez un nouveau compte';
  static const String logoutMessage = 'Êtes-vous sûr de vouloir vous déconnecter?';
  
  // Validation
  static const String fieldRequired = 'Ce champ est requis';
  static const String invalidEmail = 'Adresse email invalide';
  static const String invalidPhone = 'Numéro de téléphone invalide';
  static const String passwordTooShort = 'Le mot de passe est trop court';
  static const String passwordMismatch = 'Les mots de passe ne correspondent pas';
  
  // Erreurs
  static const String errorOccurred = 'Une erreur est survenue';
  static const String tryAgain = 'Réessayer';
  static const String cancel = 'Annuler';
  static const String ok = 'OK';
  static const String yes = 'Oui';
  static const String no = 'Non';
  
  // Navigation
  static const String home = 'Accueil';
  static const String profile = 'Profil';
  static const String settings = 'Paramètres';
  static const String logout = 'Déconnexion';
}
