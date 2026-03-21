# NutriLens UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Tüm ekranları "Dark Organic Premium" estetik yönüyle modern, belirgin ve akılda kalıcı şekilde yeniden tasarlamak.

**Architecture:** Mevcut logic/provider kodları değiştirilmez; yalnızca presentation katmanı (screens, widgets, theme) güncellenir. Tüm ekranlar ortak bir design system üzerinden beslenir.

**Tech Stack:** Flutter 3.x, Material 3, google_fonts (Plus Jakarta Sans), AnimatedContainer, şeffaf degradeler.

---

## Design System

### Renk Paleti — "Dark Organic Premium"

```
background:    #070D07   (derin siyah-yeşil)
surface:       #0F1A0F
surfaceCard:   #162016
surfaceCard2:  #1E2E1E
accentGreen:   #4ADE80   (canlı lime — tek parlak renk)
accentDark:    #22C55E
textPrimary:   #F0FDF4
textSecondary: #86EFAC
textMuted:     #4B7A4B
border:        #243324
error:         #F87171
warning:       #FCD34D
```

### Tipografi — Plus Jakarta Sans (google_fonts)

- Display: 700–800 weight, -0.5 letter spacing
- Heading: 600–700 weight
- Body: 400–500 weight, comfortable line height

### Ortak UI Kuralları

- Butonlar: pill-shape (borderRadius: 50), gradient dolgu (#4ADE80 → #22C55E)
- Kartlar: borderRadius:20, border: Color(0xFF243324), background: surfaceCard
- TextField: filled, borderRadius:16, muted border + green focus
- Bottom nav: Material 3 `NavigationBar` (eski `BottomNavigationBar` yerine)
- AppBar: transparent/surface, no elevation
- Scaffold background: #070D07

---

## Task 1: google_fonts bağımlılığı ekle

**Files:**
- Modify: `pubspec.yaml`

**Step 1: pubspec.yaml'e google_fonts ekle**

```yaml
  # UI
  google_fonts: ^6.2.1
  cupertino_icons: ^1.0.8
  ...
```

`dependencies:` altındaki UI bölümüne `google_fonts: ^6.2.1` satırını ekle.

**Step 2: flutter pub get çalıştır**

```bash
flutter pub get
```

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add google_fonts dependency for UI redesign"
```

---

## Task 2: Design system güncelle (colors + typography + theme)

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/theme/app_typography.dart`
- Modify: `lib/core/theme/app_theme.dart`

**Step 1: app_colors.dart'ı yeni paletten güncelle**

Mevcut `AppColors` sınıfını aşağıdaki değerlerle tamamen değiştir:

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const Color primary      = Color(0xFF4ADE80);
  static const Color primaryDark  = Color(0xFF22C55E);
  static const Color primaryDeep  = Color(0xFF16A34A);

  // Backgrounds
  static const Color background   = Color(0xFF070D07);
  static const Color surface      = Color(0xFF0F1A0F);
  static const Color surfaceCard  = Color(0xFF162016);
  static const Color surfaceCard2 = Color(0xFF1E2E1E);
  static const Color border       = Color(0xFF243324);

  // Text
  static const Color textPrimary   = Color(0xFFF0FDF4);
  static const Color textSecondary = Color(0xFF86EFAC);
  static const Color textMuted     = Color(0xFF4B7A4B);

  // Semantic
  static const Color error   = Color(0xFFF87171);
  static const Color warning = Color(0xFFFCD34D);
  static const Color success = Color(0xFF4ADE80);
  static const Color info    = Color(0xFF60A5FA);

  // HP Gauge
  static const Color gauge1 = Color(0xFF4ADE80);
  static const Color gauge2 = Color(0xFF86EFAC);
  static const Color gauge3 = Color(0xFFFCD34D);
  static const Color gauge4 = Color(0xFFFB923C);
  static const Color gauge5 = Color(0xFFF87171);

  // NOVA
  static const Color nova1 = Color(0xFF4ADE80);
  static const Color nova2 = Color(0xFF86EFAC);
  static const Color nova3 = Color(0xFFFCD34D);
  static const Color nova4 = Color(0xFFF87171);

  // Risk
  static const Color riskSafe      = Color(0xFF4ADE80);
  static const Color riskLow       = Color(0xFF86EFAC);
  static const Color riskModerate  = Color(0xFFFCD34D);
  static const Color riskHigh      = Color(0xFFFB923C);
  static const Color riskDangerous = Color(0xFFF87171);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF070D07), Color(0xFF0F1A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static Color gaugeColor(int gauge) => switch (gauge) {
    1 => gauge1,
    2 => gauge2,
    3 => gauge3,
    4 => gauge4,
    _ => gauge5,
  };

  static Color riskColor(int riskLevel) => switch (riskLevel) {
    1 => riskSafe,
    2 => riskLow,
    3 => riskModerate,
    4 => riskHigh,
    _ => riskDangerous,
  };

  static Color novaColor(int novaGroup) => switch (novaGroup) {
    1 => nova1,
    2 => nova2,
    3 => nova3,
    _ => nova4,
  };
}
```

**Step 2: app_typography.dart'ı Plus Jakarta Sans ile güncelle**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static TextTheme get textTheme {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 36, fontWeight: FontWeight.w800,
        letterSpacing: -1.0, color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 30, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: AppColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 26, fontWeight: FontWeight.w700,
        letterSpacing: -0.25, color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: AppColors.textPrimary, height: 1.6,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: AppColors.textSecondary, height: 1.5,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15, fontWeight: FontWeight.w600,
        letterSpacing: 0.2, color: AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 10, fontWeight: FontWeight.w500,
        letterSpacing: 0.5, color: AppColors.textMuted,
      ),
    );
  }
}
```

