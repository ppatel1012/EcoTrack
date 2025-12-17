import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/eco_header.dart';
import '../widgets/eco_navbar.dart';
import '../screens/social_screen.dart';
import '../screens/log_activity_screen.dart';
import '../screens/diary_screen.dart';
import '../widgets/community_preview.dart';
import '../widgets/friends_preview.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? currentStreak;
  String? displayName;
  bool loading = true;

  // Make sure we only check once per mount
  bool _nudgesChecked = false;

  // UI state for the nudge popup
  bool _showNudgePopup = false;
  String? _nudgeFromLabel;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkForNudges(); // check for nudges when the home screen loads
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => loading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() => loading = false);
        return;
      }

      final data = doc.data() ?? {};

      final first = (data['firstName'] ?? '').toString();
      final last = (data['lastName'] ?? '').toString();
      final screen = (data['screenName'] ?? '').toString();
      final fullName = '$first $last'.trim();

      setState(() {
        currentStreak = (data['currentStreak'] ?? 0) as int;
        displayName = fullName.isNotEmpty ? fullName : screen;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  /// Check Firestore for the newest nudge for this user.
  /// If found, show a popup once and then delete all nudges.
  Future<void> _checkForNudges() async {
    if (_nudgesChecked) return;
    _nudgesChecked = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;

    try {
      final snap = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('nudges')
          .orderBy('createdAt', descending: true)
          .get();

      if (snap.docs.isEmpty) return;

      // Latest nudge
      final latestDoc = snap.docs.first;
      final data = latestDoc.data();
      final fromEmail = (data['fromEmail'] ?? '') as String;
      final fromLabel = fromEmail.isNotEmpty ? fromEmail : 'an eco friend';

      if (!mounted) return;

      // Show center popup
      setState(() {
        _nudgeFromLabel = fromLabel;
        _showNudgePopup = true;
      });

      // Auto-dismiss after a few seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        if (_showNudgePopup) {
          setState(() {
            _showNudgePopup = false;
          });
        }
      });

      // After showing the popup, delete ALL nudges so they are only seen once.
      for (final d in snap.docs) {
        await d.reference.delete();
      }
    } catch (_) {
      // Silently fail – this feature is "nice to have", not critical
    }
  }

  void _navigateToSocialTab(BuildContext context, int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SocialScreen(initialTabIndex: index)),
    );
  }

  void _navigateToDiary(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LogActivityScreen()),
    );
  }

  void _navigateToStreaks(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DiaryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EcoTrackHeader(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Main content
                Column(
                  children: [
                    // TOP ROW: My Log + Streak
                    Expanded(
                      child: Row(
                        children: [
                          // My Log
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _navigateToDiary(context),
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[200],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.green.shade300,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _NotepadLinesPainter(),
                                      ),
                                    ),
                                    const Center(
                                      child: Text(
                                        'My Log\n✍️',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Cursive',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Current streak (uses real data)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _navigateToStreaks(context),
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[300],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${currentStreak ?? 0}🔥',
                                        style: const TextStyle(
                                          fontSize: 60,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // MIDDLE: Friends Log preview
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _navigateToSocialTab(context, 1),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[500],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: const [
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Friends Log',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: FriendsPreview(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // BOTTOM: Community Feed preview
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _navigateToSocialTab(context, 0),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[700],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: const [
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.groups, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Community Feed',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: CommunityPreview(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Nudge popup overlay
                if (_showNudgePopup && _nudgeFromLabel != null)
                  Positioned.fill(
                    child: GestureDetector(
                      // Tap outside also closes
                      onTap: () {
                        setState(() {
                          _showNudgePopup = false;
                        });
                      },
                      child: Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          // So taps inside the card don’t close automatically
                          onTap: () {},
                          child: _NudgePopup(
                            fromLabel: _nudgeFromLabel!,
                            onClose: () {
                              setState(() {
                                _showNudgePopup = false;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: const EcoNavBar(currentIndex: 0),
    );
  }
}

class _NotepadLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = 1;

    const spacing = 20.0;
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Center popup card for nudges
class _NudgePopup extends StatelessWidget {
  const _NudgePopup({required this.fromLabel, required this.onClose});

  final String fromLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 12,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with title + close button
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You got a nudge!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  splashRadius: 20,
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$fromLabel sent you a friendly eco reminder 🌱',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Keep your streak going!',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
