import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  User? get user => _user;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google Sign-In aborted by user.');
        return null;
      }

      debugPrint('Google User obtained: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint('Obtaining Firebase credential...');
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      debugPrint('Firebase Sign-In successful for: ${result.user?.email}');
      return result;
    } catch (e) {
      debugPrint('CRITICAL Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    debugPrint('Signing out user...');
    
    // Clear local database cache to prevent data leakage between users
    await LocalDbService.clearCache();
    debugPrint('Local database cache cleared');
    
    await _googleSignIn.signOut();
    await _auth.signOut();
    debugPrint('Sign out complete');
  }
}
