import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/attendance_service.dart';

final attendanceServiceProvider =
    Provider<AttendanceService>((ref) => AttendanceService());

// ── Current class context ─────────────────────────────────────────────────────

final selectedClassIdProvider = StateProvider<String>((ref) => 'CLASS-10A');
final selectedSectionProvider = StateProvider<String>((ref) => 'A');

// ── Student gaps ──────────────────────────────────────────────────────────────

final studentGapsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, studentId) async {
  final svc = ref.read(attendanceServiceProvider);
  final classId = ref.read(selectedClassIdProvider);
  return svc.getGaps(studentId: studentId, classId: classId, status: 'unresolved');
});

// ── Student overall stats ─────────────────────────────────────────────────────

final studentStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, studentId) async {
  final svc = ref.read(attendanceServiceProvider);
  final classId = ref.read(selectedClassIdProvider);
  return svc.getOverallStats(studentId, classId);
});

// ── Threshold compliance check ────────────────────────────────────────────────

final thresholdCheckProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, studentId) async {
  final svc = ref.read(attendanceServiceProvider);
  final classId = ref.read(selectedClassIdProvider);
  return svc.checkThreshold(studentId, classId);
});

// ── Weekly routine for a class ────────────────────────────────────────────────

final routineProvider =
    FutureProvider.family<List<dynamic>, String>((ref, classId) async {
  final svc = ref.read(attendanceServiceProvider);
  return svc.getRoutine(classId);
});

// ── Class-level attendance summary (mentor) ───────────────────────────────────

final classSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, classId) async {
  final svc = ref.read(attendanceServiceProvider);
  final section = ref.read(selectedSectionProvider);
  return svc.getClassSummary(classId, section);
});

// ── Gaps for a class (mentor view) ───────────────────────────────────────────

final classGapsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, classId) async {
  final svc = ref.read(attendanceServiceProvider);
  return svc.getGaps(classId: classId);
});

// ── Student attendance history ────────────────────────────────────────────────

final studentHistoryProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, studentId) async {
  final svc = ref.read(attendanceServiceProvider);
  final classId = ref.read(selectedClassIdProvider);
  return svc.getStudentHistory(studentId, classId);
});

// ── Periods for a class ───────────────────────────────────────────────────────

final periodsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, classId) async {
  final svc = ref.read(attendanceServiceProvider);
  return svc.getPeriods(classId);
});

// ── Student calendar ──────────────────────────────────────────────────────────

class StudentCalendarParams {
  final String studentId;
  final String classId;
  final int year;
  final int month;
  StudentCalendarParams(
      {required this.studentId,
      required this.classId,
      required this.year,
      required this.month});
}

final studentCalendarProvider =
    FutureProvider.family<List<dynamic>, StudentCalendarParams>(
        (ref, params) async {
  final svc = ref.read(attendanceServiceProvider);
  return svc.getStudentCalendar(params.studentId, params.classId,
      year: params.year, month: params.month);
});
