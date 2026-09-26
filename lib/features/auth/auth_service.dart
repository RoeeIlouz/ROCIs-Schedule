import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/services/guest_data_migrator.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth? _customAuth;
  final GoogleSignIn _googleSignIn;

  User? _user;
  Future<void>? _migration;

  User? get user => _user;
  bool get isAuthenticated => _user != null && !_user!.isAnonymous;
  bool get isGuest => _user == null || _user!.isAnonymous;
  String get effectiveUserId => _user?.uid ?? GuestDataMigrator.guestUserId;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _customAuth = auth,
      _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            serverClientId:
                '318456267857-u9mr5ssmdd76944000ggf34vv7pkqufc.apps.googleusercontent.com',
            scopes: ['email', 'profile'],
          ) {
    _init();
  }

  FirebaseAuth get _auth {
    if (_customAuth != null) return _customAuth;
    return FirebaseAuth.instance;
  }

  Future<void> _init() async {
    try {
      if (_customAuth != null || Firebase.apps.isNotEmpty) {
        _user = _auth.currentUser;
        _auth.authStateChanges().listen(_setUser);
      }
    } catch (e) {
      debugPrint('AuthService: Running in disconnected/test mode ($e)');
    }
  }

  /// A guest signing in first has their local data moved into the account,
  /// before the account's providers load. Sign-in and the auth stream both
  /// land here, so they share one migration.
  Future<void> _setUser(User? user) async {
    if (user != null && !user.isAnonymous && isGuest) {
      await (_migration ??= GuestDataMigrator.migrateInto(
        user.uid,
      ).whenComplete(() => _migration = null));
    }
    _user = user;
    notifyListeners();
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In...');

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential result = await _auth.signInWithPopup(
          googleProvider,
        );
        await _setUser(result.user);
        debugPrint(
          'Firebase Web Sign-In successful for: ${result.user?.email}',
        );
        return result;
      }

      // Ensure any previous session is cleared so user can always pick an account
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google Sign-In aborted by user.');
        return null;
      }

      debugPrint('Google User obtained: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint(
        'Obtaining Firebase credential (idToken: ${googleAuth.idToken != null}, accessToken: ${googleAuth.accessToken != null})...',
      );
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception(
          'Google Sign-In failed: No authorization tokens received from Google Play Services.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      await _setUser(result.user);
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
      await _setUser(result.user);
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
      await _setUser(result.user);
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
