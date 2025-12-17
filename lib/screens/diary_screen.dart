import 'package:flutter/material.dart';
import '../widgets/eco_header.dart';
import '../widgets/eco_navbar.dart';
import '../screens/badges_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/streaks_screen.dart';

class DiaryScreen extends StatelessWidget {
  final int initialTabIndex; // 0 = Streaks, 1 = Progress, 2 = Badges
  const DiaryScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialTabIndex,
      length: 3, // three tabs
      child: Scaffold(
        appBar: const EcoTrackHeader(),
        body: Column(
          children: [
            // Top Tab Bar
            Container(
              color: Colors.green[400],
              child: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'Streaks'),
                  Tab(text: 'Progress'),
                  Tab(text: 'Badges'),
                ],
              ),
            ),
            // Tab Views
            Expanded(
  child: TabBarView(
    children: [
      StreaksScreen(),
      ProgressScreen(),
      BadgesScreen(),
    ],
  ),
),

          ],
        ),
        bottomNavigationBar: const EcoNavBar(currentIndex: 2),
      ),
    );
  }
}
