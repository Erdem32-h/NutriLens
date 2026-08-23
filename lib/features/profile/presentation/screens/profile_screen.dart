import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/session/guest_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../meals/presentation/providers/meal_chart_provider.dart';
import '../../../meals/presentation/providers/meal_provider.dart';
import '../providers/health_filters_provider.dart';
import '../providers/user_data_deletion_provider.dart';
import '../providers/user_metrics_provider.dart';
import '../screens/metrics_wizard_screen.dart';
import '../widgets/analytics_opt_out_tile.dart';
import '../../../../core/theme/cozy_tokens.dart';
import '../../../../core/widgets/cozy_header.dart';
import '../../../../core/widgets/cozy_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isGuestProvider);
    final l10n = context.l10n;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);

    final initial = isGuest
        ? 'M'
        : (user?.displayName?.isNotEmpty == true
                  ? user!.displayName![0]
                  : user?.email[0] ?? '?')
              .toUpperCase();

    final cozy = context.colors.cozy;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          CozyHeader(
            title: l10n.profile,
            subtitle: l10n.profileSubtitle,
            action: CozyHeaderAction(
              icon: Icons.logout_rounded,
              tooltip: l10n.signOut,
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ),

          // Identity card
          Container(
            margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cozy.lilac.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: context.colors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuest
                            ? l10n.guestUser
                            : (user?.displayName ?? l10n.user),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isGuest ? l10n.guestDataLocal : (user?.email ?? ''),
                        style: TextStyle(
                          fontSize: 13,
                          color: cozy.bodyOnTint,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isGuest) _GuestRegisterBanner(),

          const SizedBox(height: 18),

          // Settings section
          CozySectionLabel(l10n.settings),

          // Theme tile
          _SettingsTile(
            icon: currentThemeMode == ThemeMode.dark
                ? Icons.dark_mode_rounded
                : currentThemeMode == ThemeMode.light
                ? Icons.light_mode_rounded
                : Icons.brightness_auto_rounded,
            title: l10n.theme,
            subtitle: l10n.themeSubtitle,
            tint: cozy.lilac,
            value: currentThemeMode == ThemeMode.dark
                ? l10n.darkMode
                : currentThemeMode == ThemeMode.light
                ? l10n.lightMode
                : l10n.systemMode,
            onTap: () => _showThemeDialog(context, ref, currentThemeMode),
          ),

          // Language tile
          _SettingsTile(
            icon: Icons.language_rounded,
            title: l10n.language,
            subtitle: l10n.languageSubtitle,
            tint: cozy.sky,
            value: _getLanguageDisplayName(currentLocale.languageCode),
            onTap: () => _showLanguageDialog(context, ref, currentLocale),
          ),


          // Kişisel kalori hedefi — hesaplanmışsa hedefi alt metinde
          // gösterir, yoksa hesaplamaya davet eder. shouldPrompt() kontrolü
          // BİLEREK burada yapılmaz: food_result_screen'deki otomatik
          // tetikleyici yalnızca ilk-öğün-sonrası bir kez açılır ve
          // reddedildikten sonra bir daha kendiliğinden açılmaz, ama profil
          // her zaman bir giriş noktası olarak kalmalı. Mevcut kayıt varsa
          // sihirbaz kendi initState'inde alanları doldurur (bkz.
          // MetricsWizardScreen dokümantasyonu) — burada bir şey geçmiyoruz.
          Consumer(
            builder: (context, ref, _) {
              final personalTarget = ref.watch(personalDailyCaloriesProvider);
              return _SettingsTile(
                icon: Icons.local_fire_department_rounded,
                title: l10n.calorieTargetCardTitle,
                tint: cozy.peach,
                subtitle: personalTarget != null
                    ? l10n.calorieTargetCardSubtitleSet(personalTarget)
                    : l10n.calorieTargetCardSubtitleUnset,
                // Hedef gerçekten hesaplanmışsa (personalTarget != null)
                // tıbbi tavsiye niteliğinde değil, tahmini bir sayı olduğu
                // hatırlatılır. Hesaplanmamış davet metninde henüz bir
                // hedef yok, o yüzden dipnot gereksiz.
                footnote:
                    personalTarget != null ? l10n.metricsMedicalDisclaimer : null,
                // rootNavigator: the tabs live in a ShellRoute whose child
                // sits above an ad banner and the nav bar. Pushing onto the
                // nested navigator would keep both on screen and cost the
                // wizard ~330px — enough that on a 720x1280 device only one
                // of the three sex options fit, and the weight field became
                // unreachable behind the keyboard.
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => const MetricsWizardScreen(),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          // Health filters section
          CozySectionLabel(l10n.healthFilters),

          _SettingsTile(
            icon: Icons.warning_amber_rounded,
            title: l10n.allergens,
            subtitle: l10n.allergenTypes,
            tint: cozy.peach,
            onTap: () => context.goNamed(RouteNames.allergenSelection),
          ),
          _SettingsTile(
            icon: Icons.restaurant_rounded,
            title: l10n.dietFilters,
            subtitle: l10n.dietOptions,
            tint: cozy.mint,
            onTap: () => context.goNamed(RouteNames.dietFilter),
          ),
          _SettingsTile(
            icon: Icons.opacity_rounded,
            title: l10n.oilFilters,
            subtitle: l10n.oilOptions,
            tint: cozy.sky,
            onTap: () => context.goNamed(RouteNames.oilFilter),
          ),
          _SettingsTile(
            icon: Icons.science_rounded,
            title: l10n.chemicalFilters,
            subtitle: l10n.chemicalOptions,
            tint: cozy.rose,
            onTap: () => context.goNamed(RouteNames.chemicalFilter),
          ),

          const SizedBox(height: 18),

          // Subscription section. Visible to everyone:
          // - authenticated free user → routes to /paywall
          // - authenticated premium  → shows "Premium Aktif"
          // - guest                  → tapping fires the register
          //   sheet (premium needs a RevenueCat identity, but the
          //   tile is still surfaced so guests see the upgrade path)
          CozySectionLabel(l10n.subscription),
          Consumer(
            builder: (context, ref, _) {
              final isPremium = ref.watch(isPremiumProvider);
              if (isPremium) {
                return _SettingsTile(
                  icon: Icons.star,
                  title: l10n.premiumActive,
                  subtitle: l10n.premiumBenefits,
                  value: l10n.activeStatus,
                  tint: cozy.lilac,
                  onTap: () => context.push('/paywall'),
                );
              }
              return _SettingsTile(
                icon: Icons.star_outline,
                title: l10n.premiumContinueCta,
                subtitle: context.l10n.premiumBenefits,
                tint: cozy.lilac,
                onTap: () async {
                  if (!await ref.requireAuthOr(
                    context,
                    feature: context.l10n.featurePremium,
                  )) {
                    return;
                  }
                  if (context.mounted) context.push('/paywall');
                },
              );
            },
          ),

          const SizedBox(height: 18),

          // Privacy — shown to everyone, guests included. Funnel events are
          // keyed by a hashed device id and are recorded whether or not the
          // visitor ever signs up, so gating this behind an account would
          // hide the switch from most of the people it applies to.
          CozySectionLabel(l10n.privacy),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: AnalyticsOptOutTile(),
          ),

          // Data management — only meaningful for authenticated users.
          // Guests have no Supabase rows to delete and no account to
          // remove; their local data is wiped on uninstall.
          if (!isGuest) ...[
            const SizedBox(height: 18),
            CozySectionLabel(l10n.dataManagement),
            _SettingsTile(
              icon: Icons.delete_sweep_rounded,
              title: l10n.deleteAllData,
              subtitle: l10n.userData,
              accentColor: context.colors.error,
              onTap: () => _confirmDeleteAllData(context, ref),
            ),
            _SettingsTile(
              icon: Icons.person_remove_rounded,
              title: l10n.deleteAccount,
              subtitle: l10n.permanent,
              accentColor: context.colors.error,
              onTap: () => _confirmDeleteAccount(context, ref),
            ),
          ],

          const SizedBox(height: 24),

          // Version footer — also acts as a hidden Sentry verification
          // entry point: long-pressing the version line sends a test
          // exception to Sentry so we can confirm the SDK is wired up
          // on real devices (TestFlight / Play Internal) without
          // shipping a visible debug button.
          const _VersionFooter(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAllData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surfaceCard2,
        title: Text(
          l10n.deleteAllDataTitle,
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          l10n.deleteAllDataMessage,
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.keepData),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(userDataDeletionServiceProvider).deleteAllUserData(userId);
      ref.invalidate(scanHistoryProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(blacklistProvider);
      ref.invalidate(mealsProvider);
      ref.invalidate(calorieChartDataProvider);
      ref.invalidate(todayCalorieTotalProvider);
      ref.invalidate(healthFiltersProvider);

      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.userDataDeleted)));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.deleteDataFailed(e.toString()))),
      );
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surfaceCard2,
        title: Text(
          l10n.deleteAccountTitle,
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          l10n.deleteAccountMessage,
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.keepData),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteAccountButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountDeletionServiceProvider).deleteAccount(userId);
      ref.invalidate(scanHistoryProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(blacklistProvider);
      ref.invalidate(mealsProvider);
      ref.invalidate(calorieChartDataProvider);
      ref.invalidate(todayCalorieTotalProvider);
      ref.invalidate(healthFiltersProvider);
      ref.invalidate(authStateProvider);

      if (!context.mounted) return;
      context.go('/login');
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountFailed(e.toString()))),
      );
    }
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: context.colors.surfaceCard2,
        title: Text(
          l10n.theme,
          style: TextStyle(color: context.colors.textPrimary),
        ),
        children: [
          _buildDialogOption(
            context: context,
            title: l10n.systemMode,
            icon: Icons.brightness_auto_rounded,
            isSelected: currentMode == ThemeMode.system,
            onTap: () {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
          _buildDialogOption(
            context: context,
            title: l10n.lightMode,
            icon: Icons.light_mode_rounded,
            isSelected: currentMode == ThemeMode.light,
            onTap: () {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          _buildDialogOption(
            context: context,
            title: l10n.darkMode,
            icon: Icons.dark_mode_rounded,
            isSelected: currentMode == ThemeMode.dark,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      case 'pt':
        return 'Português';
      case 'es':
        return 'Español';
      case 'ar':
        return 'العربية';
      case 'zh':
        return '中文';
      default:
        return 'English';
    }
  }

  void _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    Locale currentLocale,
  ) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: context.colors.surfaceCard2,
        title: Text(
          l10n.language,
          style: TextStyle(color: context.colors.textPrimary),
        ),
        children: [
          _buildDialogOption(
            context: context,
            title: 'Türkçe',
            icon: Icons.flag_rounded,
            isSelected: currentLocale.languageCode == 'tr',
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('tr'));
              Navigator.pop(context);
            },
          ),
          _buildDialogOption(
            context: context,
            title: 'English',
            icon: Icons.flag_outlined,
            isSelected: currentLocale.languageCode == 'en',
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('en'));
              Navigator.pop(context);
            },
          ),
          _buildDialogOption(
            context: context,
            title: 'Português',
            icon: Icons.language_rounded,
            isSelected: currentLocale.languageCode == 'pt',
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('pt'));
              Navigator.pop(context);
            },
          ),
          _buildDialogOption(
            context: context,
            title: 'Español',
            icon: Icons.language_rounded,
            isSelected: currentLocale.languageCode == 'es',
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('es'));
              Navigator.pop(context);
            },
          ),
          _buildDialogOption(
            context: context,
            title: 'العربية',
            icon: Icons.language_rounded,
            isSelected: currentLocale.languageCode == 'ar',
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('ar'));
              Navigator.pop(context);
            },
          ),
          _buildDialogOption(
            context: context,
            title: '中文',
            icon: Icons.language_rounded,
            isSelected: currentLocale.languageCode == 'zh',
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('zh'));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDialogOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected
                ? context.colors.primary
                : context.colors.textMuted,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, color: context.colors.primary, size: 18),
        ],
      ),
    );
  }
}

