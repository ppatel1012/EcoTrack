import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/eco_navbar.dart';
import 'pending_friend_requests_screen.dart';

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = false;
  List<_UserCandidate> _allCandidates = [];
  List<_UserCandidate> _filteredResults = [];

  static const _green = Color.fromARGB(255, 76, 175, 80);

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  // LOAD USERS EXCLUDING: self, current friends, already requested
  Future<void> _loadCandidates() async {
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _allCandidates = [];
        _filteredResults = [];
      });
      return;
    }

    final String uid = user.uid;

    try {
      // Get friend UIDs
      final friendsSnap = await firestore
          .collection('users')
          .doc(uid)
          .collection('friends')
          .get();

      final excludedIds = friendsSnap.docs
          .map((d) => (d.data()['friendUid'] ?? d.id) as String)
          .toSet();

      excludedIds.add(uid); // Exclude yourself

      // Get already-sent requests
      final sentRequestsSnap = await firestore
          .collection('friendRequests')
          .where('fromUid', isEqualTo: uid)
          .get();

      for (var doc in sentRequestsSnap.docs) {
        excludedIds.add(doc.data()['toUid'] as String? ?? '');
      }

      // Fetch all users
      final usersSnap = await firestore.collection('users').get();

      final List<_UserCandidate> candidates = [];

      for (final doc in usersSnap.docs) {
        if (excludedIds.contains(doc.id)) continue;

        final data = doc.data();
        final firstName = (data['firstName'] ?? '') as String;
        final lastName = (data['lastName'] ?? '') as String;
        final screenName = (data['screenName'] ?? '') as String;
        final email = (data['userEmail'] ?? '') as String;
        final String? profileImageUrl = data['profileImageUrl'] as String?;

        String displayName = '$firstName $lastName'.trim();
        if (displayName.isEmpty) {
          displayName = screenName.isNotEmpty
              ? screenName
              : (email.isNotEmpty ? email : 'Eco Friend');
        }

        candidates.add(
          _UserCandidate(
            uid: doc.id,
            displayName: displayName,
            firstName: firstName,
            lastName: lastName,
            screenName: screenName,
            userEmail: email,
            profileImageUrl: profileImageUrl,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _allCandidates = candidates;
        _filteredResults = candidates;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _allCandidates = [];
        _filteredResults = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load users. Please try again.'),
        ),
      );
    }
  }

  // LOCAL SEARCH (client-side)
  Future<void> _runSearch() async {
    final q = _controller.text.trim().toLowerCase();

    if (q.isEmpty) {
      setState(() => _filteredResults = _allCandidates);
      return;
    }

    setState(() {
      _filteredResults = _allCandidates
          .where((u) => u.displayName.toLowerCase().contains(q))
          .toList();
    });
  }

  // SEND FRIEND REQUEST
  Future<void> _sendFriendRequest(_UserCandidate candidate) async {
    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add friends.')),
      );
      return;
    }

    final uid = user.uid;

    try {
      String fromName = 'Eco Friend';

      final senderDoc = await firestore.collection('users').doc(uid).get();
      if (senderDoc.exists) {
        final data = senderDoc.data() ?? {};
        final first = (data['firstName'] ?? '') as String;
        final last = (data['lastName'] ?? '') as String;
        final screen = (data['screenName'] ?? '') as String;
        final email = user.email ?? '';

        final full = '$first $last'.trim();

        fromName = full.isNotEmpty
            ? full
            : (screen.isNotEmpty
                  ? screen
                  : (email.isNotEmpty ? email : 'Eco Friend'));
      }

      await firestore.collection('friendRequests').add({
        'fromUid': uid,
        'fromName': fromName,
        'toUid': candidate.uid,
        'toName': candidate.displayName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Remove from list immediately
      if (!mounted) return;

      setState(() {
        _allCandidates.removeWhere((u) => u.uid == candidate.uid);
        _filteredResults.removeWhere((u) => u.uid == candidate.uid);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${candidate.displayName}!'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send friend request.')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Add Friends',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _green,
        ),
        body: const Center(
          child: Text('You must be logged in to add friends.'),
        ),
        bottomNavigationBar: const EcoNavBar(currentIndex: -1),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Friends', style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox, color: Colors.white),
            tooltip: "Friend Requests",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PendingFriendRequestsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    decoration: InputDecoration(
                      hintText: 'Search by name',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _runSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredResults.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No new people to add right now.\n'
                        'Check back later as more eco friends join!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _filteredResults.length,
                    separatorBuilder: (_, __unused) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final candidate = _filteredResults[i];
                      return _FriendResultTile(
                        candidate: candidate,
                        onAdd: () => _sendFriendRequest(candidate),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const EcoNavBar(currentIndex: -1),
    );
  }
}

// DATA MODEL FOR SEARCH RESULTS
class _UserCandidate {
  final String uid;
  final String displayName;
  final String firstName;
  final String lastName;
  final String screenName;
  final String userEmail;
  final String? profileImageUrl;

  _UserCandidate({
    required this.uid,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.screenName,
    required this.userEmail,
    this.profileImageUrl,
  });
}

// UI TILE FOR EACH FRIEND SEARCH RESULT
class _FriendResultTile extends StatelessWidget {
  const _FriendResultTile({required this.candidate, required this.onAdd});

  final _UserCandidate candidate;
  final VoidCallback onAdd;

  static const _green = Color.fromARGB(255, 76, 175, 80);

  Widget _buildAvatar() {
    final url = candidate.profileImageUrl;
    final hasProfilePic = url != null && url.isNotEmpty;

    if (hasProfilePic) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(url!));
    }

    // Fallback: original green-ish background + white person icon
    return const CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white24,
      child: Icon(Icons.person, color: Colors.white),
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
              candidate.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),

          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: _green,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
