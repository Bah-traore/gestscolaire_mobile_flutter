import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../widgets/update_notification_banner.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateChecker {
  static GlobalKey<NavigatorState> get navigatorKey => MyApp.navigatorKey;
  static const String _pendingUpdateKey = 'pending_update_info';
  static const String _updateCheckInitializedKey = 'update_check_initialized';

  /// Initialise le vérificateur de mises à jour
  static Future<void> initialize() async {
    print('[UPDATE_CHECKER] Initialisation...');
    final updateService = UpdateService();
    await updateService.init();

    // Attendre que l'app soit complètement construite
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[UPDATE_CHECKER] App construite, démarrage vérification...');

      // Vérifier si une mise à jour est en attente
      _checkPendingUpdate();

      // Vérifier si c'est la première fois
      _checkFirstTimeAndRun();

      // Vérifier périodiquement (toutes les 6 heures)
      _schedulePeriodicChecks();
    });
  }

  /// Vérifie si une mise à jour est en attente et l'affiche
  static Future<void> _checkPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingUpdateJson = prefs.getString(_pendingUpdateKey);

    if (pendingUpdateJson != null) {
      print('[UPDATE_CHECKER] Mise à jour en attente trouvée');
      try {
        final updateInfo = UpdateInfo.fromJsonString(pendingUpdateJson);
        // Afficher la bannière pour la mise à jour en attente (après 3 secondes)
        Future.delayed(const Duration(seconds: 3), () {
          _showUpdateNotification(updateInfo);
        });
      } catch (e) {
        print(
          '[UPDATE_CHECKER] Erreur lors de la lecture de la mise à jour en attente: $e',
        );
        await prefs.remove(_pendingUpdateKey);
      }
    }
  }

  /// Sauvegarde une mise à jour comme en attente
  static Future<void> _savePendingUpdate(UpdateInfo updateInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingUpdateKey, updateInfo.toJsonString());
    print('[UPDATE_CHECKER] Mise à jour sauvegardée comme en attente');
  }

  /// Efface la mise à jour en attente (appelé après installation réussie)
  static Future<void> clearPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingUpdateKey);
    print('[UPDATE_CHECKER] Mise à jour en attente effacée');
  }

  static Future<void> _checkFirstTimeAndRun() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCheckedBefore = prefs.getBool(_updateCheckInitializedKey) ?? false;

    if (!hasCheckedBefore) {
      print('[UPDATE_CHECKER] Premier démarrage - vérification forcée');
      await prefs.setBool(_updateCheckInitializedKey, true);
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
      print('[UPDATE_CHECKER] Mise à jour trouvée, sauvegarde et affichage...');
      // Sauvegarder la mise à jour comme en attente
      await _savePendingUpdate(updateInfo);
      _showUpdateNotification(updateInfo, isPending: false);
    } else {
      print('[UPDATE_CHECKER] Aucune mise à jour trouvée');
    }
  }

  static void _schedulePeriodicChecks() {
    Stream.periodic(const Duration(hours: 6), (_) async {
      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdates();

      if (updateInfo != null) {
        _showUpdateNotification(updateInfo, isPending: false);
      }
    }).listen((_) {});
  }

  /// Affiche une notification bannière animée pour la mise à jour
  static void _showUpdateNotification(
    UpdateInfo updateInfo, {
    bool isPending = false,
  }) {
    print(
      '[UPDATE_CHECKER] Tentative affichage notification... (pending: $isPending)',
    );

    // Attendre que le navigator soit prêt avec retry
    _showNotificationWithRetry(updateInfo, attempts: 0, isPending: isPending);
  }

  static void _showNotificationWithRetry(
    UpdateInfo updateInfo, {
    required int attempts,
    bool isPending = false,
  }) {
    if (attempts > 10) {
      print(
        '[UPDATE_CHECKER] Échec après 10 tentatives - navigator pas disponible',
      );
      return;
    }

    final context = navigatorKey.currentContext;

    if (context == null) {
      print(
        '[UPDATE_CHECKER] Contexte null, retry dans 500ms (tentative ${attempts + 1})',
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        _showNotificationWithRetry(
          updateInfo,
          attempts: attempts + 1,
          isPending: isPending,
        );
      });
      return;
    }

    print('[UPDATE_CHECKER] Contexte trouvé, affichage notification');

    // Si mise à jour obligatoire, afficher directement le dialog
    if (updateInfo.isMandatory) {
      _showUpdateDialog(updateInfo);
      return;
    }

    // Afficher la bannière animée pour les mises à jour optionnelles
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.topCenter,
        child: UpdateNotificationBanner(
          updateInfo: updateInfo,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Affiche le dialog de mise à jour (pour les mises à jour obligatoires)
  static void _showUpdateDialog(UpdateInfo updateInfo) {
    print('[UPDATE_CHECKER] Affichage dialog obligatoire...');
    _showDialogWithRetry(updateInfo, attempts: 0);
  }

  static void _showDialogWithRetry(
    UpdateInfo updateInfo, {
    required int attempts,
  }) {
    if (attempts > 10) {
      print(
        '[UPDATE_CHECKER] Échec après 10 tentatives - navigator pas disponible',
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

    print('[UPDATE_CHECKER] Contexte trouvé, affichage du dialogue');

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
      _showUpdateNotification(updateInfo);
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
        _showUpdateNotification(updateInfo);
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
      // Afficher la notification si possible
      _showUpdateNotification(updateInfo, isPending: false);
    } else {
      print(' No update available');
    }
    print('=== END TEST ===');
  }
}
