import 'api_service.dart';

class ChildrenService {
  final ApiService _api;

  ChildrenService(this._api);

  Future<List<Map<String, dynamic>>> fetchChildren({
    required String establishmentId,
    String? academicYear,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/parent/$establishmentId/children/',
      queryParameters: {if (academicYear != null) 'annee': academicYear},
    );

    final rawChildren = response['children'];
    if (rawChildren is List) {
      return rawChildren
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return [];
  }
}
