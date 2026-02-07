import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateChecker {
  static GlobalKey<NavigatorState> get navigatorKey => MyApp.navigatorKey;

  /// Initialise le vérificateur de mises à jour
  static Future<void> initialize() async {
    print('[UPDATE_CHECKER] Initialisation...');
    final updateService = UpdateService();
    await updateService.init();

    // Attendre que l'app soit complètement construite
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[UPDATE_CHECKER] App construite, démarrage vérification...');

      // Vérifier si c'est la première fois
      _checkFirstTimeAndRun();

      // Vérifier périodiquement (toutes les 6 heures)
      _schedulePeriodicChecks();
    });
  }

  static Future<void> _checkFirstTimeAndRun() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCheckedBefore = prefs.getBool('update_check_initialized') ?? false;

    if (!hasCheckedBefore) {
      print('[UPDATE_CHECKER] Premier démarrage - vérification forcée');
      await prefs.setBool('update_check_initialized', true);
      // Vérifier immédiatement avec forceCheck
      await _checkForUpdatesOnStartup(forceCheck: true);
    } else {
      // Vérifier normalement
      _checkForUpdatesOnStartup();
    }
  }

  static Future<void> _checkForUpdatesOnStartup({
    bool forceCheck = false,
  }) async {
    // Attendre que l'interface soit prête
    await Future.delayed(const Duration(seconds: 2));

    print(
      '[UPDATE_CHECKER] Vérification au démarrage (forceCheck: $forceCheck)...',
    );

    final updateService = UpdateService();
    final updateInfo = await updateService.checkForUpdates(
      forceCheck: forceCheck,
    );

    if (updateInfo != null) {
      print('[UPDATE_CHECKER] Mise à jour trouvée, affichage du dialogue...');
      _showUpdateDialog(updateInfo);
    } else {
      print('[UPDATE_CHECKER] Aucune mise à jour trouvée');
    }
  }

  static void _schedulePeriodicChecks() {
    Stream.periodic(const Duration(hours: 6), (_) async {
      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdates();

      if (updateInfo != null) {
        _showUpdateDialog(updateInfo);
      }
    }).listen((_) {});
  }

  static void _showUpdateDialog(UpdateInfo updateInfo) {
    print('[UPDATE_CHECKER] Tentative affichage dialogue...');

    // Attendre que le navigator soit prêt avec retry
    _showDialogWithRetry(updateInfo, attempts: 0);
  }

  static void _showDialogWithRetry(
    UpdateInfo updateInfo, {
    required int attempts,
  }) {
    if (attempts > 10) {
      print(
        '[UPDATE_CHECKER]  Échec après 10 tentatives - navigator pas disponible',
      );
      return;
    }

    final context = navigatorKey.currentContext;

    if (context == null) {
      print(
        '[UPDATE_CHECKER] Contexte null, retry dans 500ms (tentative ${attempts + 1})',
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        _showDialogWithRetry(updateInfo, attempts: attempts + 1);
      });
      return;
    }

    print('[UPDATE_CHECKER]  Contexte trouvé, affichage du dialogue');

    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (context) => UpdateDialog(
        updateInfo: updateInfo,
        onUpdate: () {
          Navigator.of(context).pop();
          // L'application va redémarrer après l'installation
        },
        onLater: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Affiche le dialogue de mise à jour depuis une notification FCM
  static void showUpdateDialogFromNotification(UpdateInfo updateInfo) {
    // Attendre que le navigator soit prêt
    Future.delayed(const Duration(milliseconds: 500), () {
      _showUpdateDialog(updateInfo);
    });
  }

  /// Vérification manuelle des mises à jour
  static Future<bool> checkForUpdatesManually(BuildContext context) async {
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Vérification des mises à jour...'),
            ],
          ),
        ),
      );

      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdates(forceCheck: true);

      // Fermer le dialogue de chargement
      Navigator.of(context).pop();

      if (updateInfo != null) {
        _showUpdateDialog(updateInfo);
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre application est à jour'),
            backgroundColor: Colors.green,
          ),
        );
        return false;
      }
    } catch (e) {
      // Fermer le dialogue de chargement s'il est ouvert
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la vérification: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  /// Méthode de test - affiche les logs dans la console
  static Future<void> testUpdateCheck() async {
    print('=== TEST UPDATE CHECK ===');
    final updateService = UpdateService();
    await updateService.init();

    print('Forcing update check...');
    final updateInfo = await updateService.checkForUpdates(forceCheck: true);

    if (updateInfo != null) {
      print(' Update found: v${updateInfo.version}');
      // Afficher le dialogue si possible
      _showUpdateDialog(updateInfo);
    } else {
      print(' No update available');
    }
    print('=== END TEST ===');
  }
}
