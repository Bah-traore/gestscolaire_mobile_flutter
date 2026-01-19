import 'api_service.dart';

class ModulesService {
  final ApiService _api;

  ModulesService(this._api);

  Future<Map<String, dynamic>> fetchNotes({
    required String tenant,
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/$tenant/notes/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }

  Future<Map<String, dynamic>> fetchHomework({
    required String tenant,
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/$tenant/homework/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }

  Future<Map<String, dynamic>> fetchBulletins({
    required String tenant,
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/$tenant/bulletins/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }

  Future<Map<String, dynamic>> fetchNotifications({
    required String tenant,
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/$tenant/notifications/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }

  Future<Map<String, dynamic>> fetchScolarites({
    required String tenant,
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/$tenant/scolarites/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }
}
