# 📱 GestEcole Mobile

Application Flutter moderne pour la gestion scolaire avec une architecture scalable et une UX exceptionnelle.

## 🎯 Vue d'ensemble

GestEcole Mobile est une application complète de gestion scolaire offrant :
- ✅ Authentification sécurisée
- ✅ Interface moderne et responsive
- ✅ Gestion d'état avec Provider
- ✅ API REST intégrée
- ✅ Stockage local persistant
- ✅ Gestion hors ligne
- ✅ Design system cohérent

## 📚 Documentation

### Pour commencer
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Guide d'installation et de démarrage
- **[USEFUL_COMMANDS.md](USEFUL_COMMANDS.md)** - Commandes Flutter utiles

### Architecture et conception
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architecture détaillée du projet
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Résumé de l'implémentation

## 🚀 Démarrage rapide

### Prérequis
- Flutter SDK 3.9.2+
- Dart SDK 3.9.2+
- Un éditeur de code (VS Code, Android Studio)

### Installation
```bash
# Cloner le projet
git clone <repository-url>
cd gestscolaire

# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run
```

## 🏗️ Structure du projet

```
lib/
├── config/              # Configuration et thème
│   ├── app_config.dart
│   ├── app_theme.dart
│   ├── constants.dart
│   └── routes.dart
├── models/              # Modèles de données
│   └── user_model.dart
├── services/            # Services métier
│   ├── api_service.dart
│   └── auth_service.dart
├── screens/             # Écrans de l'application
│   ├── login_screen.dart
│   └── dashboard_screen.dart
├── providers/           # Gestion d'état
│   └── auth_provider.dart
├── widgets/             # Widgets réutilisables
│   ├── custom_button.dart
│   └── custom_text_field.dart
├── utils/               # Utilitaires
│   ├── validators.dart
│   ├── extensions.dart
│   ├── formatters.dart
│   ├── storage.dart
│   ├── network.dart
│   └── logger.dart
└── main.dart            # Point d'entrée
```

## 🎨 Design System

### Couleurs
- **Primaire**: #2563EB (Bleu)
- **Secondaire**: #10B981 (Vert)
- **Accent**: #F59E0B (Ambre)
- **Erreur**: #EF4444 (Rouge)

### Typographie
- **Font**: Poppins
- **Tailles**: 10px à 32px
- **Poids**: 400 à 700

### Espacement
- **xs**: 4px
- **sm**: 8px
- **md**: 12px
- **lg**: 16px
- **xl**: 20px
- **xxl**: 24px
- **xxxl**: 32px

## 🔐 Authentification

### Flux de connexion
1. Utilisateur entre email et mot de passe
2. Validation des champs
3. Appel API d'authentification
4. Sauvegarde des tokens
5. Redirection vers le dashboard

### Gestion des tokens
- Access Token: Stocké en SharedPreferences
- Refresh Token: Stocké en SharedPreferences
- Expiration: Gérée automatiquement

## 📡 API Service

### Configuration
```dart
final apiService = ApiService();
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
```

## 🧩 Widgets réutilisables

### CustomButton
```dart
CustomButton(
  label: 'Connexion',
  onPressed: () => handleLogin(),
  isLoading: isLoading,
)
```

### CustomTextField
```dart
CustomTextField(
  label: 'Email',
  hint: 'exemple@ecole.com',
  validator: Validators.validateEmail,
)
```

### EmailField
```dart
EmailField(
  controller: emailController,
  validator: Validators.validateEmail,
)
```

### PasswordField
```dart
PasswordField(
  controller: passwordController,
)
```

## 🔧 Utilitaires

### Validateurs
```dart
Validators.validateEmail(email)
Validators.validatePassword(password)
Validators.validatePhone(phone)
Validators.validateName(name)
```

### Formatters
```dart
AppFormatters.formatDate(date)
AppFormatters.formatCurrency(amount)
AppFormatters.formatPhoneNumber(phone)
AppFormatters.getRelativeDate(date)
```

### Extensions
```dart
'email@example.com'.isValidEmail
'2024-01-01'.capitalize
DateTime.now().isToday
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

## 📦 Build

### Android
```bash
flutter build apk --release
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

## 📊 Dépendances principales

```yaml
provider: ^6.0.0              # Gestion d'état
dio: ^5.3.1                   # Requêtes HTTP
shared_preferences: ^2.2.2    # Stockage local
google_fonts: ^6.1.0          # Polices
intl: ^0.19.0                 # Internationalisation
connectivity_plus: ^5.0.0     # Gestion réseau
logger: ^2.0.1                # Logging
```

## 🎯 Fonctionnalités

### Implémentées
- ✅ Authentification (login, register, logout)
- ✅ Gestion d'état avec Provider
- ✅ API REST intégrée
- ✅ Stockage local
- ✅ Validation des formulaires
- ✅ Gestion des erreurs
- ✅ Logging centralisé
- ✅ Design system cohérent

### À venir
- 🔄 Mode hors ligne
- 🔄 Notifications push
- 🔄 Synchronisation des données
- 🔄 Internationalisation (i18n)
- 🔄 Mode sombre
- 🔄 Authentification biométrique

## 🔗 Ressources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Material Design](https://material.io/design)
- [Provider Package](https://pub.dev/packages/provider)
- [Dio Documentation](https://pub.dev/packages/dio)

## 🤝 Contribution

1. Créer une branche (`git checkout -b feature/AmazingFeature`)
2. Commiter vos changements (`git commit -m 'Add AmazingFeature'`)
3. Pousser vers la branche (`git push origin feature/AmazingFeature`)
4. Ouvrir une Pull Request

## 📝 Conventions de code

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

## 📞 Support

Pour toute question ou problème :
1. Consultez la documentation
2. Vérifiez les issues existantes
3. Créez une nouvelle issue avec une description détaillée

## 📄 Licence

Ce projet est sous licence [MIT](LICENSE).

## 👥 Auteurs

- **Équipe GestEcole** - Développement initial

## 🙏 Remerciements

- Flutter et Dart teams
- Communauté Flutter
- Tous les contributeurs

---

**Version**: 1.0.0  
**Statut**: ✅ Prêt pour le développement  
**Dernière mise à jour**: 2024

## 📋 Checklist de démarrage

- [ ] Installer Flutter SDK 3.9.2+
- [ ] Cloner le projet
- [ ] Exécuter `flutter pub get`
- [ ] Configurer l'URL API
- [ ] Exécuter `flutter run`
- [ ] Tester la connexion
- [ ] Lire la documentation

---

**Besoin d'aide?** Consultez [GETTING_STARTED.md](GETTING_STARTED.md) ou [ARCHITECTURE.md](ARCHITECTURE.md)
# gestscolaire_mobile_flutter
