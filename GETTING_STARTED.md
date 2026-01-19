# Guide de démarrage - GestEcole Mobile

## 📋 Prérequis

- Flutter SDK 3.9.2 ou supérieur
- Dart SDK 3.9.2 ou supérieur
- Android Studio ou Xcode (pour le développement mobile)
- Un éditeur de code (VS Code, Android Studio, etc.)

## 🚀 Installation

### 1. Cloner le projet
```bash
git clone <repository-url>
cd gestscolaire
```

### 2. Installer les dépendances
```bash
flutter pub get
```

### 3. Générer les fichiers de modèles (si nécessaire)
```bash
flutter pub run build_runner build
```

### 4. Lancer l'application
```bash
flutter run
```

## 📱 Développement

### Structure du projet
```
lib/
├── config/          # Configuration et thème
├── models/          # Modèles de données
├── services/        # Services métier
├── screens/         # Écrans de l'application
├── providers/       # Gestion d'état
├── widgets/         # Widgets réutilisables
├── utils/           # Utilitaires
└── main.dart        # Point d'entrée
```

### Ajouter une nouvelle dépendance
```bash
flutter pub add <package-name>
```

### Mettre à jour les dépendances
```bash
flutter pub upgrade
```

## 🔧 Configuration

### Variables d'environnement
Créer un fichier `.env` à la racine du projet :
```
API_BASE_URL=https://gestscolaire.com/api
API_TIMEOUT=30
ENABLE_DEBUG_LOGGING=true
```

### Configuration API
Modifier `lib/config/app_config.dart` pour configurer l'URL de base de l'API :
```dart
static const String apiBaseUrl = 'https://votre-api.com/api';
```

## 🧪 Tests

### Exécuter tous les tests
```bash
flutter test
```

### Exécuter un test spécifique
```bash
flutter test test/path/to/test.dart
```

### Tests d'intégration
```bash
flutter drive --target=test_driver/app.dart
```

## 📦 Build

### Android
```bash
# Debug
flutter build apk --debug

# Release
flutter build apk --release

# App Bundle
flutter build appbundle --release
```

### iOS
```bash
# Debug
flutter build ios --debug

# Release
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 🐛 Dépannage

### Erreur: "Flutter SDK not found"
```bash
flutter doctor
flutter pub get
```

### Erreur: "Unable to find a matching variant"
```bash
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build
```

### Erreur: "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

## 📚 Ressources

- [Documentation Flutter](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Material Design](https://material.io/design)
- [Provider Package](https://pub.dev/packages/provider)

## 🤝 Contribution

1. Créer une branche pour votre feature (`git checkout -b feature/AmazingFeature`)
2. Commiter vos changements (`git commit -m 'Add some AmazingFeature'`)
3. Pousser vers la branche (`git push origin feature/AmazingFeature`)
4. Ouvrir une Pull Request

## 📝 Conventions de code

### Formatage
```bash
# Formater le code
dart format lib/

# Analyser le code
dart analyze
```

### Nommage
- **Classes**: `PascalCase`
- **Fichiers**: `snake_case`
- **Variables**: `camelCase`
- **Constantes**: `camelCase`

### Documentation
```dart
/// Courte description
/// 
/// Description plus détaillée si nécessaire.
class MyClass {
  /// Getter pour obtenir la valeur
  String get value => _value;
}
```

## 🔐 Sécurité

### Bonnes pratiques
- Ne jamais commiter les fichiers `.env` ou les clés API
- Utiliser les variables d'environnement pour les données sensibles
- Valider toutes les entrées utilisateur
- Utiliser HTTPS pour les communications API
- Implémenter le chiffrement pour les données sensibles

## 📞 Support

Pour toute question ou problème, veuillez :
1. Vérifier la documentation
2. Consulter les issues existantes
3. Créer une nouvelle issue avec une description détaillée

## 📄 Licence

Ce projet est sous licence [MIT](LICENSE).
