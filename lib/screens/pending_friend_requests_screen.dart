import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/eco_navbar.dart';

class PendingFriendRequestsScreen extends StatelessWidget {
  const PendingFriendRequestsScreen({super.key});

  static const _green = Color.fromARGB(255, 76, 175, 80);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Friend Requests',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _green,
        ),
        body: const Center(
          child: Text('You must be logged in to view friend requests.'),
        ),
        bottomNavigationBar: const EcoNavBar(currentIndex: -1),
      );
    }

    final uid = user.uid;

    // Stream of pending friend requests addressed to THIS user
    final requestsStream = FirebaseFirestore.instance
        .collection('friendRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Friend Requests',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _green,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: requestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No pending friend requests right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final String fromName =
                  (data['fromName'] ?? 'Eco Friend') as String;
              final String fromUid = (data['fromUid'] ?? '') as String;

              return _RequestTile(
                fromUid: fromUid,
                fromName: fromName,
                onAccept: () => _acceptRequest(context, doc.id, data),
                onDecline: () => _declineRequest(context, doc.id),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const EcoNavBar(currentIndex: -1),
    );
  }

  // ACCEPT FRIEND REQUEST
  Future<void> _acceptRequest(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final firestore = FirebaseFirestore.instance;

    final String fromUid = data['fromUid'] as String;
    final String toUid = data['toUid'] as String;
    final String fromName = (data['fromName'] ?? 'Eco Friend') as String;
    final String toName = (data['toName'] ?? 'Eco Friend') as String;

    final requestRef = firestore.collection('friendRequests').doc(requestId);

    try {
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(requestRef);
        if (!snap.exists) return;

        final status = (snap.data()!['status'] ?? 'pending') as String;
        if (status != 'pending') return;

        final userRefA = firestore.collection('users').doc(fromUid);
        final userRefB = firestore.collection('users').doc(toUid);

        // Add friend A → B
        tx.set(userRefA.collection('friends').doc(toUid), {
          'friendUid': toUid,
          'displayName': toName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Add friend B → A
        tx.set(userRefB.collection('friends').doc(fromUid), {
          'friendUid': fromUid,
          'displayName': fromName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Mark request as accepted
        tx.update(requestRef, {
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request accepted!')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not accept request. Please try again.'),
        ),
      );
    }
  }

  // DECLINE FRIEND REQUEST
  Future<void> _declineRequest(BuildContext context, String requestId) async {
    final firestore = FirebaseFirestore.instance;
    final requestRef = firestore.collection('friendRequests').doc(requestId);

    try {
      await requestRef.update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request declined.')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not decline request. Please try again.'),
        ),
      );
    }
  }
}

// UI TILE FOR EACH REQUEST
class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.fromUid,
    required this.fromName,
    required this.onAccept,
    required this.onDecline,
  });

  final String fromUid;
  final String fromName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  static const _green = Color.fromARGB(255, 76, 175, 80);

  /// Load the sender's user doc and build the avatar:
  /// - If profileImageUrl exists -> show it
  /// - Else -> original green circle with white person icon
  Widget _buildAvatar() {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(fromUid).get(),
      builder: (context, snapshot) {
        String? profileUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          profileUrl = data?['profileImageUrl'] as String?;
        }

        if (profileUrl != null && profileUrl.isNotEmpty) {
          return CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage(profileUrl),
          );
        }

        // Fallback: original styling
        return const CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white24,
          child: Icon(Icons.person, color: Colors.white),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),

          Expanded(
            child: Text(
              fromName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),

          // Decline button
          TextButton(
            onPressed: onDecline,
            child: const Text(
              'Decline',
              style: TextStyle(color: Colors.white70),
            ),
          ),

          const SizedBox(width: 4),

          // Accept button
          Material(
            color: Colors.white,
            shape: const StadiumBorder(),
            elevation: 2,
            child: InkWell(
              onTap: onAccept,
              customBorder: const StadiumBorder(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Accept',
                  style: TextStyle(color: _green, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