/// App version line at the bottom of the profile screen. Tap to see
/// the version, long-press to fire a test Sentry event (verifies the
/// crash pipeline end-to-end on real TestFlight / Play Internal
/// devices). Kept low-key so beta testers don't trigger it by
/// accident; the long-press is intentional friction.
class _VersionFooter extends StatefulWidget {
  const _VersionFooter();

  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  String _label = '...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _label = '${info.version} (${info.buildNumber})');
    } catch (_) {
      if (!mounted) return;
      setState(() => _label = '—');
    }
  }

  Future<void> _fireSentryTest() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await Sentry.captureException(
        StateError('NutriLens manual Sentry verification ping'),
        stackTrace: StackTrace.current,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.sentryTestEventSent),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sentryTestFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onLongPress: _fireSentryTest,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          child: Text(
            '${context.l10n.appVersion} $_label',
            style: TextStyle(
              fontSize: 11,
              color: context.colors.textMuted.withValues(alpha: 0.6),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft CTA shown to guest users on the profile screen. Tapping it
/// sends them to /register so their next session is authenticated and
/// the migration prompt kicks in.
class _GuestRegisterBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CozyBanner(
      tint: context.colors.cozy.mint,
      icon: Icons.cloud_upload_outlined,
      title: l10n.createAccountBackupTitle,
      subtitle: l10n.createAccountBackupSubtitle,
      onTap: () => context.go('/register'),
    );
  }
}

