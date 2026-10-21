import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow landscape and portrait on tablet
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const RepoViewerApp());
}

class RepoViewerApp extends StatelessWidget {
  const RepoViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepoViewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF58A6FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF161B22),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          foregroundColor: Color(0xFFC9D1D9),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: const Color(0xFF30363D),
        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFF8B949E),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFC9D1D9)),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF238636);
            }
            return const Color(0xFF30363D);
          }),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
