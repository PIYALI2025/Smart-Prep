import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import 'student_history_screen.dart';
import 'gap_detail_screen.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});
  @override
  ConsumerState<StudentDashboard> createState() => _State();
}

class _State extends ConsumerState<StudentDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _radar;
  List<Map<String, dynamic>> _gaps = [];
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _threshold;
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _load();
  }
  @override
  void dispose() { _radar.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _err = null; });
    final user = ref.read(authProvider).user;
    final sid = user?.id ?? '';
    final cid = ref.read(selectedClassIdProvider);
    try {
      final svc = AttendanceService();
      final r = await Future.wait([
        svc.getGaps(studentId: sid, classId: cid, status: 'unresolved'),
        svc.getOverallStats(sid, cid),
        svc.checkThreshold(sid, cid),
      ]);
      _gaps = List<Map<String, dynamic>>.from(r[0] as List);
      _stats = r[1] as Map<String, dynamic>;
      _threshold = r[2] as Map<String, dynamic>;
    } catch (e) {
      _err = 'Failed to load dashboard data. Please try again.';
      _gaps = [];
      _stats = null;
      _threshold = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.green, backgroundColor: AppColors.surfaceSolid, onRefresh: _load,
    child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.green))
      : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          if (_err != null) _banner(_err!, AppColors.warning, Icons.wifi_off_rounded),
          _radarPanel(), const SizedBox(height: 20),
          _attendanceCard(), const SizedBox(height: 12),
          if (_threshold != null) _thresholdWarning(), const SizedBox(height: 16),
          _hdr('ACTIVE GAPS', Icons.warning_amber_rounded, _gaps.length, AppColors.warning),
          const SizedBox(height: 10),
          ..._gaps.map(_gapTile),
          if (_gaps.isEmpty) _empty('No gaps detected', Icons.check_circle_outline_rounded, AppColors.green),
          const SizedBox(height: 20), _subjects(),
          const SizedBox(height: 20), _historyBtn(),
        ]),
  );

  Widget _banner(String m, Color c, IconData i) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.4))),
    child: Row(children: [Icon(i, color: c, size: 18), const SizedBox(width: 8),
      Expanded(child: Text(m, style: AppTextStyles.mono.copyWith(color: c, fontSize: 11)))]),
  );

  Widget _radarPanel() => Container(height: 240,
    decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25))),
    child: Stack(alignment: Alignment.center, children: [
      AnimatedBuilder(animation: _radar, builder: (_, __) => CustomPaint(
          size: const Size(200, 200),
          painter: RadarPainter(sweepAngle: _radar.value * 2 * pi, gapCount: _gaps.length))),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${_gaps.length}', style: AppTextStyles.heading.copyWith(fontSize: 48,
            color: _gaps.isEmpty ? AppColors.green : AppColors.warning)),
        Text(_gaps.isEmpty ? 'ALL CLEAR' : 'GAPS DETECTED',
            style: AppTextStyles.label.copyWith(
                color: _gaps.isEmpty ? AppColors.green : AppColors.warning, letterSpacing: 2, fontSize: 10)),
      ]),
    ]),
  );

  Widget _attendanceCard() {
    final pct = (_stats?['overall_attendance_pct'] ?? 0.0) as num;
    final b = pct < 75; final c = b ? AppColors.error : AppColors.green;
    return Container(padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(b ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: c, size: 20),
          const SizedBox(width: 8), Text('OVERALL ATTENDANCE', style: AppTextStyles.label.copyWith(fontSize: 11)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('${pct.toStringAsFixed(1)}%', style: AppTextStyles.monoBold.copyWith(
                  color: b ? AppColors.error : AppColors.greenGlow, fontSize: 14))),
        ]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0).toDouble(), minHeight: 8,
            backgroundColor: AppColors.surfaceElevated, valueColor: AlwaysStoppedAnimation(c))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _chip('Total', '${_stats?['total_classes'] ?? 0}', AppColors.textMuted),
          _chip('Present', '${_stats?['present_count'] ?? 0}', AppColors.green),
          _chip('Absent', '${_stats?['absent_count'] ?? 0}', AppColors.error),
          _chip('Target', '75%', AppColors.info),
        ]),
      ]),
    );
  }

  Widget _chip(String l, String v, Color c) => Column(children: [
    Text(v, style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 15)),
    Text(l, style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
  ]);

  Widget _thresholdWarning() {
    final below = ((_threshold?['subjects'] as List?)?.where((s) => s['is_below'] == true).toList() ?? []);
    if (below.isEmpty) return const SizedBox.shrink();
    return Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18), const SizedBox(width: 8),
          Text('ATTENDANCE WARNING', style: AppTextStyles.label.copyWith(color: AppColors.error, fontSize: 11))]),
        const SizedBox(height: 10),
        ...below.map((s) => Padding(padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 14), const SizedBox(width: 6),
            Expanded(child: Text(s['subject_name'] ?? '', style: AppTextStyles.body.copyWith(fontSize: 12))),
            Text('Need ${s['classes_needed']} more', style: AppTextStyles.mono.copyWith(color: AppColors.error, fontSize: 10)),
          ]),
        )),
      ]),
    );
  }

  Widget _hdr(String t, IconData i, int n, Color c) => Row(children: [
    Icon(i, color: c, size: 18), const SizedBox(width: 8),
    Text(t, style: AppTextStyles.label.copyWith(fontSize: 12)), const Spacer(),
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text('$n', style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 11))),
  ]);

  Widget _gapTile(Map<String, dynamic> gap) {
    final lp = gap['lecture_plan'] as Map<String, dynamic>?;
    final topic = lp?['topic'] ?? 'Unknown Topic';
    final subject = gap['subject_name'] ?? '';
    final p = (gap['priority_score'] ?? 5.0) as num;
    final pc = p >= 7 ? AppColors.error : p >= 4 ? AppColors.warning : AppColors.green;
    return Container(margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => GapDetailScreen(gap: gap, gapId: gap['id']?.toString() ?? ''))),
        child: Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle,
                color: pc.withValues(alpha: 0.12), border: Border.all(color: pc.withValues(alpha: 0.5), width: 1.5)),
                child: Center(child: Text(p.toStringAsFixed(1),
                    style: AppTextStyles.monoBold.copyWith(color: pc, fontSize: 12)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(topic, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(subject, style: AppTextStyles.mono.copyWith(color: AppColors.info, fontSize: 10))),
                const SizedBox(width: 8),
                Text(gap['date'] ?? '', style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
              ]),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _empty(String t, IconData i, Color c) => Container(padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [Icon(i, color: c.withValues(alpha: 0.6), size: 48), const SizedBox(height: 12),
      Text(t, style: AppTextStyles.body.copyWith(color: AppColors.textMuted))]));

  Widget _subjects() {
    final subjects = (_stats?['subjects'] as List?) ?? [];
    if (subjects.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _hdr('SUBJECT BREAKDOWN', Icons.analytics_outlined, subjects.length, AppColors.info),
      const SizedBox(height: 10),
      ...subjects.map((s) {
        final m = s as Map<String, dynamic>;
        final pct = (m['attendance_pct'] ?? 0.0) as num;
        final b = m['is_below_threshold'] == true;
        final c = b ? AppColors.error : AppColors.green;
        return Container(margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(width: 4, height: 32, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 12),
            Expanded(child: Text(m['subject_name'] ?? '', style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
            Text('${pct.toStringAsFixed(1)}%', style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 13)),
            if (b) ...[const SizedBox(width: 6), const Icon(Icons.arrow_downward_rounded, color: AppColors.error, size: 14)],
          ]),
        );
      }),
    ]);
  }

  Widget _historyBtn() => OutlinedButton.icon(
    onPressed: () {
      final user = ref.read(authProvider).user;
      if (user != null) Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StudentHistoryScreen(studentId: user.id, classId: ref.read(selectedClassIdProvider))));
    },
    icon: const Icon(Icons.history_rounded, size: 18), label: const Text('View Attendance History'),
    style: OutlinedButton.styleFrom(foregroundColor: AppColors.greenGlow,
        side: BorderSide(color: AppColors.green.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14)),
  );
}