/// A settings row in the cozy skin.
///
/// The old row squeezed the descriptive string ("Vegan, Vegetarian,
/// Gluten-free, Halal") into a right-hand pill that ellipsised it away on
/// every device. Those strings are descriptions, so they now sit under the
/// title where they fit, and the pill is reserved for the short status a row
/// actually reports — a theme name, "Active". Rows with no status show none.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;

  /// The descriptive line under the title.
  final String subtitle;

  /// Short status word for the pill. Null on rows that have no status.
  final String? value;

  final VoidCallback onTap;

  /// Which accent the row wears. Ignored when [accentColor] is set.
  final CozyTint? tint;

  /// Forces a one-off accent — used by the destructive rows, which have to
  /// read as dangerous rather than as the next colour in the rotation.
  final Color? accentColor;

  /// İsteğe bağlı, küçük/ikincil renkli tek satırlık dipnot — bir uyarı
  /// afişi değil, bir niteleyici (örn. tıbbi tavsiye dipnotu).
  final String? footnote;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.value,
    this.tint,
    this.accentColor,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final resolved = accentColor != null
        ? CozyTint(
            surface: accentColor!.withValues(alpha: 0.10),
            ink: accentColor!,
          )
        : (tint ?? colors.cozy.mint);

    final tile = CozyTile(
      tint: resolved,
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onTap: onTap,
    );

    if (footnote == null) return tile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 40, 6),
          child: Text(
            footnote!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}
