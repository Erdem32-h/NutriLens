import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/analytics/failure_reason.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/cozy_header.dart';
import '../../../../core/widgets/cozy_tile.dart';
import '../providers/auth_provider.dart';
import '../providers/social_auth_tracking.dart';
import '../widgets/post_auth_flow.dart';
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

  /// Set to the registered email after a successful signup that requires
  /// email confirmation. While non-null we swap the form for a "check
  /// your inbox" banner with resend + back-to-login actions, instead of
  /// leaving the user staring at an unchanged form.
  String? _pendingConfirmationEmail;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(analyticsServiceProvider)
        .track(FunnelEvents.authScreenShown, props: {'screen': 'register'});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final analytics = ref.read(analyticsServiceProvider);
    // Before the validation gate on purpose. Everything downstream fires
    // only once the form is clean, so a visitor who taps and bounces off a
    // red field used to produce no event whatsoever — leaving "never found
    // the button" and "could not get past validation" as the same empty
    // row, with opposite fixes.
    analytics.track(
      FunnelEvents.registerSubmitTapped,
      props: {'method': AuthMethod.email},
    );
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    analytics.track(
      FunnelEvents.registerStarted,
      props: {'method': AuthMethod.email},
    );

    final failure = await ref
        .read(authNotifierProvider.notifier)
        .signUpWithEmail(
          email: email,
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );

    if (!mounted) return;
    if (failure != null) {
      analytics.track(
        FunnelEvents.registerFailed,
        props: {
          'method': AuthMethod.email,
          'reason': authFailureReason(failure),
        },
      );
    }
    if (failure is AlreadyRegisteredFailure) {
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.emailAlreadyRegistered),
          backgroundColor: context.colors.error,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l10n.signIn,
            textColor: Colors.white,
            onPressed: () => context.go('/login'),
          ),
        ),
      );
      return;
    }
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    // If "Confirm email" is ON in Supabase Auth, signUp succeeds but
    // creates the user with email_confirmed_at=null and does NOT emit
    // a session. authStateProvider stays empty, so runPostAuthFlow
    // never runs. Swap the form for the "check your inbox" banner so
    // the user gets feedback instead of a silent no-op.
    //
    // If confirmation is OFF, a session lands immediately, the
    // listener in build() picks it up and routes to /meals. We skip
    // showing the banner in that case.
    final hasSession =
        Supabase.instance.client.auth.currentSession != null;
    // `awaiting_confirmation` is the whole reason this event carries a prop.
    // A registration that lands here without a session has created a row in
    // auth.users — so it counts as an account in every server-side tally —
    // while the person is still outside the app and may never come back.
    // Without this flag those two very different outcomes are indistinguishable.
    analytics.track(
      FunnelEvents.registerSucceeded,
      props: {
        'method': AuthMethod.email,
        'awaiting_confirmation': !hasSession,
      },
    );
    if (!hasSession) {
      setState(() => _pendingConfirmationEmail = email);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _pendingConfirmationEmail;
    if (email == null || _resending) return;
    setState(() => _resending = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: 'nutrilens://auth/callback',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.verificationEmailResent),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.emailSendFailed(e))),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final user = next.value!;
        // Social sign-in started on this screen comes back here. It reports
        // as a login rather than a registration because the client cannot
        // tell a new Google account from a returning one; the server can,
        // by comparing `auth.users.created_at` with the event timestamp.
        final method = ref.read(pendingSocialAuthProvider.notifier).take();
        if (method != null) {
          ref
              .read(analyticsServiceProvider)
              .track(FunnelEvents.loginSucceeded, props: {'method': method});
        }
        ref.read(subscriptionServiceProvider).logIn(user.id);
        if (!mounted) return;
        runPostAuthFlow(ref, context, userId: user.id);
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          const CozyGlowBackdrop(),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _pendingConfirmationEmail != null
                  ? _ConfirmationSentView(
                      email: _pendingConfirmationEmail!,
                      isResending: _resending,
                      onResend: _resendConfirmation,
                    )
                  : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // The same back chip every pushed cozy screen wears,
                    // rather than a bare IconButton.
                    CozyHeaderAction(
                      icon: Icons.arrow_back_rounded,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () => context.go('/login'),
                    ),

                    const SizedBox(height: 24),

                    // Heading
                    Text(
                      l10n.createAccount,
                      style: textTheme.displaySmall?.copyWith(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.startHealthyJourney,
                      style: textTheme.bodyLarge?.copyWith(
                        color: context.colors.cozy.bodyOnTint,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Full name
                    _buildLabel(l10n.fullName),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontFamilyFallback: const ['Roboto', 'sans-serif'],
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.fullName,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
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
                      decoration: InputDecoration(
                        hintText: l10n.emailHint,
                        prefixIcon: const Icon(Icons.email_outlined),
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
                    AppButton(
                      label: l10n.signUp,
                      isLoading: isLoading,
                      onPressed: _handleRegister,
                    ),

                    const SizedBox(height: 32),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: context.colors.border)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n.orSeparator,
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
                          l10n.alreadyHaveAccount,
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            l10n.signIn,
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

/// Shown after a successful signUpWithEmail when Supabase's "Confirm
/// email" toggle is ON — the user is created but unauthenticated
/// until they click the verification link. We surface a clear "check
/// your inbox + spam" message + a resend button so they don't think
/// the app silently swallowed their signup.
class _ConfirmationSentView extends StatelessWidget {
  final String email;
  final bool isResending;
  final VoidCallback onResend;

  const _ConfirmationSentView({
    required this.email,
    required this.isResending,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        CozyHeaderAction(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.go('/login'),
        ),
        const SizedBox(height: 28),
        // A cozy illustration circle rather than the brand gradient square:
        // this glyph stands for "check your inbox", not for NutriLens.
        Container(
          width: 84,
          height: 84,
          decoration: cozyCircleDecoration(context),
          alignment: Alignment.center,
          child: Icon(
            Icons.mark_email_read_outlined,
            color: colors.cozy.mint.ink,
            size: 38,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.verifyYourEmail,
          style: textTheme.headlineMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 15,
              color: colors.cozy.bodyOnTint,
              height: 1.5,
            ),
            children: [
              TextSpan(text: l10n.verificationLinkPrefix),
              TextSpan(
                text: email,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: l10n.verificationLinkSuffix),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Peach is the app's warning/heads-up tint. Hairline box replaced by
        // the tinted card the rest of the app uses for the same job.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cozy.peach.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: colors.cozy.peach.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.checkSpamFolder,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.cozy.bodyOnTint,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        AppButton(
          label: l10n.resendEmail,
          isLoading: isResending,
          onPressed: onResend,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: Text(
              l10n.backToLogin,
              style: TextStyle(
                color: context.colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
