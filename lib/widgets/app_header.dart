import 'package:flutter/material.dart';
import '../app_nav.dart';
import '../screens/settings_screen.dart';
import '../services/prefs_service.dart';
import '../theme.dart';

/// The RepoViewer bar fixed at the top of every page: the app name (tap it
/// to go home), light/dark toggle and Settings. It sits above the navigator, so it never
/// scrolls away or slides out with a page.
class AppHeader extends StatefulWidget {
  const AppHeader({super.key});

  static const height = 52.0;

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  bool _settingsOpen = false;

  void _home() {
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  Future<void> _settings() async {
    final nav = navigatorKey.currentState;
    if (nav == null || _settingsOpen) return;
    _settingsOpen = true;
    await nav.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    _settingsOpen = false;
    settingsChanged.value++;
  }

  void _toggleTheme() {
    final dark = !AppColors.isDark;
    AppTheme.set(dark);
    PrefsService.setDarkMode(dark);
  }

  @override
  Widget build(BuildContext context) {
    // No tooltips here: the header sits outside the navigator's overlay.
    Widget button(IconData icon, VoidCallback onTap) => IconButton(
          icon: Icon(icon, color: AppColors.muted, size: 22),
          onPressed: onTap,
        );
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: AppHeader.height,
          padding: const EdgeInsets.only(left: 8, right: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _home,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Text('RepoViewer',
                      style: TextStyle(
                          fontFamily: kSerif,
                          color: AppColors.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            const Spacer(),
            button(
                AppColors.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                _toggleTheme),
            button(Icons.settings_outlined, _settings),
          ]),
        ),
      ),
    );
  }
}
