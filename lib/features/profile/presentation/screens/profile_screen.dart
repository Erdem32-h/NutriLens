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
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../meals/presentation/providers/meal_provider.dart';
import '../providers/health_filters_provider.dart';
import '../providers/user_data_deletion_provider.dart';

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

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.profile),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: context.colors.textMuted),
            tooltip: l10n.signOut,
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.border),
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
                        isGuest
                            ? l10n.guestDataLocal
                            : (user?.email ?? ''),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isGuest) ...[
            const SizedBox(height: 16),
            _GuestRegisterBanner(),
          ],

          const SizedBox(height: 28),

          // Settings section
          _SectionLabel(l10n.settings),
          const SizedBox(height: 10),

          // Theme tile
          _SettingsTile(
            icon: currentThemeMode == ThemeMode.dark
                ? Icons.dark_mode_rounded
                : currentThemeMode == ThemeMode.light
                ? Icons.light_mode_rounded
                : Icons.brightness_auto_rounded,
            title: l10n.theme,
            value: currentThemeMode == ThemeMode.dark
                ? l10n.darkMode
                : currentThemeMode == ThemeMode.light
                ? l10n.lightMode
                : l10n.systemMode,
            onTap: () => _showThemeDialog(context, ref, currentThemeMode),
          ),

          const SizedBox(height: 8),

          // Language tile
          _SettingsTile(
            icon: Icons.language_rounded,
            title: l10n.language,
            value: currentLocale.languageCode == 'tr'
                ? l10n.turkish
                : l10n.english,
            onTap: () => _showLanguageDialog(context, ref, currentLocale),
          ),

          const SizedBox(height: 28),

          // Health filters section
          _SectionLabel(l10n.healthFilters),
          const SizedBox(height: 10),

          _SettingsTile(
            icon: Icons.warning_amber_rounded,
            title: l10n.allergens,
            value: l10n.allergenTypes,
            onTap: () => context.goNamed(RouteNames.allergenSelection),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.restaurant_rounded,
            title: l10n.dietFilters,
            value: l10n.dietOptions,
            onTap: () => context.goNamed(RouteNames.dietFilter),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.opacity_rounded,
            title: l10n.oilFilters,
            value: l10n.oilOptions,
            onTap: () => context.goNamed(RouteNames.oilFilter),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.science_rounded,
            title: l10n.chemicalFilters,
            value: l10n.chemicalOptions,
            onTap: () => context.goNamed(RouteNames.chemicalFilter),
          ),

          const SizedBox(height: 28),

          // Subscription section — only meaningful for authenticated
          // users. Guests get the register banner up top instead;
          // showing them "Premium'a Geç" here is misleading because
          // RevenueCat needs an identity before any purchase can be
          // attributed.
          if (!isGuest) ...[
            const _SectionLabel('Abonelik'),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final isPremium = ref.watch(isPremiumProvider);
                if (isPremium) {
                  return _SettingsTile(
                    icon: Icons.star,
                    title: 'Premium Aktif',
                    value: 'Aktif',
                    onTap: () {},
                  );
                }
                return _SettingsTile(
                  icon: Icons.star_outline,
                  title: "Premium'a Geç",
                  value: 'Sınırsız tarama, reklamsız',
                  onTap: () => context.push('/paywall'),
                );
              },
            ),
          ],

          // Data management — only meaningful for authenticated users.
          // Guests have no Supabase rows to delete and no account to
          // remove; their local data is wiped on uninstall.
          if (!isGuest) ...[
            const SizedBox(height: 28),
            _SectionLabel(l10n.dataManagement),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.delete_sweep_rounded,
              title: l10n.deleteAllData,
              value: l10n.userData,
              accentColor: context.colors.error,
              onTap: () => _confirmDeleteAllData(context, ref),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.person_remove_rounded,
              title: l10n.deleteAccount,
              value: l10n.permanent,
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
      ref.invalidate(mealCalorieSummaryProvider);
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
      ref.invalidate(mealCalorieSummaryProvider);
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
    try {
      await Sentry.captureException(
        StateError('NutriLens manual Sentry verification ping'),
        stackTrace: StackTrace.current,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sentry test event sent ✓'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Sentry test failed: $e')),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/register'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: context.colors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: Colors.black,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.createAccountBackupTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.createAccountBackupSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.colors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color? accentColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (accentColor ?? context.colors.primary).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: accentColor ?? context.colors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.surfaceCard2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.border),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
