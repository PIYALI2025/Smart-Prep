import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';

class ClassSummaryScreen extends ConsumerStatefulWidget {
  final String classId, section;
  const ClassSummaryScreen({super.key, required this.classId, required this.section});
  @override
  ConsumerState<ClassSummaryScreen> createState() => _State();
}

class _State extends ConsumerState<ClassSummaryScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      _data = await AttendanceService().getClassSummary(widget.classId, widget.section);
    } catch (e) {
      _err = 'Could not load class summary.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final students = (_data?['students'] as List?) ?? [];
    final threshold = (_data?['default_threshold'] ?? 75.0) as num;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceSolid, iconTheme: const IconThemeData(color: AppColors.green),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Class Summary', style: AppTextStyles.subheading.copyWith(fontSize: 16)),
          Text('${widget.classId} • Section ${widget.section}',
              style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.green))
        : _err != null ? Center(child: Text(_err!, style: AppTextStyles.body.copyWith(color: AppColors.error)))
        : Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                _statChip('Students', '${students.length}', AppColors.info),
                const SizedBox(width: 12),
                _statChip('Threshold', '${threshold.toStringAsFixed(0)}%', AppColors.warning),
                const SizedBox(width: 12),
                _statChip('At Risk', '${students.where((s) => s['has_warning'] == true).length}', AppColors.error),
              ])),
            Expanded(child: RefreshIndicator(color: AppColors.green, onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: students.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final s = students[i] as Map<String, dynamic>;
                  final pct = (s['overall_attendance_pct'] ?? 0.0) as num;
                  final warn = s['has_warning'] == true;
                  final c = warn ? AppColors.error : AppColors.green;
                  final name = s['student_name']?.toString() ?? s['student_id']?.toString() ?? '';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: warn ? AppColors.error.withValues(alpha: 0.3) : AppColors.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: c.withValues(alpha: 0.15),
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 12))),
                        const SizedBox(width: 10),
                        Expanded(child: Text(name, style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
                        if (warn) const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 4),
                        Text('${pct.toStringAsFixed(1)}%', style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 13)),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0).toDouble(), minHeight: 5,
                          backgroundColor: AppColors.surfaceElevated, valueColor: AlwaysStoppedAnimation(c))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        ...((s['subjects'] as List?) ?? []).map((sub) {
                          final m = sub as Map<String, dynamic>;
                          final sp = (m['attendance_pct'] ?? 0.0) as num;
                          final sb = m['is_below_threshold'] == true;
                          return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: (sb ? AppColors.error : AppColors.green).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text('${m['subject_name'] ?? ''}: ${sp.toStringAsFixed(0)}%',
                                style: AppTextStyles.mono.copyWith(
                                    color: sb ? AppColors.error : AppColors.green, fontSize: 10)));
                        }),
                      ]),
                    ]),
                  );
                },
              ),
            )),
          ]),
    );
  }

  Widget _statChip(String l, String v, Color c) => Expanded(
    child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Column(children: [
        Text(v, style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 18)),
        const SizedBox(height: 4),
        Text(l, style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
      ]),
    ),
  );
}
