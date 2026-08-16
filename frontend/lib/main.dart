import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SmartPrepApp(),
    ),
  );
}

class SmartPrepApp extends StatelessWidget {
  const SmartPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart-Prep | Gap Radar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

/// AuthGate observes AuthState to seamlessly switch between Login and Home
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Initial session restoration state
    if (authState.isLoading && authState.user == null && authState.errorMessage == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.green.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.radar,
                  color: AppColors.greenGlow,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "CONNECTING TO RADAR...",
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (authState.isAuthenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
