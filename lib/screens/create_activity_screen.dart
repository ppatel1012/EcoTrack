import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/eco_header.dart';
import '../widgets/eco_navbar.dart';
import '../screens/activity_confirmation_screen.dart';

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final TextEditingController _controller = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  List<String> _existingActivities = [];
  String? _similarWarning;

  @override
  void initState() {
    super.initState();
    _loadExistingActivities();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Load existing activities for duplicate/similar detection
  Future<void> _loadExistingActivities() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activityLog')
        .get();

    setState(() {
      _existingActivities = snap.docs
          .map((d) => (d['activityString'] as String).toLowerCase())
          .toList();
    });
  }

  // Proper capitalization
  String _toTitleCase(String input) {
    return input
        .trim()
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  // Similar activity detection as user types
  void _onActivityChanged(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty) {
      setState(() => _similarWarning = null);
      return;
    }

    String? similar;
    for (final existing in _existingActivities) {
      if (existing == normalized ||
          existing.contains(normalized) ||
          normalized.contains(existing)) {
        similar = existing;
        break;
      }
    }

    setState(() {
      _similarWarning = similar == null
          ? null
          : 'Similar activity already exists: "${_toTitleCase(similar)}"';
    });
  }

  // Save final activity to Firestore
  Future<void> _saveActivity() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an activity before adding.'),
        ),
      );
      return;
    }

    final activity = _toTitleCase(raw);
    final lower = activity.toLowerCase();

    // Final duplicate check
    final alreadyExists = _existingActivities.any((a) => a == lower);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already saved this activity.')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to add activities.'),
        ),
      );
      return;
    }

    // Write new Firestore doc with auto-ID
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activityLog')
        .add({
          'activityString': activity,
          'isComplete': false,
          'timesCompleted': 0,
        });

    // Update local list so they can't add again while still on this screen
    setState(() => _existingActivities.add(lower));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityConfirmationScreen(activity: activity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EcoTrackHeader(),

      extendBody: true,
      backgroundColor: Colors.transparent,
      bottomNavigationBar: const EcoNavBar(currentIndex: -1),

      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDFF2E1), Color(0xFFB7E4C7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back arrow
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: const Color(0xFF204E2A),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Center content
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),

                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),

                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        // Header text
                        const Text(
                          'Create Activity',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF204E2A),
                          ),
                        ),

                        const SizedBox(height: 4),
                        const Text(
                          'Save a new eco-friendly action so you can log it quickly later.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Text input
                        TextField(
                          controller: _controller,
                          onChanged: _onActivityChanged,
                          textInputAction: TextInputAction.done,

                          decoration: InputDecoration(
                            labelText: 'Activity name',
                            hintText: 'e.g. Bike to class instead of driving',
                            labelStyle: const TextStyle(color: Colors.black54),
                            hintStyle: const TextStyle(color: Colors.black38),
                            filled: true,
                            fillColor: const Color(0xFFF9FBF9),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF9EAD9F),
                                width: 1.2,
                              ),
                            ),

                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                              borderSide: BorderSide(
                                color: Color(0xFF4CAF50),
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        // Similar warning
                        if (_similarWarning != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _similarWarning!,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Add activity button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveActivity,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Add Activity',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Tip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 18,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'Tip: Keep it short and specific so it’s easy to complete.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
