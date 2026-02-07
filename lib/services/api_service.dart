import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'dart:io';
import 'auth_service.dart';
import '../config/app_config.dart';
import 'performance_service.dart';

/// Service API centralisé avec optimisations de performance
class ApiService {
  late Dio _dio;
  final Logger _logger = Logger();
  String? _authToken;

  AuthService? _authService;
  bool _refreshing = false;

  // Services d'optimisation
  final RequestManager _requestManager = RequestManager();
  final NetworkOptimizer _networkOptimizer = NetworkOptimizer();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final CacheService _cache = CacheService();

  // Contrôleur pour annuler les requêtes
  final CancelToken _cancelToken = CancelToken();

  ApiService() {
    _initializeDio();
  }

  void attachAuthService(AuthService authService) {
    _authService = authService;
  }

  /// Initialiser Dio avec les configurations et optimisations
  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectionTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        // Timeout plus court pour meilleure expérience utilisateur
        sendTimeout: const Duration(seconds: 45),
        contentType: 'application/json',
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'GestScolaire Mobile/1.0',
          'Connection': 'keep-alive',
        },
        // Activer la validation pour éviter les requêtes inutiles
        validateStatus: (status) => status != null && status < 500,
        // Utiliser plain pour éviter les erreurs de parsing automatique
        responseType: ResponseType.plain,
      ),
    );

    // Ajouter les interceptors
    _dio.interceptors.add(CacheInterceptor());
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // Configurer l'adaptateur HTTP pour optimiser les performances
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 30);
      client.connectionTimeout = const Duration(seconds: 30);
      return client;
    };
  }

  /// Callback pour les requêtes
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_authToken != null) {
      options.headers['Authorization'] = 'Bearer $_authToken';
    }

    if (AppConfig.enableDebugLogging) {
      _logger.d('REQUEST: ${options.method} ${options.path}');
      _logger.d('Headers: ${options.headers}');
      if (options.data != null) {
        _logger.d('Body: ${options.data}');
      }
    }

    return handler.next(options);
  }

  /// Callback pour les réponses avec monitoring et validation
  Future<void> _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final requestTime = response.requestOptions.headers['X-Request-Time'];
    if (requestTime != null) {
      final startTime = DateTime.parse(requestTime as String);
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      // Enregistrer les performances
      _performanceMonitor.recordResponseTime(
        response.requestOptions.path,
        duration,
      );

      if (AppConfig.enableDebugLogging) {
        _logger.d(
          'RESPONSE: ${response.statusCode} ${response.requestOptions.path} (${duration}ms)',
        );
      }
    } else if (AppConfig.enableDebugLogging) {
      _logger.d(
        'RESPONSE: ${response.statusCode} ${response.requestOptions.path}',
      );
    }

    if (AppConfig.enableDebugLogging) {
      _logger.d('Data: ${response.data}');
    }

    // Vérifier les erreurs métier TOKEN_EXPIRED - essayer refresh automatique
    try {
      final data = _validateAndParseResponse(response);
      if (data is Map &&
          data['success'] == false &&
          data['code'] == 'TOKEN_EXPIRED') {
        _logger.w(' TOKEN_EXPIRED détecté - tentative de refresh automatique');

        // Essayer de rafraîchir le token silencieusement
        if (_authService != null && !_refreshing) {
          _refreshing = true;
          try {
            final refreshed = await _authService!.refreshAccessToken();
            if (refreshed) {
              _logger.i(' Token rafraîchi avec succès - session maintenue');
              // Retenter la requête avec le nouveau token
              final newToken = _authService!.token;
              if (newToken != null && newToken.isNotEmpty) {
                setAuthToken(newToken);
                // Créer une copie des options pour modification
                final retryOptions = response.requestOptions.copyWith(
                  headers: Map<String, dynamic>.from(
                    response.requestOptions.headers,
                  )..['Authorization'] = 'Bearer $newToken',
                );
                final retryResponse = await _dio.fetch(retryOptions);
                return handler.resolve(retryResponse);
              }
            }
          } catch (refreshError) {
            _logger.e(' Échec du refresh: $refreshError');
          } finally {
            _refreshing = false;
          }
        }

        // Si refresh échoue ou pas de authService, on garde la session
        // et on laisse l'app gérer l'erreur normalement
        _logger.w(' Impossible de rafraîchir, mais session conservée');
      }
    } catch (e) {
      // Ignorer les erreurs de parsing ici
    }

    return handler.next(response);
  }

  /// Callback pour les erreurs avec gestion améliorée
  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final status = error.response?.statusCode;
    final requestOptions = error.requestOptions;
    final alreadyRetried = requestOptions.extra['retried'] == true;

    if (AppConfig.enableDebugLogging) {
      _logger.e(' Request failed: ${requestOptions.path} - ${error.message}');
      _logger.e(' ERROR: ${error.error}');
      _logger.e(' Status Code: $status');
      _logger.e(' Response: ${error.response?.data}');
    }

    // Gérer les erreurs de formatage JSON
    if (error.error is FormatException) {
      _logger.e('⛠️ JSON Format Error: ${error.error}');

      // Créer une erreur plus descriptive
      final customError = DioException(
        requestOptions: requestOptions,
        error: 'Invalid response format from server',
        message: 'Server returned invalid JSON format',
        type: DioExceptionType.unknown,
      );

      return handler.next(customError);
    }

    // Gérer les erreurs de réseau et timeout
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      _logger.w(' Timeout: ${error.type} for ${requestOptions.path}');

      final timeoutError = DioException(
        requestOptions: requestOptions,
        error: error.error,
        message: 'Request timeout - please check your connection',
        type: error.type,
      );

      return handler.next(timeoutError);
    }

    // Gérer les erreurs de connexion réseau
    if (error.type == DioExceptionType.connectionError) {
      _logger.w(' Connection Error: ${error.message}');

      final connectionError = DioException(
        requestOptions: requestOptions,
        error: error.error,
        message: 'Network connection error - please check your internet',
        type: error.type,
      );

      return handler.next(connectionError);
    }

    final bool isRefreshEndpoint = requestOptions.path.contains(
      '/auth/refresh',
    );

    // Gérer le cas où le refresh token est aussi expiré - ne pas déconnecter automatiquement
    if (status == 401 && isRefreshEndpoint) {
      _logger.w(
        ' Refresh token expiré, mais session conservée (pas de déconnexion auto)',
      );
      // Ne pas déconnecter automatiquement - laisser l'utilisateur connecté
      return handler.next(error);
    }

    // Si après tentative de refresh on a toujours 401, ne pas déconnecter auto
    if (status == 401 && alreadyRetried) {
      _logger.w(
        ' Refresh échoué, mais session conservée (pas de déconnexion auto)',
      );
      return handler.next(error);
    }

    // Tenter de rafraîchir le token pour les erreurs 401
    final shouldAttemptRefresh =
        status == 401 &&
        _authToken != null &&
        _authService != null &&
        !isRefreshEndpoint;

    if (shouldAttemptRefresh &&
        !alreadyRetried &&
        _authService != null &&
        !_refreshing) {
      _refreshing = true;

      try {
        final refreshed = await _authService!.refreshAccessToken();
        if (refreshed) {
          // retry same request
          requestOptions.extra['retried'] = true;
          final newToken = _authService!.token;
          if (newToken != null && newToken.isNotEmpty) {
            setAuthToken(newToken);
            requestOptions.headers['Authorization'] = 'Bearer $newToken';
          }

          final response = await _dio.fetch(requestOptions);
          return handler.resolve(response);
        } else {
          // Le refresh a échoué, mais on garde la session active
          _logger.w(
            ' Refresh échoué, session conservée (pas de déconnexion auto)',
          );
        }
      } catch (_) {
        // Erreur lors du refresh, mais on garde la session active
        _logger.w(
          ' Erreur refresh, session conservée (pas de déconnexion auto)',
        );
      } finally {
        _refreshing = false;
      }
    }

    return handler.next(error);
  }

  /// Définir le token d'authentification
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Effacer le token d'authentification
  void clearAuthToken() {
    _authToken = null;
  }

  /// Requête GET optimisée avec cache et retry
  Future<T> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Duration? cacheExpiration,
    bool forceRefresh = false,
    int maxRetries = 2,
  }) async {
    final cacheKey = 'GET:$endpoint:${queryParameters?.toString() ?? ''}';

    return _requestManager.execute(
      cacheKey,
      () async {
        return _executeGetWithRetry<T>(
          endpoint,
          queryParameters,
          fromJson,
          maxRetries,
        );
      },
      cacheExpiration: cacheExpiration,
      forceRefresh: forceRefresh,
    );
  }

  /// Exécuter GET avec retry automatique en cas d'erreur de formatage
  Future<T> _executeGetWithRetry<T>(
    String endpoint,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    int maxRetries,
  ) async {
    int attempts = 0;

    while (attempts <= maxRetries) {
      try {
        final startTime = DateTime.now();

        // Utiliser responseType.plain pour éviter le parsing automatique
        var response = await _dio.get(
          endpoint,
          queryParameters: queryParameters,
          cancelToken: _cancelToken,
        );

        // Valider et parser la réponse
        final validatedData = _validateAndParseResponse(response);

        if (fromJson != null) {
          return fromJson(validatedData);
        }

        return validatedData as T;
      } catch (e) {
        attempts++;

        // Si c'est une erreur de formatage et qu'on peut réessayer
        if (e is DioException &&
            e.error is FormatException &&
            attempts <= maxRetries) {
          _logger.w(
            ' Retry $attempts/$maxRetries for $endpoint due to format error',
          );

          // Attendre un peu avant de réessayer
          await Future.delayed(Duration(milliseconds: 500 * attempts));
          continue;
        }

        // Si c'est la dernière tentative ou une autre erreur
        if (attempts > maxRetries) {
          _logger.e('GET Error after $maxRetries retries: $e');
        } else {
          _logger.e('GET Error: $e');
        }
        rethrow;
      }
    }

    throw Exception('Max retries exceeded');
  }

  /// Valider et parser la réponse du serveur
  dynamic _validateAndParseResponse(Response response) {
    final data = response.data;

    if (data == null) {
      throw const FormatException('Response data is null');
    }

    // Déjà JSON parsé par Dio
    if (data is Map || data is List) {
      return data;
    }

    // Certains adapters peuvent renvoyer des bytes
    if (data is List<int>) {
      try {
        final decoded = utf8.decode(data, allowMalformed: true);
        return _parseJsonString(decoded);
      } catch (e) {
        throw FormatException('Failed to decode bytes response: $e');
      }
    }

    // Cas standard: String
    if (data is String) {
      return _parseJsonString(data);
    }

    // Fallback: retourner brut
    return data;
  }

  dynamic _parseJsonString(String raw) {
    final responseData = raw.trim();

    if (responseData.isEmpty) {
      throw const FormatException('Response data is empty');
    }

    // Si c'est une réponse HTML (souvent erreur reverse proxy)
    if (responseData.startsWith('<!DOCTYPE html') ||
        responseData.startsWith('<html')) {
      throw FormatException(
        'Response is HTML, not JSON: ${responseData.substring(0, responseData.length > 80 ? 80 : responseData.length)}',
      );
    }

    if (!responseData.startsWith('{') && !responseData.startsWith('[')) {
      final preview = responseData.substring(
        0,
        responseData.length > 80 ? 80 : responseData.length,
      );
      throw FormatException('Response is not valid JSON: $preview');
    }

    try {
      return jsonDecode(responseData);
    } catch (e) {
      throw FormatException('Failed to parse JSON: $e');
    }
  }

  /// Requête POST optimisée avec retry
  Future<T> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Duration? cacheExpiration,
    int maxRetries = 1,
  }) async {
    // Pour les POST, on utilise le batch si possible
    if (data != null && _canBatchRequest(endpoint)) {
      return _networkOptimizer.batchRequest(
        'POST:$endpoint',
        () => _executePostWithRetry<T>(
          endpoint,
          data,
          queryParameters,
          fromJson,
          maxRetries,
        ),
      );
    }

    return _executePostWithRetry<T>(
      endpoint,
      data,
      queryParameters,
      fromJson,
      maxRetries,
    );
  }

  Future<T> _executePostWithRetry<T>(
    String endpoint,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    int maxRetries,
  ) async {
    int attempts = 0;

    while (attempts <= maxRetries) {
      try {
        final response = await _dio.post(
          endpoint,
          data: data,
          queryParameters: queryParameters,
          cancelToken: _cancelToken,
        );

        // Valider et parser la réponse
        final validatedData = _validateAndParseResponse(response);

        if (fromJson != null) {
          return fromJson(validatedData);
        }

        return validatedData as T;
      } catch (e) {
        attempts++;

        // Si c'est une erreur de formatage et qu'on peut réessayer
        if (e is DioException &&
            e.error is FormatException &&
            attempts <= maxRetries) {
          _logger.w(
            ' POST Retry $attempts/$maxRetries for $endpoint due to format error',
          );

          // Attendre un peu avant de réessayer
          await Future.delayed(Duration(milliseconds: 500 * attempts));
          continue;
        }

        // Si c'est la dernière tentative ou une autre erreur
        if (attempts > maxRetries) {
          _logger.e('POST Error after $maxRetries retries: $e');
        } else {
          _logger.e('POST Error: $e');
        }
        rethrow;
      }
    }

    throw Exception('Max POST retries exceeded');
  }

  /// Requête PUT
  Future<T> put<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );

      if (fromJson != null) {
        return fromJson(response.data);
      }

      return response.data as T;
    } catch (e) {
      _logger.e('PUT Error: $e');
      rethrow;
    }
  }

  /// Requête PATCH
  Future<T> patch<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.patch(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );

      if (fromJson != null) {
        return fromJson(response.data);
      }

      return response.data as T;
    } catch (e) {
      _logger.e('PATCH Error: $e');
      rethrow;
    }
  }

  /// Requête DELETE
  Future<T> delete<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        queryParameters: queryParameters,
      );

      if (fromJson != null) {
        return fromJson(response.data);
      }

      return response.data as T;
    } catch (e) {
      _logger.e('DELETE Error: $e');
      rethrow;
    }
  }

  /// Télécharger un fichier
  Future<void> downloadFile(
    String endpoint,
    String savePath, {
    Function(int, int)? onReceiveProgress,
  }) async {
    try {
      await _dio.download(
        endpoint,
        savePath,
        onReceiveProgress: onReceiveProgress,
      );
    } catch (e) {
      _logger.e('Download Error: $e');
      rethrow;
    }
  }

  /// Annuler toutes les requêtes en cours
  void cancelAllRequests() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('Requests cancelled by user');
    }
    _networkOptimizer.cancelAllBatches();
  }

  /// Vider le cache
  void clearCache() {
    _cache.clear();
    _requestManager.clearCache();
  }

  /// Obtenir les statistiques de performance
  Map<String, Map<String, dynamic>> getPerformanceStats() {
    return _performanceMonitor.getPerformanceStats();
  }

  /// Vérifier si une requête peut être batchée
  bool _canBatchRequest(String endpoint) {
    // Ne batcher que les requêtes de données similaires
    final batchableEndpoints = [
      '/parent/context/',
      '/children/',
      '/establishments/',
    ];
    return batchableEndpoints.any((e) => endpoint.contains(e));
  }

  /// Nettoyer les ressources
  void dispose() {
    cancelAllRequests();
    clearCache();
  }
}
