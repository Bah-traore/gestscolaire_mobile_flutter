import 'package:intl/intl.dart';
import 'api_service.dart';
import '../models/timetable_models.dart';

class TimetableService {
  final ApiService _api;

  TimetableService(this._api);

  Future<TimetableResponse> fetchTimetable({
    required int tenantId,
    required int eleveId,
    required DateTime start,
    required DateTime end,
    String view = 'week',
  }) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    final response = await _api.get<Map<String, dynamic>>(
      '/parent/timetable/',
      queryParameters: {
        'tenant_id': tenantId,
        'eleve_id': eleveId,
        'start': startStr,
        'end': endStr,
        'view': view,
      },
    );

    return TimetableResponse.fromJson(response);
  }
}
