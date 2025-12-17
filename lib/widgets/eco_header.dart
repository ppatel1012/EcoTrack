import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/setting_screen.dart';

class EcoTrackHeader extends StatelessWidget implements PreferredSizeWidget {
  const EcoTrackHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    // Colors depend on dark / light
    final Color accent = isDarkMode
        ? const Color(0xFF81C784)
        : const Color(0xFF4CAF50);
    final Color bgColor =
        theme.appBarTheme.backgroundColor ??
        (isDarkMode ? Colors.black : Colors.white);

    const double iconSize = 30;

    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile Button
          IconButton(
            icon: const Icon(Icons.person_rounded, size: iconSize),
            color: accent,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),

          // Logo (tap → Home)
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_rounded, color: accent, size: iconSize + 6),
                const SizedBox(width: 6),
                Text(
                  'EcoTrack',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),

          // Settings Button
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: iconSize),
            color: accent,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
