import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/attendance_provider.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import 'bulk_mark_screen.dart';
import 'class_summary_screen.dart';

class MentorDashboard extends ConsumerStatefulWidget {
  const MentorDashboard({super.key});
  @override
  ConsumerState<MentorDashboard> createState() => _State();
}

class _State extends ConsumerState<MentorDashboard> {
  List<Map<String, dynamic>> _routine = [];
  List<Map<String, dynamic>> _gaps = [];
  bool _loading = true;
  String? _err;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    final cid = ref.read(selectedClassIdProvider);
    try {
      final svc = AttendanceService();
      final r = await Future.wait([
        svc.getRoutine(cid),
        svc.getGaps(classId: cid),
      ]);
      _routine = List<Map<String, dynamic>>.from(r[0] as List);
      _gaps = List<Map<String, dynamic>>.from(r[1] as List);
    } catch (e) {
      _err = 'Failed to load schedule. Please try again.';
      _routine = [];
      _gaps = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _dayName(int w) {
    const d = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
    return d[(w - 1) % 7];
  }
  String _dayLabel(int w) {
    const d = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return d[(w - 1) % 7];
  }

  List<Map<String, dynamic>> get _todaySlots {
    final today = _dayName(_selectedDate.weekday);
    return _routine.where((s) => (s['day_of_week'] ?? '').toString().toLowerCase() == today).toList();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.green, backgroundColor: AppColors.surfaceSolid, onRefresh: _load,
    child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.green))
      : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          if (_err != null) _banner(),
          _quickStats(), const SizedBox(height: 20),
          _daySelector(), const SizedBox(height: 16),
          _hdr("TODAY'S SCHEDULE", Icons.calendar_today_rounded, _todaySlots.length, AppColors.green),
          const SizedBox(height: 10),
          ..._todaySlots.asMap().entries.map((e) => _routineCard(e.value, e.key)),
          if (_todaySlots.isEmpty) _emptyState('No classes scheduled', Icons.event_available_rounded),
          const SizedBox(height: 24),
          _hdr('CLASS GAPS', Icons.radar_outlined, _gaps.length, AppColors.warning),
          const SizedBox(height: 10),
          ..._gaps.take(5).map(_gapTile),
          if (_gaps.isEmpty) _emptyState('No active gaps', Icons.check_circle_outline_rounded),
          const SizedBox(height: 24),
          _classSummaryBtn(),
        ]),
  );

  Widget _banner() => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4))),
    child: Row(children: [
      const Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 18), const SizedBox(width: 8),
      Expanded(child: Text(_err!,
          style: AppTextStyles.mono.copyWith(color: AppColors.warning, fontSize: 11))),
    ]),
  );

  Widget _quickStats() {
    final unresolved = _gaps.where((g) => g['status'] == 'unresolved').length;
    return Row(children: [
      Expanded(child: _statCard(Icons.schedule_rounded, "TODAY'S CLASSES", '${_todaySlots.length}', AppColors.green)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.warning_amber_rounded, 'OPEN GAPS', '$unresolved',
          unresolved > 0 ? AppColors.warning : AppColors.green)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.people_outline_rounded, 'STUDENTS', '32', AppColors.info)),
    ]);
  }

  Widget _statCard(IconData i, String l, String v, Color c) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
    child: Column(children: [
      Icon(i, color: c, size: 22), const SizedBox(height: 8),
      Text(v, style: AppTextStyles.heading.copyWith(fontSize: 24, color: c)),
      const SizedBox(height: 4),
      Text(l, style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 8, letterSpacing: 0.8), textAlign: TextAlign.center),
    ]),
  );

  Widget _daySelector() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    return SizedBox(height: 56, child: ListView.separated(
      scrollDirection: Axis.horizontal, itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final day = start.add(Duration(days: i));
        final sel = day.day == _selectedDate.day && day.month == _selectedDate.month;
        final today = day.day == now.day && day.month == now.month;
        return GestureDetector(
          onTap: () => setState(() => _selectedDate = day),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 46,
            decoration: BoxDecoration(
                color: sel ? AppColors.green.withValues(alpha: 0.15) : AppColors.surfaceSolid,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? AppColors.green : today ? AppColors.green.withValues(alpha: 0.3) : AppColors.border,
                    width: sel ? 1.5 : 1)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_dayLabel(day.weekday), style: AppTextStyles.mono.copyWith(
                  color: sel ? AppColors.greenGlow : AppColors.textMuted, fontSize: 9,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
              const SizedBox(height: 2),
              Text('${day.day}', style: AppTextStyles.bodyBold.copyWith(
                  color: sel ? AppColors.greenGlow : AppColors.textMain, fontSize: 16)),
            ]),
          ),
        );
      },
    ));
  }

  Widget _hdr(String t, IconData i, int n, Color c) => Row(children: [
    Icon(i, color: c, size: 18), const SizedBox(width: 8),
    Text(t, style: AppTextStyles.label.copyWith(fontSize: 12)), const Spacer(),
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text('$n', style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 11))),
  ]);

  Widget _routineCard(Map<String, dynamic> slot, int idx) {
    final period = slot['period'] as Map<String, dynamic>?;
    final pName = period?['name'] ?? 'Period';
    final start = period?['start_time'] ?? '';
    final end = period?['end_time'] ?? '';
    final subject = slot['subject_name'] ?? 'Free Period';
    final teacher = slot['teacher_name'] ?? '';
    final pid = period?['id']?.toString() ?? '';
    final colors = [AppColors.green, AppColors.info, AppColors.warning, AppColors.greenAccent];
    final ac = colors[idx % colors.length];
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2,'0')}-${_selectedDate.day.toString().padLeft(2,'0')}';

    return Container(margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BulkMarkScreen(
                classId: ref.read(selectedClassIdProvider),
                section: ref.read(selectedSectionProvider),
                date: dateStr, periodId: pid, subjectName: subject))),
        child: Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(width: 4, height: 36, decoration: BoxDecoration(color: ac, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_fmt(start), style: AppTextStyles.monoBold.copyWith(color: AppColors.textMain, fontSize: 12)),
              Text(_fmt(end), style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
            ]),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text('$pName${teacher.isNotEmpty ? " • $teacher" : ""}',
                  style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: ac.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ac.withValues(alpha: 0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_note_rounded, color: ac, size: 16), const SizedBox(width: 4),
                  Text('MARK', style: AppTextStyles.mono.copyWith(color: ac, fontSize: 9, fontWeight: FontWeight.w700)),
                ])),
          ]),
        ),
      ),
    );
  }

  String _fmt(String t) {
    if (t.isEmpty) return '';
    final p = t.split(':');
    return p.length >= 2 ? '${p[0]}:${p[1]}' : t;
  }

  Widget _gapTile(Map<String, dynamic> gap) {
    final sid = gap['student_id'] ?? 'Unknown';
    final subject = gap['subject_name'] ?? '';
    final p = (gap['priority_score'] ?? 5.0) as num;
    final c = p >= 7 ? AppColors.error : AppColors.warning;
    return Container(margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle,
            color: AppColors.warning.withValues(alpha: 0.12)),
            child: Center(child: Text(sid.length >= 3 ? sid.substring(sid.length - 3) : sid,
                style: AppTextStyles.mono.copyWith(color: AppColors.warning, fontSize: 9)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subject, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
          Text('Student: $sid • ${gap['date'] ?? ''}',
              style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 9)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text('P${p.toStringAsFixed(1)}', style: AppTextStyles.monoBold.copyWith(color: c, fontSize: 10))),
      ]),
    );
  }

  Widget _emptyState(String msg, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(children: [
      Icon(icon, color: AppColors.green.withValues(alpha: 0.5), size: 40),
      const SizedBox(height: 10),
      Text(msg, style: AppTextStyles.body.copyWith(color: AppColors.textMuted, fontSize: 13)),
    ]),
  );

  Widget _classSummaryBtn() => OutlinedButton.icon(
    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ClassSummaryScreen(
            classId: ref.read(selectedClassIdProvider),
            section: ref.read(selectedSectionProvider)))),
    icon: const Icon(Icons.people_rounded, size: 18), label: const Text('View Class Summary'),
    style: OutlinedButton.styleFrom(foregroundColor: AppColors.greenGlow,
        side: BorderSide(color: AppColors.green.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14)),
  );
}
