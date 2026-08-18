import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';

/// Monthly calendar heat-map of attendance records.
/// Calls GET /api/v1/attendance/calendar/{student_id}
class StudentAttendanceCalendarScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String classId;
  const StudentAttendanceCalendarScreen(
      {super.key, required this.studentId, required this.classId});

  @override
  ConsumerState<StudentAttendanceCalendarScreen> createState() =>
      _CalendarState();
}

class _CalendarState
    extends ConsumerState<StudentAttendanceCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, String> _dayMark = {}; // 'yyyy-MM-dd' → mark
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      final records = await AttendanceService().getStudentCalendar(
        widget.studentId,
        widget.classId,
        year: _month.year,
        month: _month.month,
      );
      final Map<String, String> map = {};
      for (final r in records) {
        final m = r as Map;
        final date = m['date']?.toString() ?? '';
        final mark = m['mark']?.toString() ?? '';
        if (date.isNotEmpty) {
          // Keep worst mark per day: absent > late > present > off_day
          final existing = map[date];
          if (existing == null ||
              _priority(mark) > _priority(existing)) {
            map[date] = mark;
          }
        }
      }
      _dayMark = map;
    } catch (e) {
      _err = 'Could not load calendar data.';
    }
    if (mounted) setState(() => _loading = false);
  }

  int _priority(String mark) {
    switch (mark) {
      case 'absent': return 3;
      case 'late': return 2;
      case 'present': return 1;
      default: return 0;
    }
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_month.year < now.year ||
        (_month.year == now.year && _month.month < now.month)) {
      setState(() => _month = DateTime(_month.year, _month.month + 1));
      _load();
    }
  }

  Color _cellColor(String? mark) {
    switch (mark) {
      case 'present': return AppColors.success.withValues(alpha: 0.25);
      case 'absent': return AppColors.error.withValues(alpha: 0.25);
      case 'late': return AppColors.warning.withValues(alpha: 0.25);
      case 'off_day': return AppColors.textDisabled.withValues(alpha: 0.2);
      default: return Colors.transparent;
    }
  }

  Color _dotColor(String? mark) {
    switch (mark) {
      case 'present': return AppColors.success;
      case 'absent': return AppColors.error;
      case 'late': return AppColors.warning;
      case 'off_day': return AppColors.textDisabled;
      default: return Colors.transparent;
    }
  }

  String _monthLabel(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday % 7; // 0=Sun

    // Summary counts
    int present = 0, absent = 0, late = 0;
    for (final m in _dayMark.values) {
      if (m == 'present') present++;
      else if (m == 'absent') absent++;
      else if (m == 'late') late++;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceSolid,
        iconTheme: const IconThemeData(color: AppColors.green),
        title: Text('Attendance Calendar',
            style: AppTextStyles.subheading.copyWith(fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: Column(children: [
        // ── Month navigator ──────────────────────────────────────────────────
        Container(
          color: AppColors.surfaceSolid,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.green),
              onPressed: _prevMonth,
            ),
            Expanded(
              child: Text(_monthLabel(_month),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subheading.copyWith(fontSize: 17)),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: _month.month == DateTime.now().month &&
                          _month.year == DateTime.now().year
                      ? AppColors.textDisabled
                      : AppColors.green),
              onPressed: _nextMonth,
            ),
          ]),
        ),
        // ── Summary chips ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            _summaryChip('Present', present, AppColors.success),
            const SizedBox(width: 8),
            _summaryChip('Absent', absent, AppColors.error),
            const SizedBox(width: 8),
            _summaryChip('Late', late, AppColors.warning),
          ]),
        ),
        const SizedBox(height: 12),
        // ── Day headers ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: AppTextStyles.mono.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 0.5)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        // ── Calendar grid ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.green))
              : _err != null
                  ? Center(
                      child: Text(_err!,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.error)))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1,
                        ),
                        itemCount: firstWeekday + daysInMonth,
                        itemBuilder: (_, i) {
                          if (i < firstWeekday) return const SizedBox();
                          final day = i - firstWeekday + 1;
                          final key =
                              '${_month.year}-${_pad(_month.month)}-${_pad(day)}';
                          final mark = _dayMark[key];
                          final isToday = DateTime.now().year == _month.year &&
                              DateTime.now().month == _month.month &&
                              DateTime.now().day == day;

                          return Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: _cellColor(mark),
                              borderRadius: BorderRadius.circular(8),
                              border: isToday
                                  ? Border.all(
                                      color: AppColors.green, width: 1.5)
                                  : null,
                            ),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              Text('$day',
                                  style: AppTextStyles.mono.copyWith(
                                    fontSize: 12,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: mark == null
                                        ? AppColors.textMuted
                                        : AppColors.textMain,
                                  )),
                              if (mark != null)
                                Container(
                                  width: 5, height: 5,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _dotColor(mark),
                                  ),
                                ),
                            ]),
                          );
                        },
                      ),
                    ),
        ),
        // ── Legend ──────────────────────────────────────────────────────────
        Container(
          color: AppColors.surfaceSolid,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem('Present', AppColors.success),
              const SizedBox(width: 16),
              _legendItem('Absent', AppColors.error),
              const SizedBox(width: 16),
              _legendItem('Late', AppColors.warning),
              const SizedBox(width: 16),
              _legendItem('Off Day', AppColors.textDisabled),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _summaryChip(String label, int count, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text('$count',
            style: AppTextStyles.monoBold.copyWith(color: color, fontSize: 18)),
        Text(label,
            style: AppTextStyles.mono
                .copyWith(color: AppColors.textMuted, fontSize: 9)),
      ]),
    ),
  );

  Widget _legendItem(String label, Color color) => Row(children: [
    Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(3)),
    ),
    const SizedBox(width: 5),
    Text(label,
        style:
            AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
  ]);
}