class RadarPainter extends CustomPainter {
  final double sweepAngle; final int gapCount;
  const RadarPainter({required this.sweepAngle, required this.gapCount});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2); final r = size.width / 2;
    final rp = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.5..color = AppColors.green.withValues(alpha: 0.15);
    for (int i = 1; i <= 4; i++) canvas.drawCircle(c, r * i / 4, rp);
    final cp = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.3..color = AppColors.green.withValues(alpha: 0.1);
    canvas.drawLine(Offset(0, c.dy), Offset(size.width, c.dy), cp);
    canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, size.height), cp);
    final sp = Paint()
      ..shader = SweepGradient(startAngle: sweepAngle - 0.6, endAngle: sweepAngle,
          colors: [Colors.transparent, AppColors.green.withValues(alpha: 0.3)],
          transform: GradientRotation(sweepAngle - 0.6)).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r, sp);
    canvas.drawLine(c, Offset(c.dx + r * cos(sweepAngle), c.dy + r * sin(sweepAngle)),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = AppColors.green.withValues(alpha: 0.6));
    if (gapCount > 0) {
      final bp = Paint()..style = PaintingStyle.fill; final rng = Random(42);
      for (int i = 0; i < gapCount && i < 8; i++) {
        final a = rng.nextDouble() * 2 * pi; final d = r * (0.3 + rng.nextDouble() * 0.55);
        final pos = Offset(c.dx + d * cos(a), c.dy + d * sin(a));
        bp.color = AppColors.warning.withValues(alpha: 0.3); canvas.drawCircle(pos, 6, bp);
        bp.color = AppColors.warning; canvas.drawCircle(pos, 3, bp);
      }
    }
  }
  @override bool shouldRepaint(covariant RadarPainter o) => o.sweepAngle != sweepAngle || o.gapCount != gapCount;
}
