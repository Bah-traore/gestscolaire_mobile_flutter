# Commandes utiles - GestEcole Mobile

## 🚀 Commandes de base

### Installation et configuration
```bash
# Installer les dépendances
flutter pub get

# Mettre à jour les dépendances
flutter pub upgrade

# Nettoyer le projet
flutter clean

# Vérifier l'environnement
flutter doctor
```

### Exécution
```bash
# Lancer l'application en debug
flutter run

# Lancer en release
flutter run --release

# Lancer sur un appareil spécifique
flutter run -d <device-id>

# Lancer avec hot reload désactivé
flutter run --no-hot

# Lancer avec verbose logging
flutter run -v
```

## 🏗️ Build

### Android
```bash
# Build APK debug
flutter build apk --debug

# Build APK release
flutter build apk --release

# Build App Bundle
flutter build appbundle --release

# Build avec split APKs
flutter build apk --release --split-per-abi
```

### iOS
```bash
# Build iOS debug
flutter build ios --debug

# Build iOS release
flutter build ios --release

# Build pour simulateur
flutter build ios --simulator
```

### Web
```bash
# Build web
flutter build web

# Build web en release
flutter build web --release

# Servir localement
flutter run -d chrome
```

## 🧪 Tests

### Tests unitaires
```bash
# Exécuter tous les tests
flutter test

# Exécuter un test spécifique
flutter test test/path/to/test.dart

# Exécuter avec coverage
flutter test --coverage

# Exécuter avec verbose
flutter test -v
```

### Tests d'intégration
```bash
# Exécuter les tests d'intégration
flutter drive --target=test_driver/app.dart

# Exécuter sur un appareil spécifique
flutter drive -d <device-id> --target=test_driver/app.dart
```

## 📊 Analyse et formatage

### Analyse du code
```bash
# Analyser le code
flutter analyze

# Analyser avec verbose
flutter analyze -v

# Analyser un fichier spécifique
flutter analyze lib/main.dart
```

### Formatage
```bash
# Formater tout le code
dart format lib/

# Formater un fichier spécifique
dart format lib/main.dart

# Vérifier le formatage sans modifier
dart format --output=none lib/

# Formater avec ligne max
dart format --line-length=120 lib/
```

### Linting
```bash
# Exécuter les lints
dart analyze

# Exécuter avec règles personnalisées
dart analyze --fatal-infos
```

## 📦 Gestion des dépendances

### Ajouter une dépendance
```bash
# Ajouter une dépendance
flutter pub add <package-name>

# Ajouter une version spécifique
flutter pub add <package-name>:^1.0.0

# Ajouter une dépendance de développement
flutter pub add --dev <package-name>
```

### Supprimer une dépendance
```bash
flutter pub remove <package-name>
```

### Vérifier les dépendances
```bash
# Vérifier les dépendances obsolètes
flutter pub outdated

# Vérifier les dépendances avec problèmes
flutter pub upgrade --major-versions
```

## 🔧 Génération de code

### Build Runner
```bash
# Générer les fichiers
flutter pub run build_runner build

# Générer en watch mode
flutter pub run build_runner watch

# Nettoyer les fichiers générés
flutter pub run build_runner clean

# Générer et nettoyer
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📱 Gestion des appareils

### Lister les appareils
```bash
# Lister tous les appareils
flutter devices

# Lister avec détails
flutter devices -v
```

### Émuler
```bash
# Lancer l'émulateur Android
flutter emulators

# Lancer un émulateur spécifique
flutter emulators --launch <emulator-id>

# Lancer le simulateur iOS
open -a Simulator
```

## 🐛 Débogage

### Logs
```bash
# Afficher les logs
flutter logs

# Afficher les logs avec verbose
flutter logs -v

# Afficher les logs d'un appareil spécifique
flutter logs -d <device-id>
```

### DevTools
```bash
# Lancer DevTools
flutter pub global activate devtools
devtools

# Lancer avec l'application
flutter run --devtools
```

### Debugger
```bash
# Lancer avec le debugger
flutter run --debug

# Attacher le debugger
flutter attach -d <device-id>
```

## 🔐 Sécurité

### Vérifier les vulnérabilités
```bash
# Vérifier les dépendances vulnérables
flutter pub outdated --dependency-overrides
```

### Obfuscation (Android)
```bash
# Build avec obfuscation
flutter build apk --obfuscate --split-debug-info=./symbols
```

## 🚀 Déploiement

### Préparation
```bash
# Vérifier la version
flutter --version

# Vérifier la configuration
flutter doctor -v

# Nettoyer avant le build
flutter clean && flutter pub get
```

### Build final
```bash
# Build Android complet
flutter build apk --release && flutter build appbundle --release

# Build iOS complet
flutter build ios --release

# Build Web complet
flutter build web --release
```

## 📝 Commandes personnalisées

### Alias utiles (ajouter à ~/.bashrc ou ~/.zshrc)
```bash
# Alias pour les commandes courantes
alias fp='flutter pub'
alias fpa='flutter pub add'
alias fpr='flutter pub remove'
alias fr='flutter run'
alias frr='flutter run --release'
alias fc='flutter clean'
alias fpg='flutter pub get'
alias fpu='flutter pub upgrade'
alias ft='flutter test'
alias fa='flutter analyze'
alias ff='dart format'
alias fd='flutter doctor'
```

## 🎯 Workflow de développement

### Démarrage
```bash
flutter clean
flutter pub get
flutter run
```

### Avant de commiter
```bash
dart format lib/
flutter analyze
flutter test
```

### Avant de déployer
```bash
flutter clean
flutter pub get
flutter test
flutter build apk --release
flutter build appbundle --release
```

## 💡 Tips et astuces

### Hot Reload
```bash
# Hot reload automatique
r - Hot reload
R - Hot restart
q - Quit
```

### Performance
```bash
# Profiler les performances
flutter run --profile

# Tracer les performances
flutter run --trace-startup
```

### Debugging
```bash
# Afficher les widget bounds
flutter run --debug
# Puis appuyer sur 'w' dans la console

# Afficher les repaint areas
# Puis appuyer sur 'p' dans la console
```

## 🔗 Ressources

- [Flutter CLI Documentation](https://flutter.dev/docs/reference/flutter-cli)
- [Dart CLI Documentation](https://dart.dev/tools/dart-tool)
- [DevTools Documentation](https://flutter.dev/docs/development/tools/devtools)

---

**Mise à jour**: 2024
**Version**: 1.0.0
