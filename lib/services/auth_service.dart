import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _fs = FirestoreService();

  Future<User?> signUp({
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
    String screenName = '',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;

      //Save additional user info to Firestore database
      if (user != null) {
        // Create user document with default values
        await _fs.createUser(
          userId: user.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          screenName: screenName,
        );
      }
      print('Writing to Firestore: $firstName $lastName ($email)');
      return user;
    } on FirebaseAuthException catch (e) {
      print('Sign-up error: ${e.message}');
      return null;
    }
  }

  //  Sign In
  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print('Sign-in error: ${e.message}');
      return null;
    }
  }

  //  Sign Out
  Future<void> signOut() async => _auth.signOut();

  // Stream of current user
  Stream<User?> get userStream => _auth.authStateChanges();
}