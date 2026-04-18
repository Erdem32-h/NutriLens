import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final l10n = context.l10n;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);

    final initial = (user?.displayName?.isNotEmpty == true
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
            icon: Icon(
              Icons.logout_rounded,
              color: context.colors.textMuted,
            ),
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
                  width: 64, height: 64,
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
                        user?.displayName ?? l10n.user,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
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

          // Subscription section
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

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showThemeDialog(
      BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: context.colors.surfaceCard2,
        title: Text(l10n.theme,
            style: TextStyle(color: context.colors.textPrimary)),
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
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(
      BuildContext context, WidgetRef ref, Locale currentLocale) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: context.colors.surfaceCard2,
        title: Text(l10n.language,
            style: TextStyle(color: context.colors.textPrimary)),
        children: [
          _buildDialogOption(
            context: context,
            title: 'Türkçe',
            icon: Icons.flag_rounded,
            isSelected: currentLocale.languageCode == 'tr',
            onTap: () {
              ref
                  .read(localeProvider.notifier)
                  .setLocale(const Locale('tr'));
              Navigator.pop(context);
            },
          ),
          _buildDialogOption(
            context: context,
            title: 'English',
            icon: Icons.flag_outlined,
            isSelected: currentLocale.languageCode == 'en',
            onTap: () {
              ref
                  .read(localeProvider.notifier)
                  .setLocale(const Locale('en'));
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
            color: isSelected ? context.colors.primary : context.colors.textMuted,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? context.colors.primary : context.colors.textPrimary,
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

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: context.colors.primary),
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