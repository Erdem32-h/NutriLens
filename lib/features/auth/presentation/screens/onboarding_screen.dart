import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/cozy_header.dart';
import '../../../scanner/presentation/providers/scanner_mode_provider.dart';
import '../widgets/onboarding_previews.dart';

/// First-launch screen: one promise, two ways straight into the product.
///
/// Until 2026-11 this was a three-page intro ending on /meals. 98 of 289
/// devices left on page 0 and only ~1/3 ever reached the scanner, so the
/// pages went and the scan buttons moved here.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  /// When this screen appeared, so an abandonment can report how long they
  /// actually looked at it.
  final _openedAt = DateTime.now();

  /// True once the visitor left through a door we already measure — a scan
  /// button, the skip link, or the login link. Guards [_trackAbandoned] so
  /// the two never both fire for the same exit.
  bool _exitTracked = false;

  /// Held rather than read through `ref` on demand: [dispose] is one of the
  /// places abandonment is recorded, and reading a provider while the element
  /// is being torn down is not allowed.
  late final _analytics = ref.read(analyticsServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    final analytics = _analytics;
    analytics.track(FunnelEvents.onboardingShown);
    // Single screen now; the page=0 event stays for dashboard continuity.
    analytics.track(FunnelEvents.onboardingPageViewed, props: {'page': 0});
  }

  /// Drops the visitor into the product as a guest, not onto the login form.
  /// They get [GuestScanCounter.lifetimeLimit] free scans before an account
  /// is required.
  ///
  /// [scanMode] null → /meals (the skip link). 1 = food, 0 = barcode →
  /// straight into the scanner in that mode. Landing on /scanner used to be
  /// avoided because it raised the OS camera prompt unasked; the scanner now
  /// shows CameraRationaleSheet first, and this path is a deliberate tap.
  ///
  /// [via] (`cta_food` / `cta_barcode` / `skip`) records which door was used.
  Future<void> _startAsGuest({required String via, int? scanMode}) async {
    _exitTracked = true;
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(
      FunnelEvents.onboardingCompleted,
      props: {'via': via, 'page': 0},
    );
    analytics.track(FunnelEvents.guestStarted, props: {'from': 'onboarding'});
    final session = ref.read(appSessionControllerProvider);
    await session.completeOnboarding();
    await session.enterGuestMode();
    if (!mounted) return;
    if (scanMode == null) {
      context.go('/meals');
      return;
    }
    ref.read(pendingScannerModeProvider.notifier).state = scanMode;
    context.go('/scanner');
  }

  /// Returning user who reinstalled or already registered elsewhere.
  Future<void> _goToLogin() async {
    _exitTracked = true;
    ref
        .read(analyticsServiceProvider)
        .track(
          FunnelEvents.onboardingSkipped,
          props: {'to': 'login', 'page': 0},
        );
    await ref.read(appSessionControllerProvider).completeOnboarding();
    if (mounted) context.go('/login');
  }

  /// Records a departure that no other event covers.
  ///
  /// Fires at most once — whoever gets here first wins — so a visitor who
  /// backgrounds the app and never returns is counted exactly like one who
  /// force-kills it, and neither is double counted on dispose.
  void _trackAbandoned(String reason) {
    if (_exitTracked) return;
    _exitTracked = true;
    _analytics.track(
      FunnelEvents.onboardingAbandoned,
      props: {
        'page': 0,
        'seconds': DateTime.now().difference(_openedAt).inSeconds,
        'reason': reason,
      },
    );
  }

  /// Backgrounding is the signal that matters: the common way to quit
  /// onboarding is to leave the app, and then [dispose] never runs. `track`
  /// persists to SharedPreferences synchronously enough to survive the kill
  /// that usually follows, and the event ships on the next launch.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _trackAbandoned('background');
    }
  }

  @override
  void dispose() {
    // Navigated away without using one of the measured doors.
    _trackAbandoned('disposed');
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          const CozyGlowBackdrop(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(onSkip: () => _startAsGuest(via: 'skip')),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _Promise(
                      title: l10n.onboardingMealTitle,
                      body: l10n.onboardingMealBody,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                  child: Column(
                    children: [
                      AppButton(
                        label: l10n.scanFood,
                        icon: Icons.camera_alt_rounded,
                        onPressed: () =>
                            _startAsGuest(via: 'cta_food', scanMode: 1),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: l10n.scanBarcodeTitle,
                        icon: Icons.qr_code_scanner_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            _startAsGuest(via: 'cta_barcode', scanMode: 0),
                      ),
                      // Escape hatch for people who already have an
                      // account (reinstall, second device). Kept quiet
                      // so it never competes with the scan buttons.
                      TextButton(
                        onPressed: _goToLogin,
                        child: Text(
                          l10n.alreadyHaveAccountSignIn,
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onSkip;

  const _TopBar({required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: context.colors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Colors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'NutriLens',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: onSkip,
            child: Text(
              context.l10n.skip,
              style: TextStyle(
                color: context.colors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview + one-line promise.
///
/// Scales down as one block on short screens so the promise is never cut off
/// below the fold. The SizedBox is required: FittedBox gives its child
/// unbounded width, and the preview's Row/Expanded break under that.
class _Promise extends StatelessWidget {
  final String title;
  final String body;

  const _Promise({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    const hPad = 24.0;
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: constraints.maxWidth - hPad * 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MealPreview(),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 15,
                      // Body-on-wash, not textMuted: muted is mint-tinted in
                      // dark mode and clashes with the wash behind it.
                      color: context.colors.cozy.bodyOnTint,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
