# 🚀 Démarrage rapide - GestEcole Mobile

## ⚡ 5 minutes pour commencer

### 1️⃣ Installation (1 min)
```bash
cd gestscolaire
flutter pub get
```

### 2️⃣ Configuration (1 min)
Éditer `lib/config/app_config.dart`:
```dart
static const String apiBaseUrl = 'https://votre-api.com/api';
```

### 3️⃣ Lancer l'app (1 min)
```bash
flutter run
```

### 4️⃣ Tester la connexion (1 min)
- Email: `test@example.com`
- Mot de passe: `password123`

### 5️⃣ Explorer le code (1 min)
- Ouvrir `lib/main.dart`
- Consulter `ARCHITECTURE.md`

## 📱 Structure rapide

```
lib/
├── config/          👈 Configuration
├── models/          👈 Données
├── services/        👈 API
├── screens/         👈 Écrans
├── providers/       👈 État
├── widgets/         👈 Composants
├── utils/           👈 Outils
└── main.dart        👈 Démarrage
```

## 🎯 Commandes essentielles

```bash
# Lancer
flutter run

# Tester
flutter test

# Analyser
flutter analyze

# Formater
dart format lib/

# Build
flutter build apk --release
```

## 🔐 Authentification

### Flux de connexion
1. Utilisateur entre email/mot de passe
2. `AuthProvider.login()` appelé
3. Token sauvegardé
4. Redirection vers dashboard

### Fichiers clés
- `lib/services/auth_service.dart` - Logique
- `lib/providers/auth_provider.dart` - État
- `lib/screens/login_screen.dart` - UI

## 🎨 Design System

### Couleurs
```dart
AppTheme.primaryColor      // #2563EB (Bleu)
AppTheme.secondaryColor    // #10B981 (Vert)
AppTheme.accentColor       // #F59E0B (Ambre)
AppTheme.errorColor        // #EF4444 (Rouge)
```

### Espacement
```dart
AppTheme.xs   // 4px
AppTheme.sm   // 8px
AppTheme.md   // 12px
AppTheme.lg   // 16px
AppTheme.xl   // 20px
```

## 🧩 Widgets courants

### Bouton
```dart
CustomButton(
  label: 'Connexion',
  onPressed: () => handleLogin(),
  isLoading: isLoading,
)
```

### Champ email
```dart
EmailField(
  controller: emailController,
)
```

### Champ mot de passe
```dart
PasswordField(
  controller: passwordController,
)
```

## 📡 API Service

### GET
```dart
final data = await apiService.get<Map>('/endpoint');
```

### POST
```dart
final response = await apiService.post<Map>(
  '/endpoint',
  data: {'key': 'value'},
);
```

## 🔧 Utilitaires

### Validateurs
```dart
Validators.validateEmail(email)
Validators.validatePassword(password)
Validators.validatePhone(phone)
```

### Formatters
```dart
AppFormatters.formatDate(date)
AppFormatters.formatCurrency(amount)
AppFormatters.formatPhoneNumber(phone)
```

### Extensions
```dart
'email@example.com'.isValidEmail
'text'.capitalize
DateTime.now().isToday
```

## 📚 Documentation

| Document | Contenu |
|----------|---------|
| [README.md](README.md) | Vue d'ensemble |
| [GETTING_STARTED.md](GETTING_STARTED.md) | Installation détaillée |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Architecture complète |
| [USEFUL_COMMANDS.md](USEFUL_COMMANDS.md) | Commandes utiles |

## 🐛 Dépannage rapide

### Erreur: "Flutter SDK not found"
```bash
flutter doctor
flutter pub get
```

### Erreur: "Build failed"
```bash
flutter clean
flutter pub get
flutter run
```

### Erreur: "Port already in use"
```bash
flutter run -d <device-id>
```

## 🎯 Prochaines étapes

1. **Lire** `ARCHITECTURE.md` pour comprendre la structure
2. **Explorer** le code dans `lib/`
3. **Tester** les fonctionnalités
4. **Ajouter** vos propres écrans
5. **Déployer** sur les stores

## 💡 Tips

- Utilisez `flutter run` avec hot reload
- Consultez les logs avec `flutter logs`
- Utilisez DevTools avec `flutter pub global activate devtools`
- Formatez le code avec `dart format lib/`
- Analysez avec `flutter analyze`

## 🔗 Ressources

- [Flutter Docs](https://flutter.dev/docs)
- [Dart Docs](https://dart.dev/guides)
- [Material Design](https://material.io/design)

## ✅ Checklist

- [ ] Flutter SDK installé
- [ ] Dépendances téléchargées (`flutter pub get`)
- [ ] API configurée
- [ ] Application lancée
- [ ] Connexion testée
- [ ] Code exploré

## 🎉 Prêt!

Vous êtes maintenant prêt à développer avec GestEcole Mobile!

---

**Besoin d'aide?** Consultez [GETTING_STARTED.md](GETTING_STARTED.md)
