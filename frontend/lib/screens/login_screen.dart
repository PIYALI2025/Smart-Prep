import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _accessKeyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _accessKeyController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authProvider.notifier).login(
            _usernameController.text.trim(),
            _accessKeyController.text,
          );
    }
  }

  void _fillPreset(String username, String key) {
    _usernameController.text = username;
    _accessKeyController.text = key;
    ref.read(authProvider.notifier).clearError();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _buildBrandHeader(),
                const SizedBox(height: 36),
                _buildFormCard(authState),
                const SizedBox(height: 20),
                _buildQuickPresetButtons(),
                const SizedBox(height: 24),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Brand header: flask icon + glowing "Smart Prep" ----------------
  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.green.withValues(alpha: 0.08),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.35),
                blurRadius: 45,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Icon(
            Icons.science_outlined,
            color: AppColors.greenGlow,
            size: 46,
            shadows: [
              Shadow(color: AppColors.green.withValues(alpha: 0.8), blurRadius: 18),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          "Smart Prep",
          textAlign: TextAlign.center,
          style: AppTextStyles.heading.copyWith(
            fontSize: 38,
            color: AppColors.greenGlow,
            shadows: [
              Shadow(color: AppColors.green.withValues(alpha: 0.6), blurRadius: 22),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "RADAR ACCESS CONSOLE",
          textAlign: TextAlign.center,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }

  // ---------------- Glass form card ----------------
  Widget _buildFormCard(AuthState authState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fieldLabel("Username"),
            const SizedBox(height: 8),
            _pillField(
              controller: _usernameController,
              hint: "Enter identification code",
              icon: Icons.person_outline_rounded,
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Username is required" : null,
            ),
            const SizedBox(height: 20),
            _fieldLabel("Access Key"),
            const SizedBox(height: 8),
            _pillField(
              controller: _accessKeyController,
              hint: "Enter secure key",
              icon: Icons.vpn_key_outlined,
              obscure: _obscureKey,
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                  size: 19,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? "Access key is required" : null,
              onSubmit: (_) => _submit(),
            ),
            if (authState.errorMessage != null) ...[
              const SizedBox(height: 16),
              _errorBanner(authState.errorMessage!),
            ],
            const SizedBox(height: 28),
            _loginButton(authState.isLoading),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.surfaceElevated,
                      content: Text(
                        "Contact your system administrator for access recovery.",
                        style: AppTextStyles.body.copyWith(color: AppColors.textMain),
                      ),
                    ),
                  );
                },
                child: Text(
                  "Forgot Access Key?",
                  style: AppTextStyles.mono.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.body.copyWith(
        color: AppColors.greenGlow,
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
    );
  }

  Widget _pillField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
    void Function(String)? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: AppTextStyles.mono.copyWith(color: AppColors.textMain, fontSize: 13),
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmit,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.green, size: 19),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.bg.withValues(alpha: 0.85),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.green.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.green.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.error, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Quick fill presets for testing ----------------
  Widget _buildQuickPresetButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Quick Login:",
          style: AppTextStyles.mono.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        _presetChip("Teacher", () => _fillPreset("teacher_1", "teacher123")),
        const SizedBox(width: 8),
        _presetChip("Student", () => _fillPreset("student_1", "student123")),
      ],
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
          color: AppColors.surfaceElevated.withValues(alpha: 0.6),
        ),
        child: Text(
          label,
          style: AppTextStyles.mono.copyWith(
            color: AppColors.greenGlow,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // ---------------- Pill-shaped glowing "Log in" button ----------------
  Widget _loginButton(bool isLoading) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
              )
            : Text(
                "Log in",
                style: AppTextStyles.button.copyWith(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  // ---------------- Footer ----------------
  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          "© 2026 Smart Prep Systems",
          textAlign: TextAlign.center,
          style: AppTextStyles.mono.copyWith(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "PRIVACY PROTOCOL",
              style: AppTextStyles.mono.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              "SYSTEM STATUS: ONLINE",
              style: AppTextStyles.mono.copyWith(
                color: AppColors.green,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}