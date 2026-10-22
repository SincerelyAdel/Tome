import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Claude-style light palette used throughout the app.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFFAF9F5); // warm cream page
  static const surface = Color(0xFFFFFFFF); // cards, fields
  static const surfaceAlt = Color(0xFFF0EEE6); // selected rows, chips
  static const border = Color(0xFFE3E0D5);

  static const text = Color(0xFF1F1E1D);
  static const muted = Color(0xFF6E6C66);
  static const faint = Color(0xFFA6A39A);

  static const accent = Color(0xFFC96442); // Claude terracotta
  static const onAccent = Color(0xFFFFFFFF);

  static const success = Color(0xFF3F7D4E);
  static const warning = Color(0xFFA86B0C);
  static const warningBg = Color(0x1FA86B0C);
  static const danger = Color(0xFFB8432F);

  static const folder = Color(0xFFC08A2E);
}

/// Serif headings like the Claude apps (Android maps 'serif' to Noto Serif).
const kSerif = 'serif';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    error: AppColors.danger,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontFamily: kSerif,
        color: AppColors.text,
        fontSize: 19,
        fontWeight: FontWeight.w500,
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.muted),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.text),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.accent),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(color: AppColors.bg),
      behavior: SnackBarBehavior.floating,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return Colors.transparent;
      }),
      side: const BorderSide(color: AppColors.faint, width: 1.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        elevation: 0,
      ),
    ),
  );
}
