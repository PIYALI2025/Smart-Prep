import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});
  @override
  ConsumerState<StatsScreen> createState() => _State();
}

class _State extends ConsumerState<StatsScreen> {
  Map<String, dynamic>? _stats, _threshold;
  bool _loading = true;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    final user = ref.read(authProvider).user;
    final sid = user?.id ?? '';
    final cid = ref.read(selectedClassIdProvider);
    try {
      final svc = AttendanceService();
      final r = await Future.wait([svc.getOverallStats(sid, cid), svc.checkThreshold(sid, cid)]);
      _stats = r[0] as Map<String, dynamic>;
      _threshold = r[1] as Map<String, dynamic>;
    } catch (e) {
      _err = 'Could not load stats.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.green));
    if (_err != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
      const SizedBox(height: 12),
      Text(_err!, style: AppTextStyles.body.copyWith(color: AppColors.error)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _load, child: const Text('Retry')),
    ]));

    final subjects = (_stats?['subjects'] as List?) ?? [];
    final threshSubjects = (_threshold?['subjects'] as List?) ?? [];

    return RefreshIndicator(color: AppColors.green, backgroundColor: AppColors.surfaceSolid,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        _overallCard(),
        const SizedBox(height: 20),
        if (threshSubjects.isNotEmpty) ...[
          _sectionLabel('THRESHOLD COMPLIANCE'),
          const SizedBox(height: 10),
          ...threshSubjects.map(_threshItem),
          const SizedBox(height: 20),
        ],
        _sectionLabel('SUBJECT-WISE ATTENDANCE'),
        const SizedBox(height: 10),
        ...subjects.map(_subjectCard),
      ]),
    );
  }

  Widget _overallCard() {
    final pct = (_stats?['overall_attendance_pct'] ?? 0.0) as num;
    final present = (_stats?['present_count'] ?? 0) as num;
    final absent = (_stats?['absent_count'] ?? 0) as num;
    final total = (_stats?['total_classes'] ?? 0) as num;
    final b = pct < 75; final c = b ? AppColors.error : AppColors.green;
    return Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Column(children: [
        Text('${pct.toStringAsFixed(1)}%', style: AppTextStyles.heading.copyWith(
            fontSize: 52, color: c, shadows: [Shadow(color: c.withValues(alpha: 0.4), blurRadius: 20)])),
        Text('OVERALL ATTENDANCE', style: AppTextStyles.label.copyWith(letterSpacing: 2)),
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0).toDouble(), minHeight: 10,
            backgroundColor: AppColors.surfaceElevated, valueColor: AlwaysStoppedAnimation(c))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statItem('Total', '$total', AppColors.textMuted),
          _statItem('Present', '$present', AppColors.green),
          _statItem('Absent', '$absent', AppColors.error),
        ]),
      ]),
    );
  }

  Widget _statItem(String l, String v, Color c) => Column(children: [
    Text(v, style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 22)),
    Text(l, style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 11)),
  ]);

  Widget _sectionLabel(String t) => Text(t, style: AppTextStyles.label.copyWith(fontSize: 12));

  Widget _threshItem(dynamic s) {
    final m = s as Map<String, dynamic>;
    final pct = (m['attendance_pct'] ?? 0.0) as num;
    final thr = (m['threshold'] ?? 75.0) as num;
    final b = m['is_below'] == true; final c = b ? AppColors.error : AppColors.green;
    final needed = m['classes_needed'] ?? 0;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: b ? AppColors.error.withValues(alpha: 0.3) : AppColors.border)),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(m['subject_name'] ?? '', style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
          Text('${pct.toStringAsFixed(1)}% / ${thr.toStringAsFixed(0)}%',
              style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0).toDouble(), minHeight: 5,
            backgroundColor: AppColors.surfaceElevated, valueColor: AlwaysStoppedAnimation(c))),
        if (b) ...[const SizedBox(height: 6),
          Row(children: [const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 14),
            const SizedBox(width: 6),
            Text('Attend $needed more classes to meet threshold',
                style: AppTextStyles.mono.copyWith(color: AppColors.error, fontSize: 10))])],
      ]),
    );
  }

  Widget _subjectCard(dynamic s) {
    final m = s as Map<String, dynamic>;
    final pct = (m['attendance_pct'] ?? 0.0) as num;
    final b = m['is_below_threshold'] == true; final c = b ? AppColors.error : AppColors.green;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 4, height: 36, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['subject_name'] ?? '', style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
          const SizedBox(height: 4),
          Text('${m['present_count'] ?? 0} present / ${m['absent_count'] ?? 0} absent',
              style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${pct.toStringAsFixed(1)}%', style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 14)),
          if (b) Text('Below target', style: AppTextStyles.mono.copyWith(color: AppColors.error, fontSize: 9)),
        ]),
      ]),
    );
  }
}
