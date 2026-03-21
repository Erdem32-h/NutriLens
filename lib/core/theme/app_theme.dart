import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final colors = AppColorsExtension.dark;
    
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: colors.primary,
      onPrimary: colors.background,
      secondary: colors.primaryDark,
      onSecondary: colors.background,
      error: colors.error,
      onError: colors.background,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerLowest: colors.surfaceCard,
      surfaceContainerLow: colors.surfaceCard,
      surfaceContainer: colors.surfaceCard2,
      outline: colors.border,
      outlineVariant: colors.border,
    );

    return _buildTheme(colors, colorScheme, Brightness.dark);
  }

  static ThemeData get light {
    final colors = AppColorsExtension.light;
    
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: colors.primary,
      onPrimary: colors.background,
      secondary: colors.primaryDark,
      onSecondary: colors.background,
      error: colors.error,
      onError: colors.background,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerLowest: colors.surfaceCard,
      surfaceContainerLow: colors.surfaceCard,
      surfaceContainer: colors.surfaceCard2,
      outline: colors.border,
      outlineVariant: colors.border,
    );

    return _buildTheme(colors, colorScheme, Brightness.light);
  }

  static ThemeData _buildTheme(AppColorsExtension colors, ColorScheme colorScheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(colors),
      scaffoldBackgroundColor: colors.background,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: brightness,
          statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.background, // Or white if preferred, but onPrimary works
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
          foregroundColor: colors.primary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          side: BorderSide(color: colors.primary),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.error),
        ),
        labelStyle: TextStyle(color: colors.textMuted),
        hintStyle: TextStyle(color: colors.textMuted),
        prefixIconColor: colors.textMuted,
        suffixIconColor: colors.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.primary, size: 24);
          }
          return IconThemeData(color: colors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary,
            );
          }
          return TextStyle(
            fontSize: 11, fontWeight: FontWeight.w400, color: colors.textMuted,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceCard2,
        selectedColor: colors.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: colors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.border),
        ),
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: colors.textMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceCard2,
        contentTextStyle: TextStyle(color: colors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
