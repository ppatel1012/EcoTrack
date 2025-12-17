import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/social_screen.dart';
import '../screens/diary_screen.dart';
import '../screens/add_screen.dart';

class EcoNavBar extends StatelessWidget {
  final int currentIndex;
  const EcoNavBar({super.key, required this.currentIndex});

  void _navigate(BuildContext context, int index) {
    Widget target;
    switch (index) {
      case 0:
        target = const HomeScreen();
        break;
      case 1:
        target = const SocialScreen();
        break;
      case 2:
        target = const DiaryScreen();
        break;
      default:
        target = const HomeScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color green = Color(0xFF4CAF50);
    const double iconSize = 28;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Base Navigation Bar
        Container(
          margin: const EdgeInsets.only(bottom: 24, left: 40, right: 40),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: green,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(
                context,
                icon: Icons.home_filled,
                index: 0,
                currentIndex: currentIndex,
                iconSize: iconSize,
                green: green,
              ),
              _navItem(
                context,
                icon: Icons.people_alt_rounded,
                index: 1,
                currentIndex: currentIndex,
                iconSize: iconSize,
                green: green,
              ),
              _navItem(
                context,
                icon: Icons.book_rounded,
                index: 2,
                currentIndex: currentIndex,
                iconSize: iconSize,
                green: green,
              ),
              const SizedBox(width: 65),
            ],
          ),
        ),

        // Floating Add Button
        Positioned(
          bottom: 18,
          right: 40,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddScreen()),
              );
            },
            child: Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: green, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: green, size: 38),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required int index,
    required int currentIndex,
    required double iconSize,
    required Color green,
  }) {
    final bool isSelected = (index == currentIndex) && currentIndex >= 0;

    return GestureDetector(
      onTap: () => _navigate(context, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: iconSize,
          color: isSelected ? green : Colors.white,
        ),
      ),
    );
  }
}
