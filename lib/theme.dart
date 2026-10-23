import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One full set of app colors.
class AppPalette {
  const AppPalette({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentLight,
    required this.onAccent,
    required this.button,
    required this.onButton,
    required this.success,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.folder,
  });

  final bool isDark;
  final Color bg, surface, surfaceAlt, border;
  final Color text, muted, faint;
  final Color accent, accentLight, onAccent;

  /// Fill and text of solid buttons and selected chips: a lighter gold.
  final Color button, onButton;
  final Color success, warning, warningBg, danger, folder;
}

const darkPalette = AppPalette(
  isDark: true,
  bg: Color(0xFF0D0D0D),
  surface: Color(0xFF2A2A2A),
  surfaceAlt: Color(0xFF353535),
  border: Color(0xFF3D3D3D),
  text: Color(0xFFF5F5F5),
  muted: Color(0xFF9E9E9E),
  faint: Color(0xFF6B6B6B),
  accent: Color(0xFFC9A227), // gold
  accentLight: Color(0xFFE8CB6A), // lighter gold for glows
  onAccent: Color(0xFF0D0D0D),
  button: Color(0xFFE6CA72),
  onButton: Color(0xFF1A1508),
  success: Color(0xFF5FAE72),
  warning: Color(0xFFD9822B),
  warningBg: Color(0x29D9822B),
  danger: Color(0xFFE5675A),
  folder: Color(0xFFB8963E),
);

const lightPalette = AppPalette(
  isDark: false,
  bg: Color(0xFFFAF9F5),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFF0EEE6),
  border: Color(0xFFE3E0D5),
  text: Color(0xFF1F1E1D),
  muted: Color(0xFF6E6C66),
  faint: Color(0xFFA6A39A),
  accent: Color(0xFF9C7A12), // deeper gold so it reads on cream
  accentLight: Color(0xFFC9A227),
  onAccent: Color(0xFFFFFFFF),
  button: Color(0xFFDDBE5C),
  onButton: Color(0xFF1F1E1D),
  success: Color(0xFF3F7D4E),
  warning: Color(0xFFB8641C),
  warningBg: Color(0x1FB8641C),
  danger: Color(0xFFB8432F),
  folder: Color(0xFFC08A2E),
);

/// The current colors. Screens read these directly; switching theme swaps
/// the palette and rebuilds every widget (see [AppTheme]).
class AppColors {
  AppColors._();

  static AppPalette _p = darkPalette;

  static bool get isDark => _p.isDark;
  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get border => _p.border;
  static Color get text => _p.text;
  static Color get muted => _p.muted;
  static Color get faint => _p.faint;
  static Color get accent => _p.accent;
  static Color get accentLight => _p.accentLight;
  static Color get onAccent => _p.onAccent;
  static Color get button => _p.button;
  static Color get onButton => _p.onButton;
  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get warningBg => _p.warningBg;
  static Color get danger => _p.danger;
  static Color get folder => _p.folder;
}

/// Holds dark/light mode. Listen to it to rebuild on change.
class AppTheme {
  AppTheme._();

  static final isDark = ValueNotifier<bool>(true);

  static void set(bool dark) {
    AppColors._p = dark ? darkPalette : lightPalette;
    isDark.value = dark;
  }
}

/// Serif headings (Android maps 'serif' to Noto Serif).
const kSerif = 'serif';

ThemeData buildAppTheme() {
  final c = AppColors._p;
  final brightness = c.isDark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: brightness,
  ).copyWith(
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accentLight,
    onSecondary: c.onAccent,
    surface: c.bg,
    onSurface: c.text,
    surfaceContainerHighest: c.surface,
    surfaceContainerHigh: c.surface, // dialogs
    surfaceTint: Colors.transparent,
    error: c.danger,
    outline: c.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.border,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle:
          c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontFamily: kSerif,
        color: c.text,
        fontSize: 19,
        fontWeight: FontWeight.w500,
      ),
    ),
    listTileTheme: ListTileThemeData(iconColor: c.muted),
    textTheme: TextTheme(bodyMedium: TextStyle(color: c.text)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.isDark ? c.surface : c.text,
      contentTextStyle: TextStyle(color: c.isDark ? c.text : c.bg),
      actionTextColor: c.accentLight,
      behavior: SnackBarBehavior.floating,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withOpacity(0.35),
      selectionHandleColor: c.accent,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(c.onAccent),
      side: BorderSide(color: c.faint, width: 1.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.button,
        foregroundColor: c.onButton,
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.button,
        foregroundColor: c.onButton,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.button,
      foregroundColor: c.onButton,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.accent),
    ),
  );
}
