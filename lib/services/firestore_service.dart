import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Create a new user document with default values under the firebase userId
  Future<void> createUser({
    required String userId,
    required String email,
    String firstName = '',
    String lastName = '',
    String screenName = '',
    int currentStreak = 0,
    int longestStreak = 0,
  }) async {
    await _db.collection('users').doc(userId).set({
      'firstName': firstName,
      'lastName': lastName,
      'screenName': screenName,
      'userEmail': email,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,

    });
  }

}

// Add friend and activity collection should be done in it's respective screen