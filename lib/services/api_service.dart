import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'auth_service.dart';
import '../config/app_config.dart';

/// Service API centralisé
class ApiService {
  late Dio _dio;
  final Logger _logger = Logger();
  String? _authToken;

  AuthService? _authService;
  bool _refreshing = false;

  ApiService() {
    _initializeDio();
  }

  void attachAuthService(AuthService authService) {
    _authService = authService;
  }

  /// Initialiser Dio avec les configurations
  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectionTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        contentType: 'application/json',
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'GestScolaire Mobile/1.0',
        },
      ),
    );

    // Ajouter les interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
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

  /// Callback pour les réponses
  Future<void> _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (AppConfig.enableDebugLogging) {
      _logger.d(
        'RESPONSE: ${response.statusCode} ${response.requestOptions.path}',
      );
      _logger.d('Data: ${response.data}');
    }

    return handler.next(response);
  }

  /// Callback pour les erreurs
  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    _logger.e('ERROR: ${error.message}');
    _logger.e('Status Code: ${error.response?.statusCode}');
    _logger.e('Response: ${error.response?.data}');

    final status = error.response?.statusCode;

    final bool isRefreshEndpoint = error.requestOptions.path.contains(
      '/auth/refresh',
    );

    final bool shouldAttemptRefresh = status == 401;

    final requestOptions = error.requestOptions;
    final alreadyRetried = requestOptions.extra['retried'] == true;

    if (shouldAttemptRefresh &&
        !isRefreshEndpoint &&
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
        }
      } catch (_) {
        // ignore, will fallthrough
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

  /// Requête GET
  Future<T> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );

      if (fromJson != null) {
        return fromJson(response.data);
      }

      return response.data as T;
    } catch (e) {
      _logger.e('GET Error: $e');
      rethrow;
    }
  }

  /// Requête POST
  Future<T> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );

      if (fromJson != null) {
        return fromJson(response.data);
      }

      return response.data as T;
    } catch (e) {
      _logger.e('POST Error: $e');
      rethrow;
    }
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

  /// Uploader un fichier
  Future<T> uploadFile<T>(
    String endpoint,
    String filePath, {
    String fieldName = 'file',
    Map<String, dynamic>? additionalFields,
    Function(int, int)? onSendProgress,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
        if (additionalFields != null) ...additionalFields,
      });

      final response = await _dio.post(
        endpoint,
        data: formData,
        onSendProgress: onSendProgress,
      );

      if (fromJson != null) {
        return fromJson(response.data);
      }

      return response.data as T;
    } catch (e) {
      _logger.e('Upload Error: $e');
      rethrow;
    }
  }
}
