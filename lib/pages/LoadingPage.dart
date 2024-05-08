import 'package:flutter/material.dart';

import 'MainPage.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {

  Future<void> getAppData() async {
    /// get data from files
    await Future.delayed(Duration(seconds: 1));

    if(context.mounted){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainPage()));
    }
  }

  @override
  void initState() {
    super.initState();
    getAppData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          color: Colors.cyan,
          width: 100,
          height: 100,
        ),
      ),
    );
  }
}
