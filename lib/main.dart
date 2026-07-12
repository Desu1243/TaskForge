import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/pages/loading_page.dart';
import 'package:taskforge/themes/default_theme.dart';

ThemeData _buildDarkTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: DefaultTheme.purple,
        brightness: Brightness.dark,
      ).copyWith(
        surface: DefaultTheme.darkPurple,
        surfaceContainer: DefaultTheme.darkPurple,
        surfaceContainerHigh: DefaultTheme.accentPurple,
        onSurface: DefaultTheme.fullWhite,
        onSurfaceVariant: DefaultTheme.lightGray,
        outline: DefaultTheme.gray,
      );

  return _buildTheme(
    colorScheme: colorScheme,
    scaffoldColor: DefaultTheme.backgroundPurple,
  );
}

ThemeData _buildLightTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: DefaultTheme.purple,
        brightness: Brightness.light,
      ).copyWith(
        surface: const Color(0xFFFFFFFF),
        surfaceContainer: const Color(0xFFF3EDF5),
        surfaceContainerHigh: const Color(0xFFE7DFEA),
        outline: const Color(0xFF817783),
      );

  return _buildTheme(
    colorScheme: colorScheme,
    scaffoldColor: const Color(0xFFFCF8FD),
  );
}

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color scaffoldColor,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldColor,
      elevation: 0,
      titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 20),
      actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: DefaultTheme.purple,
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(color: scaffoldColor),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(TaskForgeApp(settings: settings));
}

class TaskForgeApp extends StatelessWidget {
  const TaskForgeApp({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        title: 'TaskForge',
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: settings.themeMode,
        home: SafeArea(child: LoadingPage(settings: settings)),
      ),
    );
  }
}
