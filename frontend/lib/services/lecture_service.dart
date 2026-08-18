import '../services/api_service.dart';

/// Handles the two lecture-plan router groups:
///   - /api/v1/lecture-plan/* (from lecture_router.py — syllabus & missed lectures)
///   - /api/v1/lecture-plan/* (from mentor_router.py  — batch attendance & class summary)
class LectureService {
  final _dio = ApiService().dio;

  // ── Upload syllabus topics (lecture_router) ────────────────────────────────

  Future<dynamic> uploadLecturePlan({
    required String classId,
    required String subjectName,
    required List<Map<String, dynamic>> topics,
  }) async {
    final res = await _dio.post('/api/v1/lecture-plan/upload', data: {
      'class_id': classId,
      'subject_name': subjectName,
      'topics': topics,
    });
    return res.data;
  }

  // ── Log coverage (lecture_router) ──────────────────────────────────────────

  Future<dynamic> logCoverage({
    required String classId,
    required String periodId,
    required String lecturePlanId,
    required String date,
    String? taughtBy,
  }) async {
    final res = await _dio.post('/api/v1/lecture-plan/log-coverage', data: {
      'class_id': classId,
      'period_id': periodId,
      'lecture_plan_id': lecturePlanId,
      'date': date,
      if (taughtBy != null) 'taught_by': taughtBy,
    });
    return res.data;
  }

  // ── Get missed lectures for a student (lecture_router) ────────────────────

  Future<List<dynamic>> getMissedLectures(String studentId) async {
    final res =
        await _dio.get('/api/v1/lecture-plan/missed/$studentId');
    return res.data as List;
  }

  // ── Batch mark attendance for a period (mentor_router) ────────────────────

  Future<dynamic> batchMarkAttendance({
    required String classId,
    required String periodId,
    required String date,
    required List<Map<String, dynamic>> records,
  }) async {
    final res = await _dio
        .post('/api/v1/lecture-plan/attendance/batch', data: {
      'class_id': classId,
      'period_id': periodId,
      'date': date,
      'records': records,
    });
    return res.data;
  }

  // ── Class missed summary by date (mentor_router) ──────────────────────────

  Future<List<dynamic>> getClassMissedSummary(
      String classId, String date) async {
    final res = await _dio.get(
        '/api/v1/lecture-plan/class-summary/$classId',
        queryParameters: {'date': date});
    return res.data as List;
  }
}
