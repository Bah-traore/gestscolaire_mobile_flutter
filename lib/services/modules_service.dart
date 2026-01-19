import 'api_service.dart';

class ModulesService {
  final ApiService _api;

  ModulesService(this._api);

  Future<Map<String, dynamic>> fetchNotes({
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/notes/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }

  Future<Map<String, dynamic>> fetchHomework({
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/homework/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }

  Future<Map<String, dynamic>> fetchBulletins({
    required int eleveId,
    String? annee,
    int? examenId,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/bulletins/',
      queryParameters: {
        'eleve_id': eleveId,
        if (annee != null) 'annee': annee,
        if (examenId != null) 'examen_id': examenId,
      },
    );
  }

  Future<Map<String, dynamic>> fetchNotifications({
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/notifications/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }

  Future<Map<String, dynamic>> fetchScolarites({
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/scolarites/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }

  Future<Map<String, dynamic>> fetchAbsences({
    required int eleveId,
    String? annee,
  }) async {
    return _api.get<Map<String, dynamic>>(
      '/parent/absences/',
      queryParameters: {'eleve_id': eleveId, if (annee != null) 'annee': annee},
    );
  }
}
