import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FriendsPreview extends StatelessWidget {
  const FriendsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(
        child: Text(
          'Log in to see friends',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final friendsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .orderBy('createdAt', descending: true)
        .limit(3) // top couple of friends
        .snapshots();

    return Container(
      decoration: BoxDecoration(
        color: Colors.green[500],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: friendsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'No friends yet.\nAdd some from the Friends Log tab!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final friendUid = (data['friendUid'] ?? docs[index].id) as String;
              final displayName =
                  (data['displayName'] ?? 'Eco Friend') as String;

              return _FriendMiniTile(
                friendUid: friendUid,
                displayName: displayName,
              );
            },
          );
        },
      ),
    );
  }
}

class _FriendMiniTile extends StatelessWidget {
  final String friendUid;
  final String displayName;

  const _FriendMiniTile({required this.friendUid, required this.displayName});

  String _streakLabel(int streak) {
    if (streak <= 0) return 'Current streak: 0 days';
    if (streak == 1) return 'Current streak: 1 day';
    return 'Current streak: $streak days';
  }

  @override
  Widget build(BuildContext context) {
    final friendDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(friendUid)
        .snapshots();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green[500],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Avatar that uses profileImageUrl if present, else default
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: friendDocStream,
            builder: (context, snapshot) {
              String? profileUrl;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() ?? {};
                profileUrl = data['profileImageUrl'] as String?;
              }

              if (profileUrl != null && profileUrl.isNotEmpty) {
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color.fromARGB(60, 255, 255, 255),
                  backgroundImage: NetworkImage(profileUrl),
                );
              }

              // Fallback: original green-ish circle with person icon
              return const CircleAvatar(
                radius: 18,
                backgroundColor: Color.fromARGB(60, 255, 255, 255),
                child: Icon(Icons.person, color: Colors.white, size: 28),
              );
            },
          ),
          const SizedBox(width: 10),

          // Name + streak (still from stream, reusing same doc stream)
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: friendDocStream,
              builder: (context, snapshot) {
                String subtitle = 'Eco streak loading...';

                if (snapshot.connectionState == ConnectionState.waiting) {
                  subtitle = 'Loading streak...';
                } else if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() ?? {};
                  final streak = (data['currentStreak'] ?? 0) as int;
                  subtitle = _streakLabel(streak);
                } else if (snapshot.hasError) {
                  subtitle = 'Unable to load streak';
                } else {
                  subtitle = 'Current streak: 0 days';
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
