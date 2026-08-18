import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../theme/app_theme.dart';
import 'student_dashboard.dart';
import 'mentor_dashboard.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'class_summary_screen.dart';
import 'lecture_plan_screen.dart';
import 'missed_lectures_screen.dart';

/// Root shell with role-aware bottom navigation.
///
/// Student tabs: Radar | Stats | Lectures | Profile
/// Mentor tabs:  Schedule | Students | Lectures | Profile
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _sel = 0;

  static const _studentTabs = [
    _NavTab(icon: Icons.radar_outlined,        activeIcon: Icons.radar,               label: 'Radar'),
    _NavTab(icon: Icons.bar_chart_outlined,    activeIcon: Icons.bar_chart_rounded,   label: 'Stats'),
    _NavTab(icon: Icons.library_books_outlined,activeIcon: Icons.library_books_rounded,label: 'Lectures'),
    _NavTab(icon: Icons.person_outline_rounded,activeIcon: Icons.person_rounded,      label: 'Profile'),
  ];

  static const _mentorTabs = [
    _NavTab(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Schedule'),
    _NavTab(icon: Icons.people_outline_rounded,  activeIcon: Icons.people_rounded,         label: 'Students'),
    _NavTab(icon: Icons.library_books_outlined,  activeIcon: Icons.library_books_rounded,  label: 'Lectures'),
    _NavTab(icon: Icons.person_outline_rounded,  activeIcon: Icons.person_rounded,         label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final role = (user?.role ?? 'student').toLowerCase();
    final isMentor = role == 'teacher' || role == 'mentor';
    final classId = ref.watch(selectedClassIdProvider);
    final section = ref.watch(selectedSectionProvider);

    final studentBodies = <Widget>[
      const StudentDashboard(),
      const StatsScreen(),
      // Students see: missed lectures tab (lecture_plan_screen in view mode)
      const _StudentLecturesTab(),
      const ProfileScreen(),
    ];

    final mentorBodies = <Widget>[
      const MentorDashboard(),
      ClassSummaryScreen(classId: classId, section: section),
      // Mentors see: full lecture plan screen with upload tab
      const LecturePlanScreen(),
      const ProfileScreen(),
    ];

    final tabs = isMentor ? _mentorTabs : _studentTabs;
    final bodies = isMentor ? mentorBodies : studentBodies;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(user, isMentor),
      body: SafeArea(
        child: IndexedStack(
          index: _sel.clamp(0, bodies.length - 1),
          children: bodies,
        ),
      ),
      bottomNavigationBar: _bottomNav(tabs),
    );
  }

  PreferredSizeWidget _appBar(dynamic user, bool isMentor) => AppBar(
    backgroundColor: AppColors.surfaceSolid,
    elevation: 0,
    titleSpacing: 16,
    title: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.green.withValues(alpha: 0.15),
        ),
        child: const Icon(Icons.radar, color: AppColors.green, size: 20),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Smart-Prep',
            style: AppTextStyles.subheading
                .copyWith(color: AppColors.greenGlow, fontSize: 16)),
        Text(
          isMentor ? 'MENTOR CONSOLE' : 'STUDENT CONSOLE',
          style: AppTextStyles.mono.copyWith(
              color: AppColors.textMuted, fontSize: 9, letterSpacing: 1.5),
        ),
      ]),
    ]),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.green.withValues(alpha: 0.2),
            child: Text(
              (user?.username?.isNotEmpty ?? false)
                  ? user!.username[0].toUpperCase()
                  : 'U',
              style: AppTextStyles.monoBold
                  .copyWith(fontSize: 10, color: AppColors.greenGlow),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            user?.username ?? 'User',
            style: AppTextStyles.mono
                .copyWith(color: AppColors.textMain, fontSize: 11),
          ),
        ]),
      ),
    ],
  );

  Widget _bottomNav(List<_NavTab> tabs) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surfaceSolid,
      border: Border(top: BorderSide(color: AppColors.border, width: 1)),
    ),
    child: SafeArea(
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final i = e.key;
          final tab = e.value;
          final active = _sel == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _sel = i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 2,
                    width: active ? 24 : 0,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Icon(
                    active ? tab.activeIcon : tab.icon,
                    color: active ? AppColors.green : AppColors.textDisabled,
                    size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tab.label,
                    style: AppTextStyles.mono.copyWith(
                      fontSize: 9,
                      color: active ? AppColors.green : AppColors.textDisabled,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

/// Student Lectures tab — combines Missed Lectures + Lecture Plan viewer.
class _StudentLecturesTab extends ConsumerStatefulWidget {
  const _StudentLecturesTab();

  @override
  ConsumerState<_StudentLecturesTab> createState() =>
      _StudentLecturesTabState();
}

class _StudentLecturesTabState extends ConsumerState<_StudentLecturesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: AppColors.surfaceSolid,
      child: TabBar(
        controller: _tabs,
        labelColor: AppColors.green,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.green,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppTextStyles.mono
            .copyWith(fontSize: 11, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'MISSED TOPICS'),
          Tab(text: 'SYLLABUS'),
        ],
      ),
    ),
    Expanded(
      child: TabBarView(controller: _tabs, children: [
        const MissedLecturesScreen(),
        const LecturePlanScreen(),
      ]),
    ),
  ]);
}

class _NavTab {
  final IconData icon, activeIcon;
  final String label;
  const _NavTab(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}
