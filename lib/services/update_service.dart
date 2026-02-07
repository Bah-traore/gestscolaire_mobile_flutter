import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateService {
  static const String _updateUrl =
      'https://apps.gestscolaire.com/superadmin/api/version-check/';
  static const String _apkDownloadUrl =
      'https://apps.gestscolaire.com/superadmin/api/download-apk/';
  static const String _updatePreferenceKey = 'last_update_check';

  final Dio _dio = Dio();
  late SharedPreferences _prefs;

  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Vérifie s'il y a une mise à jour disponible
  Future<UpdateInfo?> checkForUpdates({bool forceCheck = false}) async {
    try {
      print('[UPDATE_CHECK] Début vérification (forceCheck: $forceCheck)');

      // Vérifier si on a déjà vérifié récemment (sauf si forceCheck)
      if (!forceCheck) {
        final lastCheck = _prefs.getInt(_updatePreferenceKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final diff = now - lastCheck;
        final hoursSinceLastCheck = diff / (1000 * 60 * 60);

        print(
          '[UPDATE_CHECK] Dernière vérif: ${hoursSinceLastCheck.toStringAsFixed(1)}h ago',
        );

        if (diff < 24 * 60 * 60 * 1000) {
          print('[UPDATE_CHECK] Ignoré - dernière vérif < 24h');
          return null;
        }
      }

      // Obtenir la version actuelle de l'app
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      print(
        '[UPDATE_CHECK] Version actuelle: $currentVersion (build: $currentBuildNumber)',
      );

      // Vérifier la connectivité
      final connectivity = await Connectivity().checkConnectivity();
      print('[UPDATE_CHECK] Connectivité: $connectivity');

      if (connectivity == ConnectivityResult.none) {
        print('[UPDATE_CHECK] Pas de connexion - abandon');
        return null;
      }

      // Appeler l'API pour vérifier les mises à jour
      print('[UPDATE_CHECK] Appel API: $_updateUrl');
      final response = await _dio.get(
        _updateUrl,
        queryParameters: {
          'current_version': currentVersion,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'build_number': currentBuildNumber,
        },
      );

      print('[UPDATE_CHECK] Réponse API: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        print('[UPDATE_CHECK] Données: $data');

        if (data['update_available'] == true) {
          print('[UPDATE_CHECK]  Mise à jour disponible trouvée!');
          final updateInfo = UpdateInfo(
            version: data['latest_version'] ?? '',
            buildNumber: data['latest_build_number'] ?? 0,
            downloadUrl: data['download_url'] ?? _apkDownloadUrl,
            releaseNotes: data['release_notes'] ?? '',
            isMandatory: data['is_mandatory'] ?? false,
            size: data['size'] ?? 0,
          );
          print(
            '[UPDATE_CHECK] UpdateInfo: v${updateInfo.version}, mandatory: ${updateInfo.isMandatory}',
          );

          // Sauvegarder la date de dernière vérification
          await _prefs.setInt(
            _updatePreferenceKey,
            DateTime.now().millisecondsSinceEpoch,
          );

          return updateInfo;
        } else {
          print('[UPDATE_CHECK]  Pas de mise à jour disponible');
        }
      } else {
        print('[UPDATE_CHECK]  Erreur API: ${response.statusCode}');
      }

      // Sauvegarder la date de dernière vérification même si pas de mise à jour
      await _prefs.setInt(
        _updatePreferenceKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      return null;
    } catch (e, stackTrace) {
      print('[UPDATE_CHECK]  Erreur: $e');
      print('[UPDATE_CHECK] Stack: $stackTrace');
      return null;
    }
  }

  /// Télécharge l'APK de manière persistante dans les fichiers de l'application
  Future<String?> downloadUpdate(
    UpdateInfo updateInfo, {
    Function(double)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      print('Les mises à jour automatiques ne sont supportées que sur Android');
      return null;
    }

    try {
      // Utiliser le répertoire de documents de l'application (persistant)
      final directory = await getApplicationDocumentsDirectory();

      // Créer un sous-répertoire dédié aux mises à jour
      final updatesDir = Directory('${directory.path}/updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      final fileName = 'gestscolaire_v${updateInfo.version}.apk';
      final filePath = '${updatesDir.path}/$fileName';

      // Nettoyer les anciennes versions (garder seulement les 2 dernières)
      await _cleanupOldVersions(updatesDir, keepLatest: 2);

      // Vérifier si le fichier existe déjà (déjà téléchargé)
      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 0) {
          print(
            'APK déjà présent: $filePath (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
          );
          return filePath;
        }
      }

      // Télécharger le fichier avec progression
      await _dio.download(
        updateInfo.downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // Vérifier que le fichier existe et a une taille correcte
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 0) {
          print(
            'APK téléchargé avec succès: $filePath (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
          );
          return filePath;
        } else {
          throw Exception('Le fichier téléchargé est vide');
        }
      } else {
        throw Exception('Le fichier téléchargé n\'existe pas');
      }
    } catch (e) {
      print('Erreur lors du téléchargement: $e');
      return null;
    }
  }

  /// Installe l'APK téléchargé en utilisant open_filex
  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      print('Installation automatique non supportée sur cette plateforme');
      return false;
    }

    try {
      print('[UPDATE_INSTALL] Tentative d\'installation: $filePath');

      // Utiliser open_filex pour ouvrir l'APK
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      print('[UPDATE_INSTALL] Résultat: ${result.message}');

      if (result.type == ResultType.done) {
        print('[UPDATE_INSTALL] Installateur lancé avec succès');
        return true;
      } else {
        print('[UPDATE_INSTALL] Erreur: ${result.message}');
        return false;
      }
    } catch (e) {
      print('[UPDATE_INSTALL] Erreur lors de l\'installation: $e');
      return false;
    }
  }

  /// Télécharge et installe l'APK
  Future<bool> downloadAndInstall(
    UpdateInfo updateInfo, {
    Function(double)? onProgress,
    Function(String)? onStatus,
  }) async {
    onStatus?.call('Téléchargement en cours...');

    final filePath = await downloadUpdate(updateInfo, onProgress: onProgress);

    if (filePath == null) {
      onStatus?.call('Échec du téléchargement');
      return false;
    }

    onStatus?.call('Installation en cours...');
    final installed = await installApk(filePath);

    if (installed) {
      onStatus?.call('Installation lancée');
    } else {
      onStatus?.call('Impossible de lancer l\'installation automatique');
    }

    return installed;
  }

  Future<void> _cleanupOldVersions(
    Directory updatesDir, {
    int keepLatest = 2,
  }) async {
    try {
      final files = await updatesDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.apk'))
          .toList();

      // Trier par date de modification (plus récent en premier)
      files.sort(
        (a, b) => (b as File).lastModifiedSync().compareTo(
          (a as File).lastModifiedSync(),
        ),
      );

      // Supprimer les anciennes versions
      if (files.length > keepLatest) {
        for (var i = keepLatest; i < files.length; i++) {
          await (files[i] as File).delete();
          print('Ancienne version supprimée: ${files[i].path}');
        }
      }
    } catch (e) {
      print('Erreur lors du nettoyage des anciennes versions: $e');
    }
  }

  /// Notifie l'utilisateur d'une mise à jour disponible
  Future<void> showUpdateNotification(UpdateInfo updateInfo) async {
    // TODO: Implémenter avec flutter_local_notifications si nécessaire
    // Pour l'instant, la notification sera gérée par le dialogue
    print('Nouvelle mise à jour disponible: ${updateInfo.version}');
  }
}

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;
  final int size; // taille en bytes

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isMandatory,
    required this.size,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Convertit en Map JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'buildNumber': buildNumber,
      'downloadUrl': downloadUrl,
      'releaseNotes': releaseNotes,
      'isMandatory': isMandatory,
      'size': size,
    };
  }

  /// Convertit en String JSON
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Crée depuis un Map JSON
  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '',
      buildNumber: json['buildNumber'] ?? 0,
      downloadUrl: json['downloadUrl'] ?? '',
      releaseNotes: json['releaseNotes'] ?? '',
      isMandatory: json['isMandatory'] ?? false,
      size: json['size'] ?? 0,
    );
  }

  /// Crée depuis une String JSON
  factory UpdateInfo.fromJsonString(String jsonString) {
    return UpdateInfo.fromJson(jsonDecode(jsonString));
  }
}
