# Architecture GestEcole Mobile

## 📱 Vue d'ensemble

GestEcole Mobile est une application Flutter moderne pour la gestion scolaire. Elle suit une architecture modulaire et scalable avec une séparation claire des responsabilités.

## 🏗️ Structure du projet

```
lib/
├── config/                 # Configuration de l'application
│   ├── app_config.dart    # Configuration globale
│   └── app_theme.dart     # Thème et design system
├── models/                # Modèles de données
│   └── user_model.dart    # Modèle utilisateur
├── services/              # Services métier
│   ├── api_service.dart   # Service API HTTP
│   └── auth_service.dart  # Service d'authentification
├── screens/               # Écrans de l'application
│   ├── login_screen.dart  # Écran de connexion
│   └── dashboard_screen.dart # Tableau de bord
├── providers/             # Providers (gestion d'état)
│   └── auth_provider.dart # Provider d'authentification
├── widgets/               # Widgets réutilisables
│   ├── custom_button.dart # Boutons personnalisés
│   └── custom_text_field.dart # Champs de texte
├── utils/                 # Utilitaires
│   ├── validators.dart    # Validateurs
│   └── extensions.dart    # Extensions Dart
└── main.dart              # Point d'entrée
```

## 🎨 Design System

### Couleurs
- **Primaire**: `#2563EB` (Bleu)
- **Secondaire**: `#10B981` (Vert)
- **Accent**: `#F59E0B` (Ambre)
- **Erreur**: `#EF4444` (Rouge)
- **Succès**: `#10B981` (Vert)

### Espacement
- `xs`: 4px
- `sm`: 8px
- `md`: 12px
- `lg`: 16px
- `xl`: 20px
- `xxl`: 24px
- `xxxl`: 32px

### Rayon de bordure
- `small`: 4px
- `medium`: 8px
- `large`: 12px
- `xl`: 16px
- `circle`: 999px

## 🔐 Authentification

### Flux de connexion
1. L'utilisateur entre ses identifiants
2. `AuthProvider.login()` est appelé
3. `AuthService` effectue l'appel API
4. Les tokens sont sauvegardés localement
5. L'utilisateur est redirigé vers le dashboard

### Gestion des tokens
- **Access Token**: Stocké en `SharedPreferences`
- **Refresh Token**: Stocké en `SharedPreferences`
- **Expiration**: Gérée automatiquement par le service

## 📡 API Service

### Configuration
```dart
ApiService apiService = ApiService();
apiService.setAuthToken('token');
```

### Utilisation
```dart
// GET
final data = await apiService.get<Map>('/endpoint');

// POST
final response = await apiService.post<Map>(
  '/endpoint',
  data: {'key': 'value'},
);

// Upload fichier
await apiService.uploadFile(
  '/upload',
  '/path/to/file',
);
```

## 🔄 Gestion d'état avec Provider

### AuthProvider
```dart
// Accéder au provider
final authProvider = context.read<AuthProvider>();

// Écouter les changements
Consumer<AuthProvider>(
  builder: (context, authProvider, _) {
    return Text(authProvider.currentUser?.fullName ?? 'Guest');
  },
)
```

## 🎯 Bonnes pratiques

### 1. Validation
```dart
// Utiliser les validateurs
CustomTextField(
  validator: Validators.validateEmail,
)
```

### 2. Gestion d'erreurs
```dart
try {
  await authService.login(...);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString())),
  );
}
```

### 3. Chargement asynchrone
```dart
Consumer<AuthProvider>(
  builder: (context, authProvider, _) {
    if (authProvider.isLoading) {
      return const CircularProgressIndicator();
    }
    return Text(authProvider.currentUser?.fullName ?? '');
  },
)
```

### 4. Extensions
```dart
// Utiliser les extensions
String email = "test@example.com";
if (email.isValidEmail) {
  // ...
}

DateTime date = DateTime.now();
print(date.toFormattedString()); // 01/01/2024
```

## 📦 Dépendances principales

- **provider**: Gestion d'état
- **dio**: Requêtes HTTP
- **shared_preferences**: Stockage local
- **google_fonts**: Polices personnalisées
- **intl**: Internationalisation

## 🚀 Déploiement

### Android
```bash
flutter build apk --release
# ou
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 🧪 Tests

### Tests unitaires
```bash
flutter test
```

### Tests d'intégration
```bash
flutter drive --target=test_driver/app.dart
```

## 📝 Conventions de code

### Nommage
- **Classes**: `PascalCase` (ex: `AuthProvider`)
- **Fichiers**: `snake_case` (ex: `auth_provider.dart`)
- **Variables**: `camelCase` (ex: `isLoading`)
- **Constantes**: `camelCase` (ex: `defaultTimeout`)

### Imports
```dart
// 1. Dart imports
import 'dart:async';

// 2. Flutter imports
import 'package:flutter/material.dart';

// 3. Package imports
import 'package:provider/provider.dart';

// 4. Relative imports
import '../config/app_theme.dart';
```

### Documentation
```dart
/// Courte description
/// 
/// Description plus détaillée si nécessaire.
/// 
/// Exemple:
/// ```dart
/// final result = myFunction();
/// ```
class MyClass {
  /// Getter pour obtenir la valeur
  String get value => _value;
}
```

## 🔗 Ressources

- [Flutter Documentation](https://flutter.dev/docs)
- [Provider Package](https://pub.dev/packages/provider)
- [Dio Documentation](https://pub.dev/packages/dio)
- [Material Design](https://material.io/design)

## 📧 Support

Pour toute question ou problème, veuillez contacter l'équipe de développement.
