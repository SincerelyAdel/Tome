import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_nav.dart';
import 'screens/home_screen.dart';
import 'widgets/app_header.dart';
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
  _hideSystemBars();
  AppTheme.set(await PrefsService.getDarkMode());
  builderRepo.value = await PrefsService.getBuilderRepo();
  runApp(const RepoViewerApp());
}

/// Full screen: status bar and navigation bar stay hidden. Swiping in from
/// the top or bottom edge shows them for a moment, then they hide again.
void _hideSystemBars() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

class RepoViewerApp extends StatefulWidget {
  const RepoViewerApp({super.key});

  @override
  State<RepoViewerApp> createState() => _RepoViewerAppState();
}

class _RepoViewerAppState extends State<RepoViewerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Android can bring the bars back while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _hideSystemBars();
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepoViewer',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeAnimationDuration: Duration.zero,
      navigatorKey: navigatorKey,
      // The header stays fixed above every page.
      builder: (context, child) => GoldGlowBorder(
        child: Column(children: [
          const AppHeader(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ]),
      ),
      home: const HomeScreen(),
    );
  }
}
