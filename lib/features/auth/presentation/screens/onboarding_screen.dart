import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../widgets/onboarding_previews.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  /// When this screen appeared, so an abandonment can report how long they
  /// actually looked at it.
  final _openedAt = DateTime.now();

  /// True once the visitor left through a door we already measure — the CTA,
  /// the skip link, or the login link. Guards [_trackAbandoned] so the two
  /// never both fire for the same exit.
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
    // PageView.onPageChanged ilk sayfa için ateşlenmez, dolayısıyla sayfa 0
    // bugüne kadar hiç ölçülmedi ve huni ancak onboarding_shown'dan çıkarım
    // yapılarak okunabiliyordu. Karşılaştırma metriği değişmiyor (§3):
    // öncesi/sonrası hâlâ page=1 / onboarding_shown üzerinden okunur.
    analytics.track(FunnelEvents.onboardingPageViewed, props: {'page': 0});
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
    _exitTracked = true;
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
    _exitTracked = true;
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
        'page': _currentPage,
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
        visual: (_) => const MealPreview(),
        title: l10n.onboardingMealTitle,
        description: l10n.onboardingMealBody,
      ),
      _PageData(
        visual: (_) => const ScorePreview(),
        title: l10n.onboardingBarcodeTitle,
        description: l10n.onboardingBarcodeBody,
      ),
      _PageData(
        visual: (_) => const FiltersPreview(),
        title: l10n.onboardingFiltersTitle,
        description: l10n.onboardingFiltersBody,
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Metin görselden önce gelir.
                            //
                            // Önceki hâl kaydırma + minHeight idi. Taşma
                            // hatası vermiyordu ama 640 dp'den kısa ekranlarda
                            // başlığı cümlenin ortasında kesip açıklamayı
                            // tamamen kadrajın altında bırakıyordu — üstelik
                            // kaydırılabildiğine dair hiçbir ipucu olmadan.
                            // Yani ekranın var oluş sebebi olan vaat, ilk
                            // boyamada görünmüyordu ve hiçbir hata da düşmüyordu.
                            //
                            // Artık içerik tek parça hâlinde orantılı küçülüyor:
                            // sığmayan şey görünmez olmak yerine ufalıyor.
                            // scaleDown olduğu için uzun ekranlarda hiçbir şey
                            // değişmez (ölçek 1'de kalır).
                            //
                            // SizedBox şart: FittedBox çocuğuna sınırsız
                            // genişlik verir, önizlemelerdeki Row/Expanded ise
                            // sınırsız genişlikte patlar.
                            const hPad = 24.0;
                            return Center(
                              child: Padding(
                                // Dikey pay olmadan ölçeklenen içerik alanı
                                // sonuna kadar dolduruyor ve son satır dip
                                // göstergelere yapışıyor.
                                padding: const EdgeInsets.symmetric(
                                  horizontal: hPad,
                                  vertical: 8,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: constraints.maxWidth - hPad * 2,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        page.visual(context),
                                        const SizedBox(height: 16),
                                        Text(
                                          page.title,
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
                                          page.description,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            color: context.colors.textMuted,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
  /// Sayfanın görseli. Eskiden sabit bir `IconData` idi; üç sayfanın
  /// görseli artık birbirinden farklı gerçek ürün önizlemeleri.
  final WidgetBuilder visual;
  final String title;
  final String description;

  const _PageData({
    required this.visual,
    required this.title,
    required this.description,
  });
}
