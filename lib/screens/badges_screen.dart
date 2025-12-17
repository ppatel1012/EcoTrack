import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[d.month - 1];
    return 'Obtained on $month ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in to view your badges.')),
      );
    }

    final String uid = user.uid;

    final badgesQuery = firestore
        .collection('users')
        .doc(uid)
        .collection('badges')
        .orderBy('earnedAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Your Badges', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: badgesQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'You haven\'t earned any badges yet.\n'
                  'Keep completing eco activities to unlock badges!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final String name = (data['name'] ?? 'Unnamed Badge') as String;
              final String description = (data['description'] ?? '') as String;
              final Timestamp? earnedAtTs = data['earnedAt'] as Timestamp?;
              final String dateLabel = earnedAtTs != null
                  ? _formatDate(earnedAtTs)
                  : 'Date unknown';

              final String iconAsset =
                  (data['iconAsset'] ?? 'assets/icons/badge_icon.png')
                      as String;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Image.asset(
                    iconAsset,
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) Text(description),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
