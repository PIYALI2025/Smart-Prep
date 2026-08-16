import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceSolid,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.green.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.radar, color: AppColors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              "Smart-Prep Radar",
              style: AppTextStyles.subheading.copyWith(
                color: AppColors.greenGlow,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: "Logout",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  title: Text(
                    "Confirm Disconnect",
                    style: AppTextStyles.subheading.copyWith(fontSize: 18),
                  ),
                  content: Text(
                    "Are you sure you want to end your current session?",
                    style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        "Cancel",
                        style: AppTextStyles.mono.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ref.read(authProvider.notifier).logout();
                      },
                      child: const Text("Logout"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Status Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSolid,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.green.withValues(alpha: 0.2),
                          child: Text(
                            (user?.username.isNotEmpty ?? false)
                                ? user!.username[0].toUpperCase()
                                : 'U',
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 22,
                              color: AppColors.greenGlow,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.username ?? "Active User",
                                style: AppTextStyles.subheading.copyWith(
                                  color: AppColors.textMain,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.green.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      (user?.role ?? 'USER').toUpperCase(),
                                      style: AppTextStyles.monoBold.copyWith(
                                        color: AppColors.greenGlow,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "ONLINE",
                                    style: AppTextStyles.mono.copyWith(
                                      color: AppColors.green,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 12),
                    Text(
                      "SESSION TOKEN IDENTIFIER",
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.token ?? "N/A",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mono.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                "SYSTEM MODULES",
                style: AppTextStyles.label.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
                children: [
                  _buildModuleCard(
                    icon: Icons.calendar_month_outlined,
                    title: "Attendance",
                    subtitle: "Routine & Records",
                    status: "Connected",
                    color: AppColors.green,
                  ),
                  _buildModuleCard(
                    icon: Icons.radar_outlined,
                    title: "Gap Radar",
                    subtitle: "Analytics Matrix",
                    status: "Active",
                    color: AppColors.info,
                  ),
                  _buildModuleCard(
                    icon: Icons.auto_graph_rounded,
                    title: "Thresholds",
                    subtitle: "Target: 75%",
                    status: "Monitored",
                    color: AppColors.warning,
                  ),
                  _buildModuleCard(
                    icon: Icons.settings_suggest_outlined,
                    title: "Settings",
                    subtitle: "App & Hardware",
                    status: "Ready",
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyBold.copyWith(
                  fontSize: 15,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.mono.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
