import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreaksScreen extends StatelessWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("You must be logged in to view streaks.")),
      );
    }

    final userDoc = firestore.collection("users").doc(user.uid);

    // Screen width to calculate square size
    final double squareSize = MediaQuery.of(context).size.width * 0.65;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Your Streaks',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDoc.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                "No streak data found.",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          final data = snapshot.data!.data() ?? {};

          final int currentStreak = (data["currentStreak"] ?? 0) as int;
          final int longestStreak = (data["longestStreak"] ?? 0) as int;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Current Streak
                  SizedBox(
                    width: squareSize,
                    height: squareSize,
                    child: _StreakSquare(
                      title: 'Current Streak',
                      value: currentStreak,
                      accentColor: Colors.green.shade500,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Highest Streak
                  SizedBox(
                    width: squareSize,
                    height: squareSize,
                    child: _StreakSquare(
                      title: 'Highest Streak',
                      value: longestStreak,
                      accentColor: Colors.orange.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Square display widget for streak values
class _StreakSquare extends StatelessWidget {
  final String title;
  final int value;
  final Color accentColor;

  const _StreakSquare({
    required this.title,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withAlpha(180), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon area
            Expanded(
              flex: 5,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Image.asset('assets/icons/streak_icon.png'),
              ),
            ),

            const SizedBox(height: 8),

            // Value
            Text(
              '$value',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'days',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),

            const SizedBox(height: 8),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
