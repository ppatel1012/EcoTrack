import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/add_post_screen.dart';

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('You must be logged in to view the community feed.'),
        ),
      );
    }

    final String uid = user.uid;

    return Scaffold(
      body: Column(
        children: [
          // Header + Add Post button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Community Feed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddPostScreen()),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add a post"),
                  style:
                      OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ).copyWith(
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.pressed)) {
                                return Colors.green;
                              }
                              return Colors.transparent;
                            }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.pressed)) {
                                return Colors.white;
                              }
                              return Colors.green;
                            }),
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Feed list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('posts')
                  .orderBy('createdAt', descending: true)
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
                        'No posts yet.\nBe the first to share an eco win!',
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
                    final doc = docs[index];
                    final data = doc.data();

                    final String username =
                        (data['authorName'] ?? data['username'] ?? 'Eco Friend')
                            as String;
                    final String description =
                        (data['text'] ?? data['description'] ?? '') as String;
                    final String? imageUrl = data['imageUrl'] as String?;
                    final Timestamp? createdTs =
                        data['createdAt'] as Timestamp?;
                    final int initialLikes = (data['likes'] ?? 0) as int;

                    // get the author's uid so we can load their profile image
                    final String authorId = (data['authorId'] ?? '') as String;

                    // Safely handle missing arrays
                    final List<String> likedBy =
                        (data['likedBy'] as List<dynamic>? ?? [])
                            .map((e) => e.toString())
                            .toList();
                    final List<String> inspiredBy =
                        (data['inspiredBy'] as List<dynamic>? ?? [])
                            .map((e) => e.toString())
                            .toList();

                    final bool initiallyLiked = likedBy.contains(uid);
                    final bool initiallyInspired = inspiredBy.contains(uid);

                    String timeAgo = 'just now';
                    if (createdTs != null) {
                      timeAgo = _formatTimeAgo(createdTs.toDate());
                    }

                    return PostCard(
                      postId: doc.id,
                      currentUserId: uid,
                      authorId: authorId,
                      username: username,
                      timeAgo: timeAgo,
                      description: description,
                      imageUrl: imageUrl,
                      initialLikes: initialLikes,
                      initiallyLiked: initiallyLiked,
                      initiallyInspired: initiallyInspired,
                    );
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

/// A single post card with its own state for likes and "Inspired" status.
class PostCard extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String authorId;
  final String username;
  final String timeAgo;
  final String description;
  final String? imageUrl; // can be asset or network
  final int initialLikes;
  final bool initiallyLiked;
  final bool initiallyInspired;

  const PostCard({
    super.key,
    required this.postId,
    required this.currentUserId,
    required this.authorId,
    required this.username,
    required this.timeAgo,
    required this.description,
    required this.initialLikes,
    required this.initiallyLiked,
    required this.initiallyInspired,
    this.imageUrl,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int _likes;
  late bool _isLiked;
  late bool _isInspired;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLikes;
    _isLiked = widget.initiallyLiked;
    _isInspired = widget.initiallyInspired;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _isLiked;
    final previousLikes = _likes;

    setState(() {
      if (_isLiked) {
        if (_likes > 0) _likes -= 1;
        _isLiked = false;
      } else {
        _likes += 1;
        _isLiked = true;
      }
    });

    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId);

    try {
      if (wasLiked) {
        // user is un-liking
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([widget.currentUserId]),
        });
      } else {
        // user is liking
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([widget.currentUserId]),
        });
      }
    } catch (_) {
      // revert UI if something goes wrong
      if (!mounted) return;
      setState(() {
        _isLiked = wasLiked;
        _likes = previousLikes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update like. Please try again.'),
        ),
      );
    }
  }

  Future<void> _toggleInspired() async {
    final wasInspired = _isInspired;

    setState(() {
      _isInspired = !_isInspired;
    });

    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId);

    try {
      if (wasInspired) {
        // remove inspiration
        await postRef.update({
          'inspiredBy': FieldValue.arrayRemove([widget.currentUserId]),
        });
      } else {
        // add inspiration
        await postRef.update({
          'inspiredBy': FieldValue.arrayUnion([widget.currentUserId]),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isInspired
                ? 'Love that you\'re inspired by this post! 🌱'
                : 'Inspiration toggled off. You can tap it again anytime.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      // revert UI if error
      if (!mounted) return;
      setState(() {
        _isInspired = wasInspired;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update inspiration. Please try again.'),
        ),
      );
    }
  }

  Widget? _buildImage() {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return null;

    final bool isNetwork = url.startsWith('http');

    final imageWidget = isNetwork
        ? Image.network(url, fit: BoxFit.cover)
        : Image.asset(url, fit: BoxFit.cover);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageWidget,
    );
  }

  /// Build the profile avatar using profileImageUrl from users/{authorId}
  /// If none, fall back to the original green circle with person icon.
  Widget _buildAuthorAvatar() {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.authorId)
          .get(),
      builder: (context, snapshot) {
        String? profileUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data();
          profileUrl = userData?['profileImageUrl'] as String?;
        }

        if (profileUrl != null && profileUrl.isNotEmpty) {
          return CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green,
            backgroundImage: NetworkImage(profileUrl),
          );
        } else {
          return const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green,
            child: Icon(Icons.person, color: Colors.white),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = _buildImage();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: user and time
            Row(
              children: [
                _buildAuthorAvatar(),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      widget.timeAgo,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (imageWidget != null) ...[
              imageWidget,
              const SizedBox(height: 12),
            ],

            // Description
            Text(
              widget.description,
              style: const TextStyle(fontSize: 15, height: 1.3),
            ),

            const SizedBox(height: 12),

            // Likes and Inspired buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Heart (like) button
                Row(
                  children: [
                    IconButton(
                      onPressed: _toggleLike,
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('$_likes Likes'),
                  ],
                ),

                // Inspired button
                OutlinedButton.icon(
                  onPressed: _toggleInspired,
                  icon: Icon(
                    _isInspired ? Icons.lightbulb : Icons.lightbulb_outline,
                  ),
                  label: Text(_isInspired ? 'Inspired!' : 'Inspired'),
                  style:
                      OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ).copyWith(
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                              if (_isInspired ||
                                  states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.pressed)) {
                                return Colors.green;
                              }
                              return Colors.transparent;
                            }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                              if (_isInspired ||
                                  states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.pressed)) {
                                return Colors.white;
                              }
                              return Colors.green;
                            }),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';

  return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
}
