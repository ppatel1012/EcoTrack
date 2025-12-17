import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CommunityPreview extends StatelessWidget {
  const CommunityPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true) // latest post
        .limit(1)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
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
                'No posts yet.\nShare an eco win from the Community tab!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final data = snapshot.data!.docs.first.data();
        final authorName = (data['authorName'] ?? 'Eco Friend') as String;
        final text = (data['text'] ?? '') as String;
        final imageUrl = data['imageUrl'] as String?;
        final String authorId = (data['authorId'] ?? '') as String;

        return Card(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AuthorAvatar(authorId: authorId),
                const SizedBox(width: 12),

                // Name + text
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.3),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(
                          imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final String authorId;

  const _AuthorAvatar({required this.authorId});

  @override
  Widget build(BuildContext context) {
    if (authorId.isEmpty) {
      // fallback if post doesn't have an authorId
      return const CircleAvatar(
        radius: 26,
        backgroundColor: Colors.green,
        child: Icon(Icons.person, color: Colors.white, size: 28),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(authorId)
          .get(),
      builder: (context, snapshot) {
        String? profileUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() ?? {};
          profileUrl = data['profileImageUrl'] as String?;
        }

        if (profileUrl != null && profileUrl.isNotEmpty) {
          return CircleAvatar(
            radius: 26,
            backgroundColor: Colors.green,
            backgroundImage: NetworkImage(profileUrl),
          );
        }

        // Fallback: original green circle with person icon
        return const CircleAvatar(
          radius: 26,
          backgroundColor: Colors.green,
          child: Icon(Icons.person, color: Colors.white, size: 28),
        );
      },
    );
  }
}
