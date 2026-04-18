import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/social_login_buttons.dart';
import '../../../../core/providers/monetization_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).signUpWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
    );

    if (mounted) {
      final authState = ref.read(authNotifierProvider);
      if (authState.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.error.toString()),
            backgroundColor: context.colors.error,
          ),
        );
      } else {
        context.goNamed(RouteNames.scanner);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        ref.read(subscriptionServiceProvider).logIn(next.value!.id);
        if (mounted) context.go('/scanner');
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final l10n = context.l10n;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // Top glow
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Back button
                    IconButton(
                      onPressed: () => context.go('/login'),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: context.colors.textPrimary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 32),

                    // Heading
                    Text(
                      l10n.createAccount,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.startHealthyJourney,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.colors.textMuted,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Full name
                    _buildLabel(l10n.fullName),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Ad Soyad',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l10n.enterName;
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Email
                    _buildLabel(l10n.email),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'ornek@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l10n.enterEmail;
                        if (!v.contains('@')) return l10n.validEmail;
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Password
                    _buildLabel(l10n.password),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l10n.enterPassword;
                        if (v.length < 6) return l10n.passwordMinLength;
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Confirm password
                    _buildLabel(l10n.confirmPassword),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (v) {
                        if (v != _passwordController.text) {
                          return l10n.passwordsDoNotMatch;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Register button
                    GestureDetector(
                      onTap: isLoading ? null : _handleRegister,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: isLoading ? null : context.colors.primaryGradient,
                          color: isLoading ? context.colors.surfaceCard2 : null,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: isLoading
                              ? []
                              : [
                                  BoxShadow(
                                    color: context.colors.primary.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: isLoading
                            ? SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: context.colors.primary,
                                ),
                              )
                            : Text(
                                l10n.signUp,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: context.colors.border)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'ya da',
                            style: TextStyle(
                              color: context.colors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: context.colors.border)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const SocialLoginButtons(),

                    const SizedBox(height: 32),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Zaten hesabın var mı?',
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            'Giriş yap',
                            style: TextStyle(
                              color: context.colors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: context.colors.textSecondary,
      letterSpacing: 0.2,
    ),
  );
}