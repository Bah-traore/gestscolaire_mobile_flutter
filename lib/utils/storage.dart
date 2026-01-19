import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service de stockage local
class StorageService {
  static late SharedPreferences _prefs;
  
  /// Initialiser le service
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Sauvegarder une chaîne
  static Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }
  
  /// Obtenir une chaîne
  static String? getString(String key) {
    return _prefs.getString(key);
  }
  
  /// Sauvegarder un entier
  static Future<bool> setInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }
  
  /// Obtenir un entier
  static int? getInt(String key) {
    return _prefs.getInt(key);
  }
  
  /// Sauvegarder un booléen
  static Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }
  
  /// Obtenir un booléen
  static bool? getBool(String key) {
    return _prefs.getBool(key);
  }
  
  /// Sauvegarder un double
  static Future<bool> setDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }
  
  /// Obtenir un double
  static double? getDouble(String key) {
    return _prefs.getDouble(key);
  }
  
  /// Sauvegarder une liste de chaînes
  static Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs.setStringList(key, value);
  }
  
  /// Obtenir une liste de chaînes
  static List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }
  
  /// Sauvegarder un objet JSON
  static Future<bool> setJson(String key, Map<String, dynamic> value) async {
    return await _prefs.setString(key, jsonEncode(value));
  }
  
  /// Obtenir un objet JSON
  static Map<String, dynamic>? getJson(String key) {
    final json = _prefs.getString(key);
    if (json == null) return null;
    
    try {
      return jsonDecode(json);
    } catch (e) {
      return null;
    }
  }
  
  /// Sauvegarder une liste d'objets JSON
  static Future<bool> setJsonList(String key, List<Map<String, dynamic>> value) async {
    return await _prefs.setString(key, jsonEncode(value));
  }
  
  /// Obtenir une liste d'objets JSON
  static List<Map<String, dynamic>>? getJsonList(String key) {
    final json = _prefs.getString(key);
    if (json == null) return null;
    
    try {
      final list = jsonDecode(json) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }
  
  /// Vérifier si une clé existe
  static bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
  
  /// Supprimer une clé
  static Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }
  
  /// Supprimer toutes les données
  static Future<bool> clear() async {
    return await _prefs.clear();
  }
  
  /// Obtenir toutes les clés
  static Set<String> getAllKeys() {
    return _prefs.getKeys();
  }
  
  /// Obtenir la taille du stockage
  static int getStorageSize() {
    int size = 0;
    for (String key in _prefs.getKeys()) {
      final value = _prefs.get(key);
      if (value is String) {
        size += value.length;
      } else if (value is List) {
        size += value.length;
      }
    }
    return size;
  }
}

/// Service de cache
class CacheService {
  static final Map<String, CacheEntry> _cache = {};
  
  /// Sauvegarder une valeur en cache
  static void set<T>(
    String key,
    T value, {
    Duration? expiration,
  }) {
    _cache[key] = CacheEntry(
      value: value,
      expiresAt: expiration != null
          ? DateTime.now().add(expiration)
          : null,
    );
  }
  
  /// Obtenir une valeur du cache
  static T? get<T>(String key) {
    final entry = _cache[key];
    
    if (entry == null) return null;
    
    // Vérifier si le cache a expiré
    if (entry.expiresAt != null && entry.expiresAt!.isBefore(DateTime.now())) {
      _cache.remove(key);
      return null;
    }
    
    return entry.value as T?;
  }
  
  /// Vérifier si une clé existe en cache
  static bool containsKey(String key) {
    return _cache.containsKey(key);
  }
  
  /// Supprimer une clé du cache
  static void remove(String key) {
    _cache.remove(key);
  }
  
  /// Vider le cache
  static void clear() {
    _cache.clear();
  }
  
  /// Nettoyer les entrées expirées
  static void cleanup() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) {
      return entry.expiresAt != null && entry.expiresAt!.isBefore(now);
    });
  }
}

/// Classe pour les entrées de cache
class CacheEntry {
  final dynamic value;
  final DateTime? expiresAt;
  
  CacheEntry({
    required this.value,
    this.expiresAt,
  });
}
