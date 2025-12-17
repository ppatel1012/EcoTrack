import 'package:flutter/material.dart';
import '../widgets/eco_header.dart';
import '../widgets/eco_navbar.dart';
import '../screens/create_activity_screen.dart';
import '../screens/log_activity_screen.dart';
import '../screens/add_friend_screen.dart';
import '../screens/add_post_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AddScreen extends StatelessWidget {
  const AddScreen({super.key});

  void _go(BuildContext context, Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;

    return Scaffold(
      appBar: const EcoTrackHeader(),
      body: Padding(
        padding: const EdgeInsets.all(gap),
        child: Column(
          children: [
            // Top big card – Create Activity
            Expanded(
              flex: 2,
              child: _BigActionCard(
                color: Colors.green[300]!,
                label: "Create Activity",
                icon: FontAwesomeIcons.seedling,
                onTap: () => _go(context, const CreateActivityScreen()),
              ),
            ),

            const SizedBox(height: gap),

            // Second big card – Log Activity
            Expanded(
              flex: 2,
              child: _BigActionCard(
                color: Colors.green[500]!,
                label: "Log Activity",
                icon: FontAwesomeIcons.pencil,
                onTap: () => _go(context, const LogActivityScreen()),
              ),
            ),

            const SizedBox(height: gap),

            // Bottom row
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: _SmallActionCard(
                      label: "Add Friend",
                      icon: FontAwesomeIcons.userPlus,
                      onTap: () => _go(context, const AddFriendsScreen()),
                    ),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    child: _SmallActionCard(
                      label: "Add Post",
                      icon: FontAwesomeIcons.camera,
                      onTap: () => _go(context, const AddPostScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const EcoNavBar(currentIndex: -1),
    );
  }
}

//  BIG CARDS
class _BigActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _BigActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24), // softer radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withOpacity(0.92),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  SMALL CARDS
class _SmallActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const ecoGreen = Color(0xFF4CAF50);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ecoGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ecoGreen, size: 30),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ecoGreen,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
