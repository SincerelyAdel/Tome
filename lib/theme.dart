import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dark palette with a gold accent, used throughout the app.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0D0D0D); // page background
  static const surface = Color(0xFF2A2A2A); // cards, fields
  static const surfaceAlt = Color(0xFF353535); // selected rows, chips
  static const border = Color(0xFF3D3D3D);

  static const text = Color(0xFFF5F5F5); // primary text
  static const muted = Color(0xFF9E9E9E); // secondary text (lifted for legibility)
  static const faint = Color(0xFF6B6B6B); // palette "secondary": hints, icons

  static const accent = Color(0xFFC9A227); // gold
  static const accentLight = Color(0xFFE8CB6A); // lighter gold for glows
  static const onAccent = Color(0xFF0D0D0D);

  static const success = Color(0xFF5FAE72);
  static const warning = Color(0xFFD9822B);
  static const warningBg = Color(0x29D9822B);
  static const danger = Color(0xFFE5675A);

  static const folder = Color(0xFFB8963E);
}

/// Serif headings (Android maps 'serif' to Noto Serif).
const kSerif = 'serif';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.accentLight,
    onSecondary: AppColors.onAccent,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surface,
    surfaceContainerHigh: AppColors.surface, // dialogs
    surfaceTint: Colors.transparent,
    error: AppColors.danger,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    dividerColor: AppColors.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
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
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: AppColors.text),
      actionTextColor: AppColors.accentLight,
      behavior: SnackBarBehavior.floating,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent.withOpacity(0.35),
      selectionHandleColor: AppColors.accent,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(AppColors.onAccent),
      side: const BorderSide(color: AppColors.faint, width: 1.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accent),
    ),
  );
}