**Step 3: app_theme.dart'ı dark-first olarak yeniden yaz**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.background,
      secondary: AppColors.primaryDark,
      onSecondary: AppColors.background,
      error: AppColors.error,
      onError: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.surfaceCard,
      surfaceContainerLow: AppColors.surfaceCard,
      surfaceContainer: AppColors.surfaceCard2,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          side: const BorderSide(color: AppColors.primary),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textMuted,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceCard2,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: AppColors.textMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceCard2,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Light theme: dark theme ile aynı (tek tema dark)
  static ThemeData get light => dark;
}
```

**Step 4: Commit**

```bash
git add lib/core/theme/
git commit -m "feat: redesign system — Dark Organic Premium palette + Plus Jakarta Sans"
```

---

## Task 3: App Shell — NavigationBar modernize

**Files:**
- Modify: `lib/features/app_shell/app_shell_screen.dart`

**Step 1: BottomNavigationBar → NavigationBar**

`AppShellScreen`'i şu şekilde yeniden yaz:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/l10n_extension.dart';
import '../../core/theme/app_colors.dart';

class AppShellScreen extends StatelessWidget {
  final Widget child;

  const AppShellScreen({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    const paths = ['/scanner', '/history', '/favorites', '/profile'];
    for (var i = 0; i < paths.length; i++) {
      if (location.startsWith(paths[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final l10n = context.l10n;
    const paths = ['/scanner', '/history', '/favorites', '/profile'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            if (index != currentIndex) context.go(paths[index]);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: const Icon(Icons.qr_code_scanner),
              label: l10n.scanner,
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: l10n.history,
            ),
            NavigationDestination(
              icon: const Icon(Icons.favorite_outline),
              selectedIcon: const Icon(Icons.favorite),
              label: l10n.favorites,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: l10n.profile,
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/app_shell/
git commit -m "feat: replace BottomNavigationBar with Material3 NavigationBar"
```

---

## Task 4: Onboarding Screen Redesign

**Files:**
- Modify: `lib/features/auth/presentation/screens/onboarding_screen.dart`

**Step 1: Tam ekran tasarım uygula**

