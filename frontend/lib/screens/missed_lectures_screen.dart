import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/lecture_service.dart';
import '../theme/app_theme.dart';

/// Lists all topics the student missed (from lecture_router.py):
///   GET /api/v1/lecture-plan/missed/{student_id}
/// Grouped by subject, sorted by topic_number.
class MissedLecturesScreen extends ConsumerStatefulWidget {
  const MissedLecturesScreen({super.key});

  @override
  ConsumerState<MissedLecturesScreen> createState() =>
      _MissedLecturesScreenState();
}

class _MissedLecturesScreenState
    extends ConsumerState<MissedLecturesScreen> {
  List<dynamic> _missed = [];
  bool _loading = true;
  String? _err;
  String? _filterSubject;
  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    final user = ref.read(authProvider).user;
    final sid = user?.id ?? '';
    try {
      _missed = await LectureService().getMissedLectures(sid);
      // Collect subjects
      final Set<String> seen = {};
      for (final m in _missed) {
        final sub = (m as Map)['subject_name']?.toString() ?? '';
        if (sub.isNotEmpty) seen.add(sub);
      }
      _subjects = seen.toList()..sort();
    } catch (e) {
      _err = 'Could not load missed lectures. Please try again.';
      _missed = [];
      _subjects = [];
    }
    if (mounted) setState(() => _loading = false);
  }



  List<dynamic> get _filtered => _filterSubject == null
      ? _missed
      : _missed.where((m) =>
          (m as Map)['subject_name']?.toString() == _filterSubject).toList();

  // Group by subject
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final Map<String, List<Map<String, dynamic>>> g = {};
    for (final item in _filtered) {
      final m = item as Map<String, dynamic>;
      final sub = m['subject_name']?.toString() ?? 'Unknown';
      g.putIfAbsent(sub, () => []).add(m);
    }
    // Sort each group by topic_number
    for (final key in g.keys) {
      g[key]!.sort((a, b) =>
          (a['topic_number'] as int? ?? 0)
              .compareTo(b['topic_number'] as int? ?? 0));
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceSolid,
        iconTheme: const IconThemeData(color: AppColors.green),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Missed Lectures',
              style: AppTextStyles.subheading.copyWith(fontSize: 16)),
          Text('${_filtered.length} topics to catch up',
              style: AppTextStyles.mono
                  .copyWith(color: AppColors.textMuted, fontSize: 10)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: Column(children: [
        // Filter chips
        if (_subjects.isNotEmpty)
          Container(
            color: AppColors.surfaceSolid,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SizedBox(
              height: 32,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _chip('All', _filterSubject == null,
                    () => setState(() => _filterSubject = null)),
                ..._subjects.map((s) => _chip(s, _filterSubject == s,
                    () => setState(() =>
                        _filterSubject = _filterSubject == s ? null : s))),
              ]),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.green))
              : _err != null && _missed.isEmpty
                  ? _errorState()
                  : _filtered.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: AppColors.green,
                          backgroundColor: AppColors.surfaceSolid,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            children: [

                              ...grouped.entries.map((entry) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _subjectHeader(entry.key, entry.value.length),
                                  const SizedBox(height: 8),
                                  ...entry.value.map(_topicTile),
                                  const SizedBox(height: 20),
                                ],
                              )),
                            ],
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.green.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? AppColors.green : AppColors.border,
              width: sel ? 1.5 : 1),
        ),
        child: Text(label,
            style: AppTextStyles.mono.copyWith(
                color: sel ? AppColors.greenGlow : AppColors.textMuted,
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
      ),
    ),
  );



  Widget _subjectHeader(String subject, int count) => Row(children: [
    Container(
      width: 8, height: 8,
      decoration: const BoxDecoration(
          shape: BoxShape.circle, color: AppColors.info),
    ),
    const SizedBox(width: 8),
    Text(subject.toUpperCase(),
        style: AppTextStyles.label.copyWith(fontSize: 11, color: AppColors.info)),
    const Spacer(),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text('$count topics',
          style: AppTextStyles.mono.copyWith(color: AppColors.info, fontSize: 10)),
    ),
  ]);

  Widget _topicTile(Map<String, dynamic> m) {
    final num = m['topic_number'] as int? ?? 0;
    final title = m['topic_title']?.toString() ?? '';
    final desc = m['description']?.toString() ?? '';
    final date = m['date']?.toString() ?? '';
    final period = m['period_name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Topic number badge
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              bottomLeft: Radius.circular(13),
            ),
          ),
          child: Center(
            child: Text('#$num',
                style: AppTextStyles.monoBold
                    .copyWith(color: AppColors.textMuted, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(desc,
                    style: AppTextStyles.mono
                        .copyWith(color: AppColors.textMuted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 10, color: AppColors.textDisabled),
                const SizedBox(width: 4),
                Text(date,
                    style: AppTextStyles.mono
                        .copyWith(color: AppColors.textDisabled, fontSize: 10)),
                if (period.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time_rounded,
                      size: 10, color: AppColors.textDisabled),
                  const SizedBox(width: 4),
                  Text(period,
                      style: AppTextStyles.mono.copyWith(
                          color: AppColors.textDisabled, fontSize: 10)),
                ],
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.book_outlined,
            color: AppColors.textDisabled, size: 18),
        const SizedBox(width: 12),
      ]),
    );
  }

  Widget _errorState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 44),
      const SizedBox(height: 12),
      Text(_err ?? 'Error',
          style: AppTextStyles.body.copyWith(color: AppColors.error),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: _load, child: const Text('Retry')),
    ]),
  );

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.menu_book_outlined,
          color: AppColors.textDisabled, size: 52),
      const SizedBox(height: 14),
      Text('No missed lectures',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: 6),
      Text('You have attended all covered topics!',
          style:
              AppTextStyles.mono.copyWith(color: AppColors.textDisabled, fontSize: 11)),
    ]),
  );
}
