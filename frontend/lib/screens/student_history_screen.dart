import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import 'student_attendance_calendar_screen.dart';

/// Full attendance history for a student:
///  - subject filter chips
///  - date range pickers
///  - color-coded mark tiles
///  - link to calendar view
class StudentHistoryScreen extends StatefulWidget {
  final String studentId;
  final String classId;
  const StudentHistoryScreen(
      {super.key, required this.studentId, required this.classId});

  @override
  State<StudentHistoryScreen> createState() =>
      _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  List<dynamic> _records = [];
  int _total = 0;
  bool _loading = true;
  String? _err;

  // Filters
  String? _selectedSubject;
  List<String> _subjects = [];
  DateTime? _fromDate, _toDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final res = await AttendanceService().getStudentHistory(
        widget.studentId,
        widget.classId,
        subject: _selectedSubject,
        from: _fromDate != null ? _fmt(_fromDate!) : null,
        to: _toDate != null ? _fmt(_toDate!) : null,
      );
      _records = (res['records'] as List?) ?? [];
      _total = res['total_records'] as int? ?? _records.length;

      // Build subject list from all records the first time
      if (_subjects.isEmpty) {
        final Set<String> seen = {};
        for (final r in _records) {
          final sub = (r as Map)['subject_name']?.toString() ?? '';
          if (sub.isNotEmpty) seen.add(sub);
        }
        _subjects = seen.toList()..sort();
      }
    } catch (e) {
      _err = 'Could not load history. Check your connection.';
      _records = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Color _markColor(String mark) {
    switch (mark.toLowerCase()) {
      case 'present':
        return AppColors.success;
      case 'absent':
        return AppColors.error;
      case 'late':
        return AppColors.warning;
      case 'off_day':
        return AppColors.textMuted;
      default:
        return AppColors.textDisabled;
    }
  }

  IconData _markIcon(String mark) {
    switch (mark.toLowerCase()) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'late':
        return Icons.access_time_rounded;
      case 'off_day':
        return Icons.event_busy_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now().subtract(const Duration(days: 30)))
        : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.green,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textMain,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isFrom ? _fromDate = picked : _toDate = picked);
      _load();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSubject = null;
      _fromDate = null;
      _toDate = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFilters =
        _selectedSubject != null || _fromDate != null || _toDate != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceSolid,
        iconTheme: const IconThemeData(color: AppColors.green),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Attendance History',
              style: AppTextStyles.subheading.copyWith(fontSize: 16)),
          Text('$_total records',
              style: AppTextStyles.mono
                  .copyWith(color: AppColors.textMuted, fontSize: 10)),
        ]),
        actions: [
          // Calendar view button
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: AppColors.green),
            tooltip: 'Calendar View',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => StudentAttendanceCalendarScreen(
                studentId: widget.studentId,
                classId: widget.classId,
              ),
            )),
          ),
          if (hasFilters)
            IconButton(
              icon: const Icon(Icons.filter_list_off_rounded,
                  color: AppColors.warning),
              tooltip: 'Clear Filters',
              onPressed: _clearFilters,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        // ── Filter bar ──────────────────────────────────────────────────────
        _filterBar(),
        // ── Content ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.green))
              : _err != null
                  ? _errorState()
                  : _records.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: AppColors.green,
                          backgroundColor: AppColors.surfaceSolid,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: _records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                _recordTile(_records[i] as Map<String, dynamic>),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _filterBar() => Container(
    color: AppColors.surfaceSolid,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Subject chips
      if (_subjects.isNotEmpty) ...[
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('All', _selectedSubject == null, () {
                setState(() => _selectedSubject = null);
                _load();
              }),
              ..._subjects.map((s) => _chip(s, _selectedSubject == s, () {
                setState(() => _selectedSubject = s == _selectedSubject ? null : s);
                _load();
              })),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      // Date range row
      Row(children: [
        _datePicker(
          label: _fromDate != null ? _fmt(_fromDate!) : 'From date',
          onTap: () => _pickDate(isFrom: true),
          active: _fromDate != null,
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_rounded,
            color: AppColors.textDisabled, size: 14),
        const SizedBox(width: 8),
        _datePicker(
          label: _toDate != null ? _fmt(_toDate!) : 'To date',
          onTap: () => _pickDate(isFrom: false),
          active: _toDate != null,
        ),
      ]),
    ]),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.green
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.mono.copyWith(
            color: selected ? AppColors.greenGlow : AppColors.textMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );

  Widget _datePicker(
      {required String label,
      required VoidCallback onTap,
      required bool active}) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.green.withValues(alpha: 0.08)
                  : AppColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active
                      ? AppColors.green.withValues(alpha: 0.4)
                      : AppColors.border),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 12,
                  color: active ? AppColors.green : AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.mono.copyWith(
                        color:
                            active ? AppColors.greenGlow : AppColors.textMuted,
                        fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
      );

  Widget _recordTile(Map<String, dynamic> r) {
    final mark = r['mark']?.toString() ?? 'unknown';
    final color = _markColor(mark);
    final subject = r['subject_name']?.toString() ?? '—';
    final date = r['date']?.toString() ?? '—';
    final period = r['period_name']?.toString() ?? '';
    final topic = r['topic']?.toString() ?? '';
    final notes = r['notes']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Left accent bar
        Container(
          width: 4, height: 72,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              bottomLeft: Radius.circular(13),
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Mark icon
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(_markIcon(mark), color: color, size: 17),
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Expanded(
                  child: Text(subject,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                _markBadge(mark, color),
              ]),
              const SizedBox(height: 3),
              Text(
                '$date${period.isNotEmpty ? ' · $period' : ''}',
                style: AppTextStyles.mono
                    .copyWith(color: AppColors.textMuted, fontSize: 10),
              ),
              if (topic.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(topic,
                    style: AppTextStyles.mono.copyWith(
                        color: AppColors.textDisabled, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('Note: $notes',
                    style: AppTextStyles.mono.copyWith(
                        color: AppColors.warning, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
        ),
        const SizedBox(width: 12),
      ]),
    );
  }

  Widget _markBadge(String mark, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      mark.toUpperCase(),
      style: AppTextStyles.mono.copyWith(
          color: color, fontSize: 9, fontWeight: FontWeight.w700),
    ),
  );

  Widget _errorState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded,
          color: AppColors.error, size: 44),
      const SizedBox(height: 14),
      Text(_err!,
          style:
              AppTextStyles.body.copyWith(color: AppColors.error),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: _load, child: const Text('Retry')),
    ]),
  );

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.history_toggle_off_rounded,
          color: AppColors.textDisabled, size: 52),
      const SizedBox(height: 14),
      Text('No records found',
          style: AppTextStyles.body
              .copyWith(color: AppColors.textMuted)),
      const SizedBox(height: 6),
      Text(
        _selectedSubject != null || _fromDate != null || _toDate != null
            ? 'Try clearing filters'
            : 'Attendance not recorded yet',
        style: AppTextStyles.mono
            .copyWith(color: AppColors.textDisabled, fontSize: 11),
      ),
    ]),
  );
}
