import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../services/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/background/animated_background.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Login screen — uses the existing [authProvider] (POST /auth/login).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  static final RegExp _emailPattern =
      RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _friendlyError(ApiException e) {
    if (e.isNetworkError) {
      return 'No connection to the server. Please check your network.';
    }
    return switch (e.statusCode) {
      401 => 'Invalid email or password.',
      403 => 'This account is blocked. Contact support.',
      _ => e.message,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;
      context.go('/');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unexpected error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to manage your devices and keys',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GlassContainer(
                        borderRadius: BorderRadius.circular(22),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  size: 20,
                                ),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) {
                                  return 'Enter your email';
                                }
                                if (!_emailPattern.hasMatch(email)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'Enter your password'
                                      : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            GlassButton(
                              label: 'Sign in',
                              icon: Icons.login_rounded,
                              loading: _loading,
                              onTap: _submit,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: const Text(
                          'Continue as guest',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Flexible(
                            child: Text(
                              "Don't have an account?",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text(
                              'Create account',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBright,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
