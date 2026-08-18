import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _State();
}

class _State extends ConsumerState<RegisterScreen> with SingleTickerProviderStateMixin {
  bool _isMentor = false;
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _boardCtrl = TextEditingController();
  final _standardCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _mentorBoardCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  String _institutionType = 'School';
  DateTime? _dob;
  TimeOfDay _studyStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _studyEnd = const TimeOfDay(hour: 11, minute: 0);
  bool _loading = false, _obscurePass = true, _obscureConfirm = true;
  String? _errMsg;
  final _formKey = GlobalKey<FormState>();
  late AnimationController _pulse;
  late Animation<double> _anim;
  static const _instTypes = ['School', 'College', 'University', 'Self'];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    for (final c in [_usernameCtrl,_emailCtrl,_passCtrl,_confirmCtrl,_boardCtrl,
                     _standardCtrl,_institutionCtrl,_mentorBoardCtrl,_subjectCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errMsg = null);
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) { setState(() => _errMsg = 'Passwords do not match.'); return; }
    setState(() => _loading = true);
    try {
      final api = ApiService().dio;
      if (_isMentor) {
        await api.post('/auth/mentor/register', data: {
          'username': _usernameCtrl.text.trim(), 'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text, 'institution': _institutionCtrl.text.trim(),
          'board': _mentorBoardCtrl.text.trim(), 'subject': _subjectCtrl.text.trim(),
        });
      } else {
        await api.post('/auth/student/register', data: {
          'username': _usernameCtrl.text.trim(), 'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
          'dob': _dob != null
              ? '${_dob!.year}-${_dob!.month.toString().padLeft(2,'0')}-${_dob!.day.toString().padLeft(2,'0')}'
              : '2000-01-01',
          'institution_type': _institutionType, 'board': _boardCtrl.text.trim(),
          'standard': _standardCtrl.text.trim(),
          'time_start': '${_studyStart.hour.toString().padLeft(2,'0')}:${_studyStart.minute.toString().padLeft(2,'0')}:00',
          'time_end': '${_studyEnd.hour.toString().padLeft(2,'0')}:${_studyEnd.minute.toString().padLeft(2,'0')}:00',
        });
      }
      if (mounted) _showSuccess();
    } on DioException catch (e) {
      setState(() => _errMsg = e.response?.data?['detail']?.toString() ?? 'Registration failed.');
    } catch (e) {
      setState(() => _errMsg = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess() => showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
    backgroundColor: AppColors.surfaceElevated,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.green.withValues(alpha: 0.5))),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 8),
      Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppColors.green.withValues(alpha: 0.15)),
          child: const Icon(Icons.check_rounded, color: AppColors.green, size: 36)),
      const SizedBox(height: 20),
      Text('Account Created!', style: AppTextStyles.subheading.copyWith(color: AppColors.greenGlow), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('Your account has been registered.', style: AppTextStyles.body.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () { Navigator.pop(context); Navigator.pop(context); },
          child: const Text('Go to Login'))),
    ]),
  ));

  Future<void> _pickDob() async {
    final p = await showDatePicker(context: context,
        initialDate: _dob ?? DateTime(2005), firstDate: DateTime(1980),
        lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
        builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(
            primary: AppColors.green, surface: AppColors.surfaceElevated)), child: child!));
    if (p != null) setState(() => _dob = p);
  }

  Future<void> _pickTime(bool isStart) async {
    final p = await showTimePicker(context: context, initialTime: isStart ? _studyStart : _studyEnd,
        builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(
            primary: AppColors.green, surface: AppColors.surfaceElevated, onSurface: AppColors.textMain)), child: child!));
    if (p != null) setState(() => isStart ? _studyStart = p : _studyEnd = p);
  }

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Stack(children: [
      Positioned(top: -120, right: -80, child: AnimatedBuilder(animation: _anim, builder: (_, __) => Container(
          width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.green.withValues(alpha: _anim.value * 0.08), Colors.transparent]))))),
      SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMuted, size: 18),
                onPressed: () => Navigator.pop(context)),
            const Spacer(),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle,
                    color: AppColors.green.withValues(alpha: 0.12)),
                child: const Icon(Icons.radar, color: AppColors.green, size: 22)),
          ])),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Create Account', style: AppTextStyles.heading.copyWith(fontSize: 28)),
            const SizedBox(height: 4),
            Text('Join Smart-Prep Gap Radar', style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 28),
            _roleToggle(), const SizedBox(height: 28),
            _label('ACCOUNT DETAILS'), const SizedBox(height: 12),
            _field(_usernameCtrl, 'Username', 'e.g. priya_student', Icons.person_outline_rounded,
                v: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
            const SizedBox(height: 14),
            _field(_emailCtrl, 'Email', 'you@example.com', Icons.email_outlined, type: TextInputType.emailAddress,
                v: (v) => (v?.contains('@') ?? false) ? null : 'Invalid email'),
            const SizedBox(height: 14),
            _passField(_passCtrl, 'Password', _obscurePass, () => setState(() => _obscurePass = !_obscurePass),
                v: (v) => (v?.length ?? 0) < 6 ? 'Min 6 chars' : null),
            const SizedBox(height: 14),
            _passField(_confirmCtrl, 'Confirm Password', _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm),
                v: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
            const SizedBox(height: 28),
            AnimatedSwitcher(duration: const Duration(milliseconds: 300),
                child: _isMentor ? _mentorFields() : _studentFields()),
            if (_errMsg != null) ...[const SizedBox(height: 16), _errBanner(_errMsg!)],
            const SizedBox(height: 28),
            SizedBox(width: double.infinity, height: 54,
              child: ElevatedButton(onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : Text(_isMentor ? 'CREATE MENTOR ACCOUNT' : 'CREATE STUDENT ACCOUNT',
                        style: AppTextStyles.button.copyWith(color: Colors.black, fontSize: 14, letterSpacing: 0.8)))),
            const SizedBox(height: 20),
            Center(child: GestureDetector(onTap: () => Navigator.pop(context),
                child: RichText(text: TextSpan(
                    text: 'Already have an account? ', style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 12),
                    children: [TextSpan(text: 'Sign In', style: AppTextStyles.monoBold.copyWith(color: AppColors.greenGlow, fontSize: 12))])))),
          ])),
        )),
      ])),
    ]),
  );

  Widget _roleToggle() => Container(height: 52, padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
    child: Row(children: [
      _roleTab('STUDENT', Icons.school_outlined, !_isMentor, () => setState(() => _isMentor = false)),
      _roleTab('MENTOR', Icons.co_present_outlined, _isMentor, () => setState(() => _isMentor = true)),
    ]),
  );

  Widget _roleTab(String l, IconData i, bool sel, VoidCallback onTap) => Expanded(
    child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(color: sel ? AppColors.green.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10), border: sel ? Border.all(color: AppColors.green.withValues(alpha: 0.5)) : null),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(i, size: 16, color: sel ? AppColors.greenGlow : AppColors.textDisabled),
        const SizedBox(width: 6),
        Text(l, style: AppTextStyles.mono.copyWith(color: sel ? AppColors.greenGlow : AppColors.textDisabled,
            fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, letterSpacing: 1.0)),
      ]),
    )),
  );

  Widget _studentFields() => Column(key: const ValueKey('s'), crossAxisAlignment: CrossAxisAlignment.start, children: [
    _label('ACADEMIC INFO'), const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: _institutionType, dropdownColor: AppColors.surfaceElevated,
        style: AppTextStyles.body.copyWith(fontSize: 14),
        decoration: InputDecoration(labelText: 'Institution Type',
            prefixIcon: const Icon(Icons.domain_outlined, color: AppColors.textMuted, size: 18)),
        items: _instTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _institutionType = v ?? 'School')),
    const SizedBox(height: 14),
    _field(_boardCtrl, 'Board / University', 'e.g. CBSE, Mumbai University', Icons.account_balance_outlined,
        v: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
    const SizedBox(height: 14),
    _field(_standardCtrl, 'Class / Semester', 'e.g. 10, Sem-3', Icons.class_outlined,
        v: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
    const SizedBox(height: 14),
    _tapField('Date of Birth', _dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Tap to select',
        Icons.cake_outlined, _pickDob, placeholder: _dob == null),
    const SizedBox(height: 22),
    _label('STUDY SCHEDULE'), const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _tapField('Study Start', _fmtTime(_studyStart), Icons.access_time_rounded, () => _pickTime(true))),
      const SizedBox(width: 12),
      Expanded(child: _tapField('Study End', _fmtTime(_studyEnd), Icons.access_time_filled_rounded, () => _pickTime(false))),
    ]),
  ]);

  Widget _mentorFields() => Column(key: const ValueKey('m'), crossAxisAlignment: CrossAxisAlignment.start, children: [
    _label('INSTITUTION INFO'), const SizedBox(height: 12),
    _field(_institutionCtrl, 'Institution Name', 'e.g. Delhi Public School', Icons.business_outlined,
        v: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
    const SizedBox(height: 14),
    _field(_mentorBoardCtrl, 'Board / Affiliation', 'e.g. CBSE', Icons.account_balance_outlined,
        v: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
    const SizedBox(height: 14),
    _field(_subjectCtrl, 'Primary Subject', 'e.g. Mathematics', Icons.menu_book_outlined,
        v: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
  ]);

  Widget _label(String t) => Text(t, style: AppTextStyles.label.copyWith(fontSize: 11));

  Widget _field(TextEditingController c, String label, String hint, IconData icon,
      {TextInputType type = TextInputType.text, String? Function(String?)? v}) => TextFormField(
    controller: c, keyboardType: type, style: AppTextStyles.body.copyWith(fontSize: 14), validator: v,
    decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18)));

  Widget _passField(TextEditingController c, String label, bool obscure, VoidCallback toggle,
      {String? Function(String?)? v}) => TextFormField(
    controller: c, obscureText: obscure, style: AppTextStyles.body.copyWith(fontSize: 14), validator: v,
    decoration: InputDecoration(labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 18),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textMuted, size: 18), onPressed: toggle)));

  Widget _tapField(String label, String value, IconData icon, VoidCallback onTap, {bool placeholder = false}) =>
    GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.25))),
      child: Row(children: [
        Icon(icon, color: AppColors.textMuted, size: 18), const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.mono.copyWith(color: AppColors.greenGlow, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.body.copyWith(color: placeholder ? AppColors.textMuted : AppColors.textMain, fontSize: 14)),
        ]),
        const Spacer(),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled, size: 18),
      ]),
    ));

  Widget _errBanner(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18), const SizedBox(width: 8),
      Expanded(child: Text(msg, style: AppTextStyles.mono.copyWith(color: AppColors.error, fontSize: 11))),
    ]),
  );
}
