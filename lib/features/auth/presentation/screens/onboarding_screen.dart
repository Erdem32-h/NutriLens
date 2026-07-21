import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    ref.read(analyticsServiceProvider).track(FunnelEvents.onboardingShown);
  }

  /// Finish the intro by dropping the visitor into the product as a
  /// guest, not onto the login form. They get [GuestScanCounter
  /// .lifetimeLimit] free scans before an account is required, which
  /// is the moment the ask actually means something to them.
  ///
  /// Lands on /meals rather than /scanner on purpose. The scanner opens a
  /// camera in initState, so routing there directly put an OS permission
  /// dialog in front of someone who had not asked for the camera yet —
  /// the very first interaction in the app was a system prompt. Both the
  /// meal diary and the product history now carry a scan button, so the
  /// prompt follows a deliberate tap.
  ///
  /// [via] separates the two ways this is reached — the header "skip" link
  /// and the final CTA. They mean different things: skipping at page 0 is a
  /// visitor who never saw the value pitch, and if that turns out to be the
  /// dominant path the pitch is what needs work, not the funnel below it.
  Future<void> _startAsGuest({required String via}) async {
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(
      FunnelEvents.onboardingCompleted,
      props: {'via': via, 'page': _currentPage},
    );
    analytics.track(FunnelEvents.guestStarted, props: {'from': 'onboarding'});
    final session = ref.read(appSessionControllerProvider);
    await session.completeOnboarding();
    await session.enterGuestMode();
    if (mounted) context.go('/meals');
  }

  /// Returning user who reinstalled or already registered elsewhere.
  Future<void> _goToLogin() async {
    ref
        .read(analyticsServiceProvider)
        .track(
          FunnelEvents.onboardingSkipped,
          props: {'to': 'login', 'page': _currentPage},
        );
    await ref.read(appSessionControllerProvider).completeOnboarding();
    if (mounted) context.go('/login');
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.of(context).size;

    final pages = [
      _PageData(
        icon: Icons.qr_code_scanner_rounded,
        title: l10n.scanBarcodeTitle,
        description: l10n.scanBarcodeDescription,
        gradient: const [Color(0xFF16A34A), Color(0xFF4ADE80)],
      ),
      _PageData(
        icon: Icons.analytics_rounded,
        title: l10n.healthScoreTitle,
        description: l10n.healthScoreDescription,
        gradient: const [Color(0xFF065F46), Color(0xFF34D399)],
      ),
      _PageData(
        icon: Icons.tune_rounded,
        title: l10n.personalFilters,
        description: l10n.personalFiltersDescription,
        gradient: const [Color(0xFF14532D), Color(0xFF4ADE80)],
      ),
    ];

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // Background gradient blob
          Positioned(
            top: -size.height * 0.1,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
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
                        onPressed: () => _startAsGuest(via: 'skip'),
                        child: Text(
                          l10n.skip,
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      _animController.reset();
                      _animController.forward();
                      ref
                          .read(analyticsServiceProvider)
                          .track(
                            FunnelEvents.onboardingPageViewed,
                            props: {'page': index},
                          );
                    },
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      return FadeTransition(
                        opacity: _fadeAnim,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon container with gradient
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: page.gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 40,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  page.icon,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 48),
                              Text(
                                page.title,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.textPrimary,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                page.description,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: context.colors.textMuted,
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Column(
                    children: [
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(pages.length, (index) {
                          final isActive = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: isActive ? 28 : 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? context.colors.primary
                                  : context.colors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      // CTA button
                      AppButton(
                        label: _currentPage == pages.length - 1
                            ? l10n.startFree
                            : l10n.continueText,
                        onPressed: _currentPage == pages.length - 1
                            ? () => _startAsGuest(via: 'cta')
                            : _nextPage,
                      ),

                      // Escape hatch for people who already have an
                      // account (reinstall, second device). Kept quiet
                      // so it never competes with the primary CTA.
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

class _PageData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;

  const _PageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
