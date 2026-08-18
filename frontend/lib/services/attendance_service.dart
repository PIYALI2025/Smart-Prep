import '../services/api_service.dart';

/// Thin wrapper over the FastAPI /api/v1/attendance/* endpoints.
class AttendanceService {
  final _dio = ApiService().dio;

  // ── 1.1 Periods ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getPeriods(String classId) async {
    final res = await _dio.get('/api/v1/attendance/periods',
        queryParameters: {'class_id': classId});
    return res.data as List;
  }

  Future<dynamic> createPeriod(Map<String, dynamic> body) async {
    final res = await _dio.post('/api/v1/attendance/periods', data: body);
    return res.data;
  }

  Future<void> deletePeriod(String periodId) async {
    await _dio.delete('/api/v1/attendance/periods/$periodId');
  }

  // ── 1.1 Weekly Routine ────────────────────────────────────────────────────

  Future<List<dynamic>> getRoutine(String classId) async {
    final res = await _dio.get('/api/v1/attendance/routine',
        queryParameters: {'class_id': classId});
    return res.data as List;
  }

  Future<dynamic> createRoutineEntry(Map<String, dynamic> body) async {
    final res = await _dio.post('/api/v1/attendance/routine', data: body);
    return res.data;
  }

  Future<void> deleteRoutineEntry(String entryId) async {
    await _dio.delete('/api/v1/attendance/routine/$entryId');
  }

  // ── 1.1 Holidays ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getHolidays(String classId) async {
    final res = await _dio.get('/api/v1/attendance/holidays',
        queryParameters: {'class_id': classId});
    return res.data as List;
  }

  Future<dynamic> createHoliday(Map<String, dynamic> body) async {
    final res = await _dio.post('/api/v1/attendance/holidays', data: body);
    return res.data;
  }

  // ── 1.1 Extra Off Days ────────────────────────────────────────────────────

  Future<List<dynamic>> getExtraOffDays(String classId,
      {int? year, int? month}) async {
    final res = await _dio.get('/api/v1/attendance/extra-off-days',
        queryParameters: {
          'class_id': classId,
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        });
    return res.data as List;
  }

  Future<dynamic> createExtraOffDay(Map<String, dynamic> body) async {
    final res =
        await _dio.post('/api/v1/attendance/extra-off-days', data: body);
    return res.data;
  }

  // ── 1.2 Mark attendance (single) ──────────────────────────────────────────

  Future<dynamic> markAttendance(Map<String, dynamic> body) async {
    final res = await _dio.post('/api/v1/attendance/mark', data: body);
    return res.data;
  }

  Future<dynamic> updateAttendance(
      String recordId, Map<String, dynamic> body) async {
    final res =
        await _dio.put('/api/v1/attendance/mark/$recordId', data: body);
    return res.data;
  }

  Future<List<dynamic>> getStudentCalendar(String studentId, String classId,
      {int? year, int? month}) async {
    final res = await _dio.get(
        '/api/v1/attendance/calendar/$studentId',
        queryParameters: {
          'class_id': classId,
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        });
    return res.data as List;
  }

  // ── 1.3 Stats ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getOverallStats(
      String studentId, String classId) async {
    final res = await _dio.get('/api/v1/attendance/stats/$studentId',
        queryParameters: {'class_id': classId});
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getSubjectStats(
      String studentId, String subjectName, String classId) async {
    final res = await _dio.get(
        '/api/v1/attendance/stats/$studentId/subject/$subjectName',
        queryParameters: {'class_id': classId});
    return Map<String, dynamic>.from(res.data);
  }

  // ── 1.4 Threshold ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getThresholds(String classId) async {
    final res = await _dio.get('/api/v1/attendance/threshold',
        queryParameters: {'class_id': classId});
    return res.data as List;
  }

  Future<dynamic> createThreshold(Map<String, dynamic> body) async {
    final res = await _dio.post('/api/v1/attendance/threshold', data: body);
    return res.data;
  }

  Future<dynamic> updateThreshold(
      String thresholdId, double threshold) async {
    final res = await _dio.put('/api/v1/attendance/threshold/$thresholdId',
        data: {'threshold': threshold});
    return res.data;
  }

  Future<Map<String, dynamic>> checkThreshold(
      String studentId, String classId) async {
    final res = await _dio.get(
        '/api/v1/attendance/threshold/check/$studentId',
        queryParameters: {'class_id': classId});
    return Map<String, dynamic>.from(res.data);
  }

  // ── 1.5 Lecture Plans ─────────────────────────────────────────────────────

  Future<List<dynamic>> getLecturePlans(String classId, String section,
      {String? date}) async {
    final res = await _dio.get('/api/v1/attendance/lecture-plan',
        queryParameters: {
          'class_id': classId,
          'section': section,
          if (date != null) 'date': date,
        });
    return res.data as List;
  }

  Future<dynamic> createLecturePlan(Map<String, dynamic> body) async {
    final res =
        await _dio.post('/api/v1/attendance/lecture-plan', data: body);
    return res.data;
  }

  Future<dynamic> updateLecturePlan(
      String planId, Map<String, dynamic> body) async {
    final res = await _dio
        .put('/api/v1/attendance/lecture-plan/$planId', data: body);
    return res.data;
  }

  Future<void> deleteLecturePlan(String planId) async {
    await _dio.delete('/api/v1/attendance/lecture-plan/$planId');
  }

  // ── 1.6 Roster & Bulk Mark ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRoster({
    required String classId,
    required String section,
    required String date,
    required String periodId,
    required List<String> studentIds,
  }) async {
    final res = await _dio.get('/api/v1/attendance/roster',
        queryParameters: {
          'class_id': classId,
          'section': section,
          'date': date,
          'period_id': periodId,
          'student_ids': studentIds.join(','),
        });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> bulkMarkAttendance(
      Map<String, dynamic> body) async {
    final res =
        await _dio.post('/api/v1/attendance/bulk-mark', data: body);
    return Map<String, dynamic>.from(res.data);
  }

  // ── 1.7 Student History ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStudentHistory(
      String studentId, String classId,
      {String? subject, String? from, String? to}) async {
    final res = await _dio.get(
        '/api/v1/attendance/history/$studentId',
        queryParameters: {
          'class_id': classId,
          if (subject != null) 'subject': subject,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        });
    return Map<String, dynamic>.from(res.data);
  }

  // ── 1.8 Class Summary ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getClassSummary(
      String classId, String section) async {
    final res = await _dio.get('/api/v1/attendance/class-summary',
        queryParameters: {'class_id': classId, 'section': section});
    return Map<String, dynamic>.from(res.data);
  }

  // ── 1.9 Gaps ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getGaps({
    String? classId,
    String? studentId,
    String? status,
  }) async {
    final res = await _dio.get('/api/v1/attendance/gaps',
        queryParameters: {
          if (classId != null) 'class_id': classId,
          if (studentId != null) 'student_id': studentId,
          if (status != null) 'gap_status': status,
        });
    return res.data as List;
  }

  Future<dynamic> updateGapStatus(String gapId, String newStatus) async {
    final res = await _dio.put('/api/v1/attendance/gaps/$gapId/status',
        queryParameters: {'new_status': newStatus});
    return res.data;
  }
}
