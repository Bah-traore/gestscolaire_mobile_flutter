import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:ui';

import '../config/app_config.dart';

/// Service de cache pour les réponses API
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry> _cache = {};
  final Map<String, Timer> _timers = {};

  void set(String key, dynamic data, {Duration? expiration}) {
    _cache[key] = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      expiration: expiration ?? const Duration(minutes: AppConfig.cacheExpirationMinutes),
    );

    // Configurer le timer d'expiration
    _timers[key]?.cancel();
    _timers[key] = Timer(_cache[key]!.expiration, () {
      _cache.remove(key);
      _timers.remove(key);
    });
  }

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > entry.expiration) {
      _cache.remove(key);
      _timers[key]?.cancel();
      _timers.remove(key);
      return null;
    }

    return entry.data as T?;
  }

  void clear() {
    _cache.clear();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  void remove(String key) {
    _cache.remove(key);
    _timers[key]?.cancel();
    _timers.remove(key);
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final Duration expiration;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.expiration,
  });
}

/// Gestionnaire de requêtes avec optimisations
class RequestManager {
  static final RequestManager _instance = RequestManager._internal();
  factory RequestManager() => _instance;
  RequestManager._internal();

  final Map<String, Completer> _pendingRequests = {};
  final CacheService _cache = CacheService();
  final Logger _logger = Logger();

  /// Exécuter une requête avec cache et déduplication
  Future<T> execute<T>(
    String key,
    Future<T> Function() requestFunction, {
    Duration? cacheExpiration,
    bool forceRefresh = false,
  }) async {
    // Vérifier le cache si pas de force refresh
    if (!forceRefresh) {
      final cached = _cache.get<T>(key);
      if (cached != null) {
        _logger.d('Cache hit for $key');
        return cached;
      }
    }

    // Déduplication des requêtes en cours
    if (_pendingRequests.containsKey(key)) {
      _logger.d('Request deduplication for $key');
      return _pendingRequests[key]!.future as T;
    }

    final completer = Completer<T>();
    _pendingRequests[key] = completer;

    try {
      final result = await requestFunction();
      
      // Mettre en cache le résultat
      _cache.set(key, result, expiration: cacheExpiration);
      
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingRequests.remove(key);
    }
  }

  /// Invalider le cache pour une clé spécifique
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Vider tout le cache
  void clearCache() {
    _cache.clear();
  }
}

/// Interceptor pour le cache et les optimisations
class CacheInterceptor extends Interceptor {
  final RequestManager _requestManager = RequestManager();
  final Logger _logger = Logger();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Ajouter des headers d'optimisation
    options.headers['X-Request-Time'] = DateTime.now().toIso8601String();
    options.headers['X-App-Version'] = AppConfig.appVersion;
    

    _logger.d('Request: ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final duration = response.requestOptions.headers['X-Request-Time'];
    if (duration != null) {
      final requestTime = DateTime.parse(duration as String);
      final responseTime = DateTime.now();
      final totalDuration = responseTime.difference(requestTime);
      _logger.d('Response time for ${response.requestOptions.path}: ${totalDuration.inMilliseconds}ms');
    }

    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    _logger.e('Request failed: ${error.requestOptions.path} - ${error.message}');
    handler.next(error);
  }
}

/// Service pour optimiser les performances réseau
class NetworkOptimizer {
  static final NetworkOptimizer _instance = NetworkOptimizer._internal();
  factory NetworkOptimizer() => _instance;
  NetworkOptimizer._internal();

  final Map<String, List<Future<void>>> _batchedRequests = {};
  final Map<String, Timer> _batchTimers = {};
  static const Duration _batchDelay = Duration(milliseconds: 100);

  /// Ajouter une requête à un batch pour traitement groupé
  Future<T> batchRequest<T>(
    String batchKey,
    Future<T> Function() requestFunction,
  ) {
    final completer = Completer<T>();
    final future = completer.future;

    // Ajouter au batch
    _batchedRequests[batchKey] ??= [];
    _batchedRequests[batchKey]!.add(
      requestFunction().then((result) {
        if (!completer.isCompleted) completer.complete(result);
      }).catchError((error) {
        if (!completer.isCompleted) completer.completeError(error);
      }),
    );

    // Programmer l'exécution du batch
    _batchTimers[batchKey]?.cancel();
    _batchTimers[batchKey] = Timer(_batchDelay, () {
      _executeBatch(batchKey);
    });

    return future;
  }

  Future<void> _executeBatch(String batchKey) async {
    final requests = _batchedRequests[batchKey] ?? [];
    _batchedRequests[batchKey] = [];
    _batchTimers.remove(batchKey);

    if (requests.isEmpty) return;

    try {
      // Exécuter toutes les requêtes du batch en parallèle
      await Future.wait(requests);
    } catch (e) {
      Logger().e('Batch execution failed for $batchKey: $e');
    }
  }

  /// Annuler tous les batches en attente
  void cancelAllBatches() {
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchedRequests.clear();
    _batchTimers.clear();
  }
}

/// Service pour monitorer les performances
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, List<int>> _responseTimes = {};
  final Logger _logger = Logger();

  /// Enregistrer le temps de réponse d'une requête
  void recordResponseTime(String endpoint, int milliseconds) {
    _responseTimes[endpoint] ??= [];
    _responseTimes[endpoint]!.add(milliseconds);

    // Garder seulement les 100 dernières mesures
    if (_responseTimes[endpoint]!.length > 100) {
      _responseTimes[endpoint]!.removeRange(0, _responseTimes[endpoint]!.length - 100);
    }

    // Alerter si les temps sont trop lents
    final avg = _responseTimes[endpoint]!.reduce((a, b) => a + b) / _responseTimes[endpoint]!.length;
    if (avg > 3000) { // 3 secondes
      _logger.w('Slow endpoint detected: $endpoint (avg: ${avg.toStringAsFixed(0)}ms)');
    }
  }

  /// Obtenir les statistiques de performance
  Map<String, Map<String, dynamic>> getPerformanceStats() {
    final stats = <String, Map<String, dynamic>>{};
    
    for (final entry in _responseTimes.entries) {
      final times = entry.value;
      if (times.isEmpty) continue;
      
      times.sort();
      final avg = times.reduce((a, b) => a + b) / times.length;
      final median = times.length % 2 == 0
          ? (times[times.length ~/ 2 - 1] + times[times.length ~/ 2]) / 2
          : times[times.length ~/ 2].toDouble();
      
      stats[entry.key] = {
        'avg': avg,
        'median': median,
        'min': times.first,
        'max': times.last,
        'count': times.length,
      };
    }
    
    return stats;
  }

  /// Réinitialiser les statistiques
  void resetStats() {
    _responseTimes.clear();
  }
}