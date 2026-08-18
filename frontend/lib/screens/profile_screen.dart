import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final classId = ref.watch(selectedClassIdProvider);
    final section = ref.watch(selectedSectionProvider);

    return ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 16),
      Center(child: Container(width: 88, height: 88,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: AppColors.green.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.5), width: 2)),
        child: Center(child: Text(
          (user != null && user.username.isNotEmpty) ? user.username[0].toUpperCase() : '?',
          style: AppTextStyles.heading.copyWith(fontSize: 36, color: AppColors.greenGlow))))),
      const SizedBox(height: 16),
      Center(child: Text(user?.username ?? 'User', style: AppTextStyles.subheading)),
      const SizedBox(height: 4),
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Text((user?.role ?? 'student').toUpperCase(),
            style: AppTextStyles.mono.copyWith(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.w700)))),
      const SizedBox(height: 32),
      _section('ACCOUNT INFO'),
      _infoTile(Icons.person_outline_rounded, 'Username', user?.username ?? '—'),
      _infoTile(Icons.email_outlined, 'Email', user?.email ?? '—'),
      _infoTile(Icons.badge_outlined, 'User ID', user?.id ?? '—'),
      const SizedBox(height: 24),
      _section('CLASS SETTINGS'),
      _editTile(context, ref, Icons.class_outlined, 'Class ID', classId,
          onEdit: (v) => ref.read(selectedClassIdProvider.notifier).state = v),
      _editTile(context, ref, Icons.sort_outlined, 'Section', section,
          onEdit: (v) => ref.read(selectedSectionProvider.notifier).state = v),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, height: 50,
        child: OutlinedButton.icon(
          onPressed: () => _confirmLogout(context, ref),
          icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
          label: Text('Logout', style: AppTextStyles.body.copyWith(color: AppColors.error)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    ]);
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Text(t, style: AppTextStyles.label.copyWith(fontSize: 11)));

  Widget _infoTile(IconData icon, String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Icon(icon, color: AppColors.textMuted, size: 18), const SizedBox(width: 12),
      Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textMuted, fontSize: 13))),
      Text(value, style: AppTextStyles.monoBold.copyWith(color: AppColors.textMain, fontSize: 12)),
    ]),
  );

  Widget _editTile(BuildContext ctx, WidgetRef ref, IconData icon, String label, String value,
      {required void Function(String) onEdit}) {
    return Container(margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final ctrl = TextEditingController(text: value);
          final result = await showDialog<String>(context: ctx, builder: (_) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: Text('Edit $label', style: AppTextStyles.subheading.copyWith(fontSize: 16)),
            content: TextField(controller: ctrl, style: AppTextStyles.body,
                decoration: InputDecoration(labelText: label)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
            ],
          ));
          if (result != null && result.isNotEmpty) onEdit(result);
        },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: AppColors.surfaceSolid, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Icon(icon, color: AppColors.textMuted, size: 18), const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textMuted, fontSize: 13))),
            Text(value, style: AppTextStyles.monoBold.copyWith(color: AppColors.greenGlow, fontSize: 12)),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, color: AppColors.textDisabled, size: 14),
          ]),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext ctx, WidgetRef ref) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border)),
      title: Text('Confirm Logout', style: AppTextStyles.subheading.copyWith(fontSize: 18)),
      content: Text('End your current session?', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.mono.copyWith(color: AppColors.textMuted))),
        ElevatedButton(
          onPressed: () { Navigator.pop(ctx); ref.read(authProvider.notifier).logout(); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
          child: const Text('Logout'),
        ),
      ],
    ));
  }
}
