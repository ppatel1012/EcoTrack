import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/eco_header.dart';
import '../widgets/eco_navbar.dart';
import '../screens/log_confirmation_screen.dart';
import '../services/badge_service.dart';
import './home_screen.dart';

class LogActivityScreen extends StatefulWidget {
  const LogActivityScreen({super.key});

  @override
  State<LogActivityScreen> createState() => _LogActivityScreenState();
}

class _LogActivityScreenState extends State<LogActivityScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// docId → whether checkbox is checked
  final Map<String, bool> _selectedActivities = {};

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // TOGGLE ACTIVITY
  Future<void> _toggleActivity(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be logged in.')));
      return;
    }

    final String uid = user.uid;
    final String docId = doc.id;
    final bool currentlyChecked = _selectedActivities[docId] ?? false;
    final bool newChecked = !currentlyChecked;

    setState(() => _selectedActivities[docId] = newChecked);

    final DocumentReference<Map<String, dynamic>> ref = doc.reference;

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(ref);
        final data = snap.data() ?? {};

        int timesCompleted = (data['timesCompleted'] ?? 0) as int;
        final String activityName = (data['activityString'] ?? '') as String;

        final Timestamp? ts = data['lastCompletedDate'] as Timestamp?;
        final DateTime? lastCompletedDate = ts?.toDate();

        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);

        // Deterministic doc id for "one completion per activity per day"
        final String dateKey =
            '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
        final String completionId = '${docId}_$dateKey';

        final completionRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('activityCompletions')
            .doc(completionId);

        if (newChecked) {
          // Increment only if NOT already completed today
          if (lastCompletedDate == null ||
              !_isSameDate(lastCompletedDate, today)) {
            timesCompleted += 1;

            transaction.update(ref, {
              'timesCompleted': timesCompleted,
              'lastCompletedDate': Timestamp.fromDate(today),
            });

            // Log this day's completion
            transaction.set(completionRef, {
              'activityId': docId,
              'activityString': activityName,
              'date': Timestamp.fromDate(today),
            }, SetOptions(merge: true));
          }
        } else {
          // Undo only if it was completed today
          if (lastCompletedDate != null &&
              _isSameDate(lastCompletedDate, today)) {
            timesCompleted = timesCompleted > 0 ? timesCompleted - 1 : 0;

            transaction.update(ref, {
              'timesCompleted': timesCompleted,
              'lastCompletedDate': null,
            });

            // Remove this day's completion record
            transaction.delete(completionRef);
          }
        }
      });
    } catch (e) {
      // Revert UI on failure
      setState(() => _selectedActivities[docId] = currentlyChecked);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update activity. Please try again.'),
        ),
      );
    }
  }

  Future<Map<String, int>> _updateStreak() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final userRef = _firestore.collection("users").doc(user.uid);

    return _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      final data = snap.data() ?? {};

      int currentStreak = (data['currentStreak'] ?? 0) as int;
      int longestStreak = (data['longestStreak'] ?? 0) as int;

      final Timestamp? ts = data['lastActivityDate'] as Timestamp?;
      final DateTime? lastActivityDate = ts?.toDate();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      final int previousStreak = currentStreak;

      // streak logic
      if (lastActivityDate == null) {
        currentStreak = 1;
      } else if (_isSameDate(lastActivityDate, today)) {
        // no change
      } else if (_isSameDate(lastActivityDate, yesterday)) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }

      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      transaction.set(userRef, {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActivityDate': Timestamp.fromDate(today),
      }, SetOptions(merge: true));

      return {'previousStreak': previousStreak, 'newStreak': currentStreak};
    });
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: const EcoTrackHeader(),
        body: const Center(child: Text("You must be logged in.")),
        bottomNavigationBar: const EcoNavBar(currentIndex: -1),
      );
    }

    final String uid = user.uid;
    final DateTime today = DateTime.now();

    return Scaffold(
      appBar: const EcoTrackHeader(),
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // back arrow
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: const Color(0xff204E2A),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Text(
              'Activity Log',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('users')
                    .doc(uid)
                    .collection('activityLog')
                    .orderBy('activityString')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No activities yet.\nStart by creating one!",
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();

                      final String name = data['activityString'] ?? "";

                      final Timestamp? ts =
                          data['lastCompletedDate'] as Timestamp?;
                      final bool completedToday =
                          ts != null && _isSameDate(ts.toDate(), today);

                      final bool isChecked =
                          _selectedActivities[doc.id] ?? completedToday;
                      _selectedActivities[doc.id] = isChecked;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isChecked ? Colors.green[50] : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isChecked
                                ? Colors.green.withValues(alpha: 0.4)
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isChecked,
                              activeColor: Colors.green,
                              onChanged: (_) => _toggleActivity(doc),
                            ),

                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Color(0xFF2F5532),
                              ),
                              onPressed: () async {
                                try {
                                  await doc.reference.delete();
                                  setState(
                                    () => _selectedActivities.remove(doc.id),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Failed to delete activity.",
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // BUTTON
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final bool hasSelected = _selectedActivities.values.any(
                    (v) => v == true,
                  );

                  if (!hasSelected) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Select at least one activity."),
                      ),
                    );
                    return;
                  }

                  try {
                    final streak = await _updateStreak();

                    final badgeService = BadgeService(_firestore);
                    await badgeService.checkAndAwardBadges(uid);

                    if (!mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LogConfirmationScreen(
                          previousStreak: streak['previousStreak']!,
                          newStreak: streak['newStreak']!,
                        ),
                      ),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to update streak.")),
                    );
                  }
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Mark as Complete",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const EcoNavBar(currentIndex: -1),
    );
  }
}
