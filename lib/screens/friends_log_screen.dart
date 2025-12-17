import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_friend_screen.dart';
import 'pending_friend_requests_screen.dart';

class FriendsLogScreen extends StatelessWidget {
  const FriendsLogScreen({super.key});

  static const _green = Color.fromARGB(255, 76, 175, 80);

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('You must be logged in to view your friends.'),
        ),
      );
    }

    final String uid = user.uid;

    return Scaffold(
      body: Column(
        children: [
          // Header + Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Friends Log',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                // Row of 2 buttons
                Row(
                  children: [
                    // Add Friend
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddFriendsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text("Add"),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _green, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // View Pending Requests
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PendingFriendRequestsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.mail_outline_rounded),
                      label: const Text("Requests"),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _green, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('users')
                  .doc(uid)
                  .collection('friends')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'You haven\'t added any friends yet.\n'
                        'Tap "Add" to connect and see their eco wins!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final String friendUid =
                        (data['friendUid'] ?? docs[index].id) as String;

                    return FriendActivityTile(friendUid: friendUid);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FriendActivityTile extends StatelessWidget {
  const FriendActivityTile({super.key, required this.friendUid});

  final String friendUid;

  static const _green = Color.fromARGB(255, 76, 175, 80);

  String _buildDisplayName(Map<String, dynamic> data) {
    final firstName = (data['firstName'] ?? '') as String;
    final lastName = (data['lastName'] ?? '') as String;
    final screenName = (data['screenName'] ?? '') as String;
    final email = (data['userEmail'] ?? '') as String;

    final full = '$firstName $lastName'.trim();
    if (full.isNotEmpty) return full;
    if (screenName.isNotEmpty) return screenName;
    if (email.isNotEmpty) return email;
    return 'Eco Friend';
  }

  String _buildStreakLabel(int streak) {
    if (streak <= 0) return 'Current streak: 0 days';
    return 'Current streak: $streak ${streak == 1 ? "day" : "days"}';
  }

  Future<void> _sendNudge(BuildContext context, String friendName) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final user = auth.currentUser;

    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You must be logged in to send a nudge.')),
      );
      return;
    }

    try {
      await firestore
          .collection('users')
          .doc(friendUid)
          .collection('nudges')
          .add({
            'fromUid': user.uid,
            'fromEmail': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });

      messenger.showSnackBar(
        SnackBar(content: Text('Reminder sent to $friendName!')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to send nudge.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(friendUid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, snapshot) {
        String friendName = 'Eco Friend';
        String subtitle = 'Loading streak...';
        String? profileImageUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() ?? {};
          friendName = _buildDisplayName(data);
          subtitle = _buildStreakLabel((data['currentStreak'] ?? 0) as int);
          profileImageUrl = data['profileImageUrl'] as String?;
        }

        final bool hasProfilePic =
            profileImageUrl != null && profileImageUrl!.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar: profile photo if present, else original style
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white24,
                backgroundImage: hasProfilePic
                    ? NetworkImage(profileImageUrl!)
                    : null,
                child: hasProfilePic
                    ? null
                    : const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friendName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Column(
                children: [
                  const Text(
                    'nudge',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => _sendNudge(context, friendName),
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.amber,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
