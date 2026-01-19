import 'package:dio/dio.dart';

import 'api_service.dart';

class EstablishmentsService {
  final ApiService _api;

  EstablishmentsService(this._api);

  Future<List<Map<String, dynamic>>> discover({
    required String identifier,
  }) async {
    // Backend exposes both:
    // - POST /api/parent/discover-establishments/
    // - POST /api/auth/parent-discover/
    // Some deployments may only enable the auth proxy, so we try parent first then fallback.
    Map<String, dynamic> response;
    try {
      response = await _api.post<Map<String, dynamic>>(
        '/parent/discover-establishments/',
        data: {'login': identifier},
      );
    } on DioException catch (e) {
      if ((e.response?.statusCode ?? 0) == 404) {
        response = await _api.post<Map<String, dynamic>>(
          '/auth/parent-discover/',
          data: {'login': identifier},
        );
      } else {
        rethrow;
      }
    }

    final raw = response['establishments'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> switchEstablishment({
    required String establishmentId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/parent/switch-establishment/',
      data: {'establishment_id': establishmentId},
    );

    return response;
  }
}
