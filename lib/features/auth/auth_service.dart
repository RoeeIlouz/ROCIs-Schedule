import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth? _customAuth;
  final GoogleSignIn _googleSignIn;

  User? _user;
  User? get user => _user;
  bool get isAuthenticated => _user != null && !_user!.isAnonymous;
  bool get isGuest => _user == null || _user!.isAnonymous;
  String get effectiveUserId => _user?.uid ?? 'guest';

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _customAuth = auth,
      _googleSignIn = googleSignIn ?? GoogleSignIn() {
    _init();
  }

  FirebaseAuth get _auth {
    if (_customAuth != null) return _customAuth;
    return FirebaseAuth.instance;
  }

  void _init() {
    try {
      if (_customAuth != null || Firebase.apps.isNotEmpty) {
        _user = _auth.currentUser;
        _auth.authStateChanges().listen((User? user) {
          _user = user;
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('AuthService: Running in disconnected/test mode ($e)');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In...');

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential result = await _auth.signInWithPopup(
          googleProvider,
        );
        _user = result.user;
        notifyListeners();
        debugPrint(
          'Firebase Web Sign-In successful for: ${result.user?.email}',
        );
        return result;
      }

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
      _user = result.user;
      notifyListeners();
      debugPrint('Firebase Sign-In successful for: ${result.user?.email}');
      return result;
    } catch (e) {
      debugPrint('CRITICAL Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      debugPrint('Signing in with email: $email');
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = result.user;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error signing in with email: $e');
      rethrow;
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      debugPrint('Registering new user with email: $email');
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = result.user;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error registering with email: $e');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  Future<void> continueAsGuest() async {
    debugPrint('Continuing as guest session');
    _user = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    debugPrint('Signing out user...');

    // Clear local database cache to prevent data leakage between users
    await LocalDbService.clearCache();
    debugPrint('Local database cache cleared');

    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google sign out error: $e');
      }
    }

    try {
      if (_customAuth != null || Firebase.apps.isNotEmpty) {
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('Firebase sign out error: $e');
    }

    _user = null;
    notifyListeners();
    debugPrint('Sign out complete');
  }
}
