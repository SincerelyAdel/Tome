import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/prefs_service.dart';
import 'theme.dart';
import 'widgets/gold_glow_border.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow landscape and portrait on tablet
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  AppTheme.set(await PrefsService.getDarkMode());
  runApp(const RepoViewerApp());
}

class RepoViewerApp extends StatefulWidget {
  const RepoViewerApp({super.key});

  @override
  State<RepoViewerApp> createState() => _RepoViewerAppState();
}

class _RepoViewerAppState extends State<RepoViewerApp> {
  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);
  }

  /// Screens read [AppColors] directly, so after a switch every widget
  /// (including ones on pages further back) must rebuild.
  void _onThemeChanged() {
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepoViewer',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeAnimationDuration: Duration.zero,
      builder: (context, child) =>
          GoldGlowBorder(child: child ?? const SizedBox.shrink()),
      home: const HomeScreen(),
    );
  }
}
