import 'package:flutter/material.dart';
import 'package:taskforge/pages/DailiesPage.dart';
import 'package:taskforge/pages/HabitsPage.dart';
import 'package:taskforge/pages/ToDosPage.dart';
import 'package:taskforge/pages/SettingsPage.dart';

import '../themes/DefaultTheme.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  List<String> pageTitles = ["Habits", "Dailies", "ToDo's", "Settings"];
  int currentPage = 0;

  PageController controller = PageController(
    initialPage: 0,
    keepPage: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitles[currentPage]),
      ),
      body: PageView(
        controller: controller,
        onPageChanged: (value) {
          setState(() {
            currentPage = value;
          });
        },
        children: const [HabitsPage(), DailiesPage(), ToDosPage(), SettingsPage()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform(
        transform: Matrix4.rotationZ(45 * 3.1415927 / 180),
        alignment: FractionalOffset.center,
        child: FloatingActionButton(
          onPressed: () {},
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5))),
          elevation: 0.0,
          child: const Icon(
            Icons.clear_rounded,
            size: 45,
            color: Colors.white,
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        padding: const EdgeInsets.all(0),
        height: 76,
          shape: const AutomaticNotchedShape(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.zero),
              ),
              StarBorder.polygon(
                sides: 4,
                rotation: 0,
                pointRounding: 0.2,
              )),
          notchMargin: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                  style: const ButtonStyle(
                      shape: WidgetStatePropertyAll(LinearBorder()),
                    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 0, vertical: 12)),
                  ),
                  onPressed: () {
                    setState(() {
                      controller.animateToPage(0, duration: const Duration(milliseconds: 500), curve: Curves.bounceInOut);
                    });
                  },
                  child: Column(
                    children: [
                      currentPage == 0
                          ? const Icon(Icons.add_box_rounded, size: 32, color: Colors.white)
                          : Icon(Icons.add_box_outlined, size: 32, color: DefaultTheme.gray),
                      currentPage == 0
                          ? const Text("Habits", style: TextStyle(color: Colors.white, fontSize: 12))
                          : Text("Habits", style: TextStyle(color: DefaultTheme.gray, fontSize: 12))
                    ],
                  )),
              OutlinedButton(
                  style: const ButtonStyle(
                    shape: WidgetStatePropertyAll(LinearBorder()),
                    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 0, vertical: 12)),
                  ),
                  onPressed: () {
                    setState(() {
                      controller.animateToPage(1, duration: const Duration(milliseconds: 500), curve: Curves.bounceInOut);
                    });
                  },
                  child: Column(
                    children: [
                      currentPage == 1
                          ? const Icon(Icons.calendar_month_rounded, size: 32, color: Colors.white,)
                          : Icon(Icons.calendar_month_outlined, size: 32, color: DefaultTheme.gray),
                      currentPage == 1
                      ? const Text("Dailies", style: TextStyle(color: Colors.white, fontSize: 12))
                      : Text("Dailies", style: TextStyle(color: DefaultTheme.gray, fontSize: 12))
                    ],
                  )),
              const SizedBox(
                width: 45,
              ),
              OutlinedButton(
                  style: const ButtonStyle(
                      shape: WidgetStatePropertyAll(LinearBorder()),
                      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 0, vertical: 12)),
                  ),
                  onPressed: () {
                    setState(() {
                      controller.animateToPage(2, duration: const Duration(milliseconds: 500), curve: Curves.bounceInOut);
                    });
                  },
                  child: Column(
                    children: [
                      currentPage == 2
                          ? const Icon(Icons.check_circle_rounded, size: 32, color: Colors.white,)
                          : Icon(Icons.check_circle_outline_rounded, size: 32, color: DefaultTheme.gray),
                      currentPage == 2
                          ? const Text("Dailies", style: TextStyle(color: Colors.white, fontSize: 12))
                          : Text("Dailies", style: TextStyle(color: DefaultTheme.gray, fontSize: 12))
                    ],
                  )),
              OutlinedButton(
                  style: const ButtonStyle(
                      shape: WidgetStatePropertyAll(LinearBorder()),
                      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 0, vertical: 12)),
                  ),
                  onPressed: () {
                    setState(() {
                      controller.animateToPage(3, duration: const Duration(milliseconds: 500), curve: Curves.bounceInOut);
                    });
                  },
                  child: Column(
                    children: [
                      currentPage == 3
                          ? const Icon(Icons.settings, size: 32, color: Colors.white,)
                          : Icon(Icons.settings_outlined, size: 32, color: DefaultTheme.gray),
                      currentPage == 3
                          ? const Text("Settings", style: TextStyle(color: Colors.white, fontSize: 12))
                          : Text("Settings", style: TextStyle(color: DefaultTheme.gray, fontSize: 12))
                    ],
                  )),
            ],
          )),
    );
  }
}
