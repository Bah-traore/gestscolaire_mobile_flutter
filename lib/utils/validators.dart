/// Utilitaires de validation
class Validators {
  /// Valider l'email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Veuillez entrer une adresse email valide';
    }
    
    return null;
  }
  
  /// Valider le mot de passe
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Le mot de passe doit contenir au moins une majuscule';
    }
    
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Le mot de passe doit contenir au moins une minuscule';
    }
    
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }
    
    return null;
  }
  
  /// Valider le téléphone
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est requis';
    }
    
    final phoneRegex = RegExp(r'^[+]?[0-9]{7,15}$');
    final cleanedPhone = value.replaceAll(RegExp(r'\s'), '');
    
    if (!phoneRegex.hasMatch(cleanedPhone)) {
      return 'Veuillez entrer un numéro de téléphone valide';
    }
    
    return null;
  }
  
  /// Valider le nom
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le nom est requis';
    }
    
    if (value.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }
    
    if (value.length > 50) {
      return 'Le nom ne doit pas dépasser 50 caractères';
    }
    
    return null;
  }
  
  /// Valider le champ requis
  static String? validateRequired(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    return null;
  }
  
  /// Valider la longueur minimale
  static String? validateMinLength(
    String? value, {
    required int minLength,
    String fieldName = 'Ce champ',
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    if (value.length < minLength) {
      return '$fieldName doit contenir au moins $minLength caractères';
    }
    
    return null;
  }
  
  /// Valider la longueur maximale
  static String? validateMaxLength(
    String? value, {
    required int maxLength,
    String fieldName = 'Ce champ',
  }) {
    if (value == null || value.isEmpty) {
      return null;
    }
    
    if (value.length > maxLength) {
      return '$fieldName ne doit pas dépasser $maxLength caractères';
    }
    
    return null;
  }
  
  /// Valider que deux champs correspondent
  static String? validateMatch(
    String? value,
    String? otherValue, {
    String fieldName = 'Ce champ',
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    if (value != otherValue) {
      return 'Les $fieldName ne correspondent pas';
    }
    
    return null;
  }
  
  /// Valider l'URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'URL est requise';
    }
    
    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );
    
    if (!urlRegex.hasMatch(value)) {
      return 'Veuillez entrer une URL valide';
    }
    
    return null;
  }
  
  /// Valider le numéro
  static String? validateNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le numéro est requis';
    }
    
    if (double.tryParse(value) == null) {
      return 'Veuillez entrer un numéro valide';
    }
    
    return null;
  }
}