Mevcut basit ikon+metin yapısını, tam ekran degradeli arka plan, büyük ikon container ve animasyonlu sayfa geçişi olan modern bir yapıyla değiştir:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
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
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) context.goNamed(RouteNames.login);
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
      backgroundColor: AppColors.background,
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
                    AppColors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'NutriLens',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          l10n.skip,
                          style: const TextStyle(
                            color: AppColors.textMuted,
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
                                width: 140, height: 140,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: page.gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
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
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                page.description,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textMuted,
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
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      // CTA button
                      GestureDetector(
                        onTap: _currentPage == pages.length - 1
                            ? _completeOnboarding
                            : _nextPage,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _currentPage == pages.length - 1
                                ? l10n.start
                                : l10n.continueText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: 0.3,
                            ),
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
```

**Step 2: Commit**

```bash
git add lib/features/auth/presentation/screens/onboarding_screen.dart
git commit -m "feat: redesign onboarding — full-screen gradient + animated pages"
```

---

## Task 5: Login Screen Redesign

**Files:**
- Modify: `lib/features/auth/presentation/screens/login_screen.dart`

**Step 1: Dark premium login ekranını uygula**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/social_login_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (mounted) {
      final authState = ref.read(authNotifierProvider);
      if (authState.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authState.error.toString())),
        );
      } else {
        context.goNamed(RouteNames.scanner);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final l10n = context.l10n;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Top glow
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
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
                    const SizedBox(height: 48),

                    // Logo
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'NutriLens',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Heading
                    const Text(
                      'Hoş geldin',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appSlogan,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Email
                    _buildLabel(l10n.email),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'ornek@email.com',
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
                      style: const TextStyle(color: AppColors.textPrimary),
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

                    const SizedBox(height: 32),

                    // Login button
                    GestureDetector(
                      onTap: isLoading ? null : _handleLogin,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: isLoading
                              ? null
                              : AppColors.primaryGradient,
                          color: isLoading ? AppColors.surfaceCard2 : null,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: isLoading
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: isLoading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary,
                                ),
                              )
                            : Text(
                                l10n.signIn,
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
                        const Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'ya da',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const SocialLoginButtons(),

                    const SizedBox(height: 32),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Hesabın yok mu?',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.goNamed(RouteNames.register),
                          child: const Text(
                            'Kayıt ol',
                            style: TextStyle(
                              color: AppColors.primary,
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
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      letterSpacing: 0.2,
    ),
  );
}
```

**Step 2: Commit**

```bash
git add lib/features/auth/presentation/screens/login_screen.dart
git commit -m "feat: redesign login — dark premium with gradient button"
```

---

## Task 6: Register Screen Redesign

**Files:**
- Modify: `lib/features/auth/presentation/screens/register_screen.dart`

**Step 1: Login ile aynı design language kullan**

Login ekranındaki pattern'i kayıt formuna uygula:
- Aynı dark background + glow
- "Hesap oluştur" başlığı
- 4 form field (name, email, password, confirm)
- Gradient submit button
- "Zaten hesabın var mı? Giriş yap" link

Login ekranındaki kodu referans alarak aynı stil ile RegisterScreen'i yeniden yaz. `_handleRegister`, `dispose`, validations korunur; yalnızca UI bölümü değişir.

**Step 2: Commit**

```bash
git add lib/features/auth/presentation/screens/register_screen.dart
git commit -m "feat: redesign register screen — dark premium style"
```

---

## Task 7: Social Login Buttons Redesign

**Files:**
- Modify: `lib/features/auth/presentation/widgets/social_login_buttons.dart`

**Step 1: Oku ve güncelle**

Mevcut `SocialLoginButtons` widget'ını oku, ardından dark theme ile uyumlu outlined button stiline çevir:
- Background: surfaceCard
- Border: border color
- Icon + metin yan yana
- Full width

**Step 2: Commit**

```bash
git add lib/features/auth/presentation/widgets/social_login_buttons.dart
git commit -m "feat: redesign social login buttons for dark theme"
```

---

## Task 8: Scanner Screen Redesign

**Files:**
- Modify: `lib/features/scanner/presentation/screens/scanner_screen.dart`
- Modify: `lib/features/scanner/presentation/widgets/scanner_overlay.dart`

**Step 1: Önce scanner_overlay.dart'ı oku**

```bash
cat lib/features/scanner/presentation/widgets/scanner_overlay.dart
```

**Step 2: Top bar iyileştir**

- Daha belirgin arka plan (semi-transparent dark)
- Eco icon + "NutriLens" text korunuyor
- Flash button pill-shaped container içinde

**Step 3: Bottom hint bölgesini modernize et**

Instruction text'in altına:
- Pill-shaped semi-transparent container
- "Barkodu çerçeveye hizalayın" metni

**Step 4: Commit**

```bash
git add lib/features/scanner/
git commit -m "feat: modernize scanner screen UI"
```

---

## Task 9: History & Favorites Empty State Redesign

**Files:**
- Modify: `lib/features/history/presentation/screens/history_screen.dart`
- Modify: `lib/features/favorites/presentation/screens/favorites_screen.dart`

**Step 1: History ekranını güncelle**

Mevcut basit empty state yerine premium boş durum:

```dart
// body kısmı:
body: Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 96, height: 96,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: const Icon(
          Icons.history_rounded,
          size: 44,
          color: AppColors.textMuted,
        ),
      ),
      const SizedBox(height: 24),
      Text(
        l10n.noHistoryYet,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.productsWillAppearHere,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  ),
),
```

**Step 2: Favorites ekranına aynısını uygula** (ikon: `Icons.favorite_rounded`)

**Step 3: AppBar'ı her ikisinde de transparent yap**

```dart
appBar: AppBar(
  title: Text(l10n.scanHistory),  // veya favorites
  backgroundColor: Colors.transparent,
),
```

**Step 4: Commit**

```bash
git add lib/features/history/ lib/features/favorites/
git commit -m "feat: redesign history and favorites empty states"
```

---

## Task 10: Profile Screen Redesign

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart`

**Step 1: Header section redesign**

User card yerine tam genişlik header:
- Gradient arka plan (surfaceCard + border)
- Büyük avatar (60px radius) gradient fill + initial
- Ad ve email altında
- Logout butonu sağ üstte icon

**Step 2: Settings section**

Her ListTile için custom styled tile:
- Container with surfaceCard bg + border
- borderRadius: 16
- Seçilen ayarın değeri sağda colored badge

**Step 3: Health filters section**

Her filter için aynı styled tile pattern.

**Step 4: Commit**

```bash
git add lib/features/profile/
git commit -m "feat: redesign profile screen with premium dark style"
```

---

## Task 11: Filter Screens Redesign

**Files:**
- Modify: `lib/features/profile/presentation/screens/allergen_selection_screen.dart`
- Modify: `lib/features/profile/presentation/screens/diet_filter_screen.dart`
- Modify: `lib/features/profile/presentation/screens/oil_filter_screen.dart`
- Modify: `lib/features/profile/presentation/screens/chemical_filter_screen.dart`

**Step 1: Her dosyayı oku**

**Step 2: Ortak pattern uygula**

Tüm filter ekranlarında:
- `AppBar` transparent
- Chip/ListTile seçimlerinde: seçili = primary color border + background tint, seçilmemiş = border color
- FilterChip veya CheckboxListTile yerine custom dark styled toggle tile

**Step 3: Commit**

```bash
git add lib/features/profile/presentation/screens/
git commit -m "feat: redesign filter screens with dark premium style"
```

---

## Task 12: Product Detail Screen Redesign

**Files:**
- Modify: `lib/features/product/presentation/screens/product_detail_screen.dart`
- Read: `lib/features/product/presentation/widgets/product_header.dart`
- Read: `lib/features/product/presentation/widgets/nova_card.dart`
- Read: `lib/features/product/presentation/widgets/nutriment_table.dart`
- Read: `lib/features/product/presentation/widgets/ingredient_list.dart`

**Step 1: Önce widget'ları oku**

Tüm product widget'larını incele.

**Step 2: Ana ekranı güncelle**

- AppBar transparent + back button styled
- Shimmer loading: dark theme uyumlu (baseColor: surfaceCard, highlightColor: surfaceCard2)
- Error/NotFound state: circle icon container + premium typography

**Step 3: Widget'ları güncelle**

Her widget için dark theme uyumluluğu:
- `ProductHeader`: surfaceCard bg, product image ile
- `NovaCard`: nova rengini accent olarak kullanan compact card
- `NutrimentTable`: stripe pattern ile dark table (alternating row colors)
- `IngredientList`: collapsible, dark styled

**Step 4: Commit**

```bash
git add lib/features/product/
git commit -m "feat: redesign product detail screen and widgets"
```

---

## Sonuç

Tüm ekranlar "Dark Organic Premium" stilinde yeniden tasarlandı. Tutarlı design system:
- `AppColors`: Yeni dark palette
- `AppTypography`: Plus Jakarta Sans
- `AppTheme`: Dark-first Material 3
- Her ekran: gradient buttons, card borders, premium typography
