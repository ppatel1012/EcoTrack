import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeService {
  final FirebaseFirestore firestore;

  BadgeService(this.firestore);

  Future<void> checkAndAwardBadges(String uid) async {
    final userRef = firestore.collection('users').doc(uid);

    final userSnap = await userRef.get();
    final userData = userSnap.data() ?? {};

    final int longestStreak = userData['longestStreak'] ?? 0;

    final completionsSnap = await userRef
        .collection('activityCompletions')
        .get();
    final int totalCompletions = completionsSnap.docs.length;

    final activitiesSnap = await userRef.collection('activityLog').get();
    final int distinctActivities = activitiesSnap.docs.length;

    final defsSnap = await firestore.collection('badgeDefinitions').get();

    for (final def in defsSnap.docs) {
      final data = def.data();

      final String badgeId = def.id;
      final String criteriaType = data['criteriaType'];
      final int requiredValue = data['criteriaValue'];

      bool qualifies = false;

      switch (criteriaType) {
        case 'totalCompletions':
          qualifies = totalCompletions >= requiredValue;
          break;
        case 'longestStreak':
          qualifies = longestStreak >= requiredValue;
          break;
        case 'distinctActivities':
          qualifies = distinctActivities >= requiredValue;
          break;
      }

      if (!qualifies) continue;

      final existing = await userRef.collection('badges').doc(badgeId).get();
      if (existing.exists) continue;

      await userRef.collection('badges').doc(badgeId).set({
        'name': data['name'],
        'description': data['description'],
        'iconAsset': data['iconAsset'],
        'earnedAt': Timestamp.now(),
      });
    }
  }
}
