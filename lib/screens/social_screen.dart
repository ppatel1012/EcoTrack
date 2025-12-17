import 'package:flutter/material.dart';

import '../widgets/eco_header.dart';
import '../widgets/eco_navbar.dart';
import '../screens/community_feed_screen.dart';
import '../screens/friends_log_screen.dart';

class SocialScreen extends StatelessWidget {
  final int initialTabIndex;
  const SocialScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialTabIndex,
      length: 2,
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
                  Tab(text: 'Community Feed'),
                  Tab(text: 'Friends Log'),
                ],
              ),
            ),

            // Tab Views: just show the 2 real screens
            const Expanded(
              child: TabBarView(
                children: [CommunityFeedScreen(), FriendsLogScreen()],
              ),
            ),
          ],
        ),
        bottomNavigationBar: const EcoNavBar(currentIndex: 1),
      ),
    );
  }
}
