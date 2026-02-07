import 'package:flutter/material.dart';
import 'package:taskforge/pages/LoadingPage.dart';
import 'package:taskforge/themes/DefaultTheme.dart';

final ThemeData myTheme = ThemeData(
  useMaterial3: true,

  appBarTheme: AppBarTheme(
    backgroundColor: DefaultTheme.backgroundPurple,
    elevation: 0.0,
    titleTextStyle: TextStyle(
      color: DefaultTheme.fullWhite,
      fontSize: 20
    ),
    actionsIconTheme: IconThemeData(
      color: DefaultTheme.fullWhite
    )
  ),

  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: DefaultTheme.purple,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    )
  ),

  bottomAppBarTheme: BottomAppBarThemeData(
    color: DefaultTheme.backgroundPurple
  ),

  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.purple,

    brightness: Brightness.dark,
  ),
);

void main() {
  runApp(MaterialApp(
    title: "TaskForge",
    theme: myTheme,
    home: const SafeArea(child: LoadingPage()),
  ));
}
