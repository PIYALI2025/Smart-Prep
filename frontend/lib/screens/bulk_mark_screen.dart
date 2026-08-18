import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/attendance_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BulkMarkScreen extends ConsumerStatefulWidget {
  final String classId, section, date, periodId, subjectName;
  const BulkMarkScreen({super.key, required this.classId, required this.section,
      required this.date, required this.periodId, required this.subjectName});
  @override
  ConsumerState<BulkMarkScreen> createState() => _State();
}

class _State extends ConsumerState<BulkMarkScreen> {
  List<Map<String, dynamic>> _students = [];
  final Map<String, String> _marks = {};
  bool _loading = true, _submitting = false;
  String? _err, _successMsg;

  @override
  void initState() { super.initState(); _loadStudents(); }

  Future<void> _loadStudents() async {
    setState(() { _loading = true; _err = null; });
    try {
      final res = await ApiService().dio.get('/auth/students');
      _students = List<Map<String, dynamic>>.from(res.data as List);
      for (final s in _students) {
        _marks[s['id'].toString()] = 'present';
      }
    } catch (e) {
      _students = [];
      _err = 'Could not load students.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _successMsg = null; _err = null; });
    try {
      final records = _students.map((s) => {
        'student_id': s['id'].toString(),
        'status': _marks[s['id'].toString()] ?? 'present',
      }).toList();
      final res = await AttendanceService().bulkMarkAttendance({
        'class_id': widget.classId, 'section': widget.section,
        'date': widget.date, 'period_id': widget.periodId,
        'subject_name': widget.subjectName, 'is_unplanned': false,
        'records': records,
      });
      final marked = res['total_marked'] ?? records.length;
      setState(() => _successMsg = 'Marked attendance for $marked students.');
    } on DioException catch (e) {
      setState(() => _err = e.response?.data?['detail']?.toString() ?? 'Submission failed.');
    } catch (e) {
      setState(() => _err = 'An error occurred.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.surfaceSolid, iconTheme: const IconThemeData(color: AppColors.green),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mark Attendance', style: AppTextStyles.subheading.copyWith(fontSize: 16)),
        Text('${widget.subjectName} • ${widget.date}',
            style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
      ]),
    ),
    bottomNavigationBar: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(color: AppColors.surfaceSolid,
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_successMsg != null) Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Text(_successMsg!, style: AppTextStyles.mono.copyWith(color: AppColors.green, fontSize: 12))),
        if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Text(_err!, style: AppTextStyles.mono.copyWith(color: AppColors.error, fontSize: 12))),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text('Submit Attendance (${_students.length} students)',
                    style: AppTextStyles.button.copyWith(color: Colors.black, fontSize: 14)),
          ),
        ),
      ]),
    ),
    body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.green))
      : Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              _bulkBtn('All Present', 'present', AppColors.green),
              const SizedBox(width: 8),
              _bulkBtn('All Absent', 'absent', AppColors.error),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = _students[i];
              final sid = s['id'].toString();
              final name = s['name']?.toString() ?? s['username']?.toString() ?? sid;
              final mark = _marks[sid] ?? 'present';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: AppColors.green.withValues(alpha: 0.15),
                      child: Text(name[0].toUpperCase(), style: AppTextStyles.monoBold.copyWith(
                          color: AppColors.greenGlow, fontSize: 13))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name, style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
                  _markSegment(sid, mark),
                ]),
              );
            },
          )),
        ]),
  );

  Widget _bulkBtn(String label, String mark, Color c) => Expanded(
    child: OutlinedButton(
      onPressed: () => setState(() { for (final s in _students) _marks[s['id'].toString()] = mark; }),
      style: OutlinedButton.styleFrom(foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      child: Text(label, style: AppTextStyles.mono.copyWith(color: c, fontSize: 11)),
    ),
  );

  Widget _markSegment(String sid, String current) {
    const marks = ['present', 'absent', 'late'];
    final colors = {'present': AppColors.green, 'absent': AppColors.error, 'late': AppColors.warning};
    return Row(mainAxisSize: MainAxisSize.min, children: marks.map((m) {
      final sel = current == m; final c = colors[m]!;
      return GestureDetector(
        onTap: () => setState(() => _marks[sid] = m),
        child: AnimatedContainer(duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: sel ? c.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: sel ? c : AppColors.border)),
          child: Text(m[0].toUpperCase(), style: AppTextStyles.monoBold.copyWith(
              color: sel ? c : AppColors.textDisabled, fontSize: 11)),
        ),
      );
    }).toList());
  }
}
