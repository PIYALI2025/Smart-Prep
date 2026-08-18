import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';

/// Shows full detail for a single gap record and lets the student
/// mark it as reviewed once they've caught up on the topic.
class GapDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> gap;
  final String gapId;
  const GapDetailScreen({super.key, required this.gap, required this.gapId});

  @override
  ConsumerState<GapDetailScreen> createState() => _GapDetailScreenState();
}

class _GapDetailScreenState extends ConsumerState<GapDetailScreen> {
  bool _marking = false;
  late String _status;


  @override
  void initState() {
    super.initState();
    _status = widget.gap['status']?.toString() ?? 'unresolved';
    _loadMissedLectures();
  }

  Future<void> _loadMissedLectures() async {
    try {
      final subject = widget.gap['subject_name']?.toString() ?? '';
      if (subject.isNotEmpty) {
        // lecture_plan is already embedded in the gap response
      }
    } catch (_) {}
  }

  Future<void> _markReviewed() async {
    if (widget.gapId.isEmpty) return;
    setState(() => _marking = true);
    try {
      await AttendanceService().updateGapStatus(widget.gapId, 'reviewed');
      if (mounted) {
        setState(() => _status = 'reviewed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.greenDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
              const SizedBox(width: 8),
              Text('Gap marked as reviewed!',
                  style: AppTextStyles.mono.copyWith(color: AppColors.textMain, fontSize: 12)),
            ]),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.gap;
    final lp = gap['lecture_plan'] as Map<String, dynamic>?;
    final topic = lp?['topic']?.toString() ?? 'Unknown Topic';
    final subtopics = lp?['subtopics']?.toString() ?? '';
    final weight = (lp?['exam_weightage'] ?? 5.0) as num;
    final subject = gap['subject_name']?.toString() ?? '';
    final date = gap['date']?.toString() ?? '';
    final priority = (gap['priority_score'] ?? 5.0) as num;
    final reason = gap['reason']?.toString() ?? 'absence';
    final pc = priority >= 7
        ? AppColors.error
        : priority >= 4
            ? AppColors.warning
            : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceSolid,
        iconTheme: const IconThemeData(color: AppColors.green),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gap Detail', style: AppTextStyles.subheading.copyWith(fontSize: 16)),
          Text(subject, style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // ── Priority + Status header ──────────────────────────────────────────
        _card(child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pc.withValues(alpha: 0.12),
              border: Border.all(color: pc.withValues(alpha: 0.5), width: 2),
            ),
            child: Center(child: Text(
              priority.toStringAsFixed(1),
              style: AppTextStyles.monoBold.copyWith(color: pc, fontSize: 14),
            )),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Priority Score', style: AppTextStyles.label.copyWith(fontSize: 10)),
            Text(
              priority >= 7 ? 'HIGH PRIORITY' : priority >= 4 ? 'MEDIUM PRIORITY' : 'LOW PRIORITY',
              style: AppTextStyles.bodyBold.copyWith(color: pc, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text('Reason: $reason', style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10)),
          ])),
          _statusBadge(_status),
        ])),
        const SizedBox(height: 14),

        // ── Info grid ─────────────────────────────────────────────────────────
        _card(child: Column(children: [
          _infoRow(Icons.menu_book_outlined, 'Subject', subject, AppColors.info),
          _divider(),
          _infoRow(Icons.calendar_today_outlined, 'Date Missed', date, AppColors.textMuted),
          _divider(),
          _infoRow(Icons.star_outline_rounded, 'Exam Weightage', '${weight.toStringAsFixed(1)}%', AppColors.warning),
        ])),
        const SizedBox(height: 14),

        // ── Topic detail ──────────────────────────────────────────────────────
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MISSED TOPIC', style: AppTextStyles.label.copyWith(fontSize: 10)),
          const SizedBox(height: 10),
          Text(topic, style: AppTextStyles.bodyBold.copyWith(fontSize: 17)),
          if (subtopics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('SUBTOPICS COVERED', style: AppTextStyles.label.copyWith(fontSize: 10)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: subtopics.split(',').map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                ),
                child: Text(s.trim(),
                    style: AppTextStyles.mono.copyWith(color: AppColors.info, fontSize: 11)),
              )).toList(),
            ),
          ],
        ])),
        const SizedBox(height: 14),

        // ── Exam impact bar ───────────────────────────────────────────────────
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.assessment_outlined, color: AppColors.warning, size: 16),
            const SizedBox(width: 8),
            Text('EXAM IMPACT', style: AppTextStyles.label.copyWith(fontSize: 10)),
            const Spacer(),
            Text('${weight.toStringAsFixed(1)}%',
                style: AppTextStyles.monoBold.copyWith(color: AppColors.warning, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
            value: (weight / 10).clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            backgroundColor: AppColors.surfaceElevated,
            valueColor: AlwaysStoppedAnimation(weight >= 7 ? AppColors.error : AppColors.warning),
          )),
          const SizedBox(height: 8),
          Text(
            weight >= 7
                ? 'High impact — prioritize reviewing this topic before the exam.'
                : weight >= 4
                    ? 'Medium impact — review when possible.'
                    : 'Low impact — review when you have time.',
            style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 10),
          ),
        ])),
        const SizedBox(height: 28),

        // ── Action button ─────────────────────────────────────────────────────
        if (_status != 'reviewed')
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _marking ? null : _markReviewed,
              icon: _marking
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(_marking ? 'Marking...' : 'Mark as Reviewed',
                  style: AppTextStyles.button.copyWith(color: Colors.black, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green, foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          )
        else
          Container(
            width: double.infinity, height: 54,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Text('Reviewed — Gap Resolved',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.success, fontSize: 14)),
            ]),
          ),
      ]),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _infoRow(IconData icon, String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: AppColors.textMuted, size: 16),
      const SizedBox(width: 10),
      Text(label, style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 12)),
      const Spacer(),
      Text(value, style: AppTextStyles.monoBold.copyWith(color: color, fontSize: 12)),
    ]),
  );

  Widget _divider() => Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6));

  Widget _statusBadge(String status) {
    final reviewed = status == 'reviewed';
    final c = reviewed ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        reviewed ? '✓ REVIEWED' : '● OPEN',
        style: AppTextStyles.mono.copyWith(
            color: c, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}
