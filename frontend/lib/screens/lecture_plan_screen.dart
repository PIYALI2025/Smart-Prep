import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/attendance_service.dart';
import '../services/lecture_service.dart';
import '../theme/app_theme.dart';

/// Combined Lecture Plan screen:
///  - Students: view lecture plan entries (topic, subject, date, section)
///  - Mentors/Teachers: view + upload new syllabus topics via POST /api/v1/lecture-plan/upload
class LecturePlanScreen extends ConsumerStatefulWidget {
  const LecturePlanScreen({super.key});

  @override
  ConsumerState<LecturePlanScreen> createState() => _LecturePlanScreenState();
}

class _LecturePlanScreenState extends ConsumerState<LecturePlanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _plans = [];
  bool _loading = true;
  String? _err;
  String? _filterSubject;
  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    final isMentor = _isMentor;
    _tabs = TabController(length: isMentor ? 2 : 1, vsync: this);
    _loadPlans();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _isMentor {
    final role = (ref.read(authProvider).user?.role ?? '').toLowerCase();
    return role == 'mentor' || role == 'teacher';
  }

  Future<void> _loadPlans() async {
    setState(() { _loading = true; _err = null; });
    final cid = ref.read(selectedClassIdProvider);
    final section = ref.read(selectedSectionProvider);
    try {
      _plans = await AttendanceService().getLecturePlans(cid, section);
      final Set<String> seen = {};
      for (final p in _plans) {
        final sub = (p as Map)['subject_name']?.toString() ?? '';
        if (sub.isNotEmpty) seen.add(sub);
      }
      _subjects = seen.toList()..sort();
    } catch (e) {
      _err = 'Could not load lecture plans. Please try again.';
      _plans = [];
      _subjects = [];
    }
    if (mounted) setState(() => _loading = false);
  }



  List<dynamic> get _filtered => _filterSubject == null
      ? _plans
      : _plans.where((p) =>
          (p as Map)['subject_name']?.toString() == _filterSubject).toList();

  @override
  Widget build(BuildContext context) {
    final isMentor = _isMentor;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceSolid,
        iconTheme: const IconThemeData(color: AppColors.green),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Lecture Plans',
              style: AppTextStyles.subheading.copyWith(fontSize: 16)),
          Text('${_filtered.length} entries',
              style: AppTextStyles.mono
                  .copyWith(color: AppColors.textMuted, fontSize: 10)),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _loadPlans),
        ],
        bottom: isMentor
            ? TabBar(
                controller: _tabs,
                labelColor: AppColors.green,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.green,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: AppTextStyles.mono.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'VIEW PLANS'),
                  Tab(text: 'UPLOAD SYLLABUS'),
                ],
              )
            : null,
      ),
      body: isMentor
          ? TabBarView(controller: _tabs, children: [
              _planListView(),
              const _UploadSyllabusView(),
            ])
          : _planListView(),
    );
  }

  Widget _planListView() => Column(children: [
    // Subject filter
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
                () => setState(
                    () => _filterSubject = _filterSubject == s ? null : s))),
          ]),
        ),
      ),
    Expanded(
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green))
          : _err != null && _plans.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 44),
                    const SizedBox(height: 12),
                    Text(_err!,
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.error)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: _loadPlans, child: const Text('Retry')),
                  ]),
                )
              : _filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.library_books_outlined,
                            color: AppColors.textDisabled, size: 52),
                        const SizedBox(height: 14),
                        Text('No lecture plans found',
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textMuted)),
                      ]),
                    )
                  : RefreshIndicator(
                      color: AppColors.green,
                      backgroundColor: AppColors.surfaceSolid,
                      onRefresh: _loadPlans,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _planTile(_filtered[i] as Map<String, dynamic>),
                      ),
                    ),
    ),
  ]);

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.green.withValues(alpha: 0.15) : AppColors.surfaceElevated,
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

  Widget _planTile(Map<String, dynamic> plan) {
    final topic = plan['topic']?.toString() ?? '';
    final subject = plan['subject_name']?.toString() ?? '';
    final subtopics = plan['subtopics']?.toString() ?? '';
    final date = plan['date']?.toString() ?? '';
    final weight = (plan['exam_weightage'] ?? 5.0) as num;
    final wColor = weight >= 7
        ? AppColors.error
        : weight >= 4
            ? AppColors.warning
            : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(topic,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: wColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('⭐ ${weight.toStringAsFixed(1)}%',
                  style: AppTextStyles.mono
                      .copyWith(color: wColor, fontSize: 10)),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _tag(subject, AppColors.info),
            const SizedBox(width: 8),
            _tag(date, AppColors.textDisabled),
          ]),
          if (subtopics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtopics,
                style: AppTextStyles.mono
                    .copyWith(color: AppColors.textMuted, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4)),
    child: Text(text,
        style: AppTextStyles.mono.copyWith(color: color, fontSize: 10)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload Syllabus sub-view (mentor only)
// POST /api/v1/lecture-plan/upload
// ─────────────────────────────────────────────────────────────────────────────

class _UploadSyllabusView extends ConsumerStatefulWidget {
  const _UploadSyllabusView();

  @override
  ConsumerState<_UploadSyllabusView> createState() =>
      _UploadSyllabusViewState();
}

class _UploadSyllabusViewState
    extends ConsumerState<_UploadSyllabusView> {
  final _subjectCtrl = TextEditingController();
  final List<_TopicRow> _topicRows = [_TopicRow()];
  bool _submitting = false;
  String? _err, _success;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    for (final r in _topicRows) r.dispose();
    super.dispose();
  }

  void _addRow() => setState(() => _topicRows.add(_TopicRow()));
  void _removeRow(int i) {
    if (_topicRows.length > 1) {
      _topicRows[i].dispose();
      setState(() => _topicRows.removeAt(i));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _err = null; _success = null; });
    final cid = ref.read(selectedClassIdProvider);
    final topics = _topicRows.asMap().entries.map((e) => {
      'topic_number': e.key + 1,
      'topic_title': e.value.titleCtrl.text.trim(),
      'description': e.value.descCtrl.text.trim().isEmpty
          ? null
          : e.value.descCtrl.text.trim(),
    }).toList();
    try {
      final res = await LectureService().uploadLecturePlan(
        classId: cid,
        subjectName: _subjectCtrl.text.trim(),
        topics: topics.cast<Map<String, dynamic>>(),
      );
      setState(() =>
          _success = res['message']?.toString() ?? 'Upload successful!');
    } on DioException catch (e) {
      setState(() =>
          _err = e.response?.data?['detail']?.toString() ?? 'Upload failed.');
    } catch (e) {
      setState(() => _err = 'An error occurred.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cid = ref.watch(selectedClassIdProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.info, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Uploading for class: $cid. Topics will be upserted — existing topic numbers will be updated.',
                  style: AppTextStyles.mono
                      .copyWith(color: AppColors.info, fontSize: 11),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _label('SUBJECT NAME'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _subjectCtrl,
            style: AppTextStyles.body.copyWith(fontSize: 14),
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Subject is required' : null,
            decoration: const InputDecoration(
              hintText: 'e.g. Mathematics',
              prefixIcon: Icon(Icons.menu_book_outlined,
                  color: AppColors.textMuted, size: 18),
            ),
          ),
          const SizedBox(height: 24),
          _label('TOPICS (${_topicRows.length})'),
          const SizedBox(height: 10),
          ..._topicRows.asMap().entries.map((e) => _buildTopicRow(e.key, e.value)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Topic'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.greenGlow,
              side: BorderSide(color: AppColors.green.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 16),
            _banner(_err!, AppColors.error, Icons.error_outline_rounded),
          ],
          if (_success != null) ...[
            const SizedBox(height: 16),
            _banner(_success!, AppColors.success,
                Icons.check_circle_outline_rounded),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.cloud_upload_outlined, size: 20),
              label: Text(
                  _submitting
                      ? 'Uploading...'
                      : 'Upload ${_topicRows.length} Topic(s)',
                  style: AppTextStyles.button
                      .copyWith(color: Colors.black, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green, foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopicRow(int idx, _TopicRow row) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceSolid,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.green.withValues(alpha: 0.12),
          ),
          child: Center(
            child: Text('${idx + 1}',
                style: AppTextStyles.monoBold
                    .copyWith(color: AppColors.greenGlow, fontSize: 12)),
          ),
        ),
        const Spacer(),
        if (_topicRows.length > 1)
          GestureDetector(
            onTap: () => _removeRow(idx),
            child: const Icon(Icons.remove_circle_outline,
                color: AppColors.error, size: 20),
          ),
      ]),
      const SizedBox(height: 10),
      TextFormField(
        controller: row.titleCtrl,
        style: AppTextStyles.body.copyWith(fontSize: 13),
        validator: (v) =>
            (v?.trim().isEmpty ?? true) ? 'Title required' : null,
        decoration: const InputDecoration(
          labelText: 'Topic Title',
          hintText: 'e.g. Quadratic Equations',
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: row.descCtrl,
        style: AppTextStyles.body.copyWith(fontSize: 13),
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Description (optional)',
          hintText: 'Key concepts, subtopics...',
        ),
      ),
    ]),
  );

  Widget _label(String t) =>
      Text(t, style: AppTextStyles.label.copyWith(fontSize: 11));

  Widget _banner(String msg, Color c, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.withValues(alpha: 0.35)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: c, size: 18),
      const SizedBox(width: 10),
      Expanded(
          child: Text(msg,
              style: AppTextStyles.mono.copyWith(color: c, fontSize: 11))),
    ]),
  );
}

class _TopicRow {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
  }
}
