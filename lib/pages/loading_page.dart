import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';

import 'main_page.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({required this.settings, super.key});

  final AppSettings settings;

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  Future<void> getAppData() async {
    // Task data will be loaded here once persistent task storage is added.
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainPage(settings: widget.settings),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    getAppData();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
