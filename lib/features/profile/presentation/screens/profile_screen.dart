import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/locale_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOut,
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (user?.displayName?.isNotEmpty == true
                              ? user!.displayName![0]
                              : user?.email[0] ?? '?')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
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
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          user?.email ?? '',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Settings section
          Text(
            l10n.settings,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Theme setting
          Card(
            child: ListTile(
              leading: Icon(
                currentThemeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : currentThemeMode == ThemeMode.light
                        ? Icons.light_mode
                        : Icons.brightness_auto,
                color: AppColors.primary,
              ),
              title: Text(l10n.theme),
              subtitle: Text(
                currentThemeMode == ThemeMode.dark
                    ? l10n.darkMode
                    : currentThemeMode == ThemeMode.light
                        ? l10n.lightMode
                        : l10n.systemMode,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeDialog(context, ref, currentThemeMode),
            ),
          ),

          // Language setting
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: AppColors.primary),
              title: Text(l10n.language),
              subtitle: Text(
                currentLocale.languageCode == 'tr'
                    ? l10n.turkish
                    : l10n.english,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(context, ref, currentLocale),
            ),
          ),

          const SizedBox(height: 24),

          // Health filters section
          Text(
            l10n.healthFilters,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _ProfileMenuItem(
            icon: Icons.warning_amber,
            title: l10n.allergens,
            subtitle: l10n.allergenTypes,
            onTap: () => context.goNamed(RouteNames.allergenSelection),
          ),
          _ProfileMenuItem(
            icon: Icons.restaurant,
            title: l10n.dietFilters,
            subtitle: l10n.dietOptions,
            onTap: () => context.goNamed(RouteNames.dietFilter),
          ),
          _ProfileMenuItem(
            icon: Icons.opacity,
            title: l10n.oilFilters,
            subtitle: l10n.oilOptions,
            onTap: () => context.goNamed(RouteNames.oilFilter),
          ),
          _ProfileMenuItem(
            icon: Icons.science,
            title: l10n.chemicalFilters,
            subtitle: l10n.chemicalOptions,
            onTap: () => context.goNamed(RouteNames.chemicalFilter),
          ),
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
        title: Text(l10n.theme),
        children: [
          _buildDialogOption(
            context: context,
            title: l10n.systemMode,
            icon: Icons.brightness_auto,
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
            icon: Icons.light_mode,
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
            icon: Icons.dark_mode,
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
        title: Text(l10n.language),
        children: [
          _buildDialogOption(
            context: context,
            title: 'Türkçe',
            icon: Icons.flag,
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
            color: isSelected ? AppColors.primary : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
