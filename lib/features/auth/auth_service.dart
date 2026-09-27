import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/core/config/app_config.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/guest_data_migrator.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';
import 'package:rocis_schedule/shared/services/tasks_firestore_service.dart';

class AuthService extends ChangeNotifier {
  static const _serverClientId =
      '318456267857-u9mr5ssmdd76944000ggf34vv7pkqufc.apps.googleusercontent.com';
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
            serverClientId: _serverClientId,
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
        if (isAuthenticated) unawaited(_restoreTasksSignIn());
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

  /// Accounts signed in before ROCIs Tasks sync existed have no rocis-todo
  /// session yet; on Android, Google hands back a token without any UI.
  Future<void> _restoreTasksSignIn() async {
    if (kIsWeb || AppConfig.isGithubBuild) return;
    if (await TasksFirestoreService.isSignedIn) return;
    try {
      final account = await _googleSignIn.signInSilently();
      final token = (await account?.authentication)?.accessToken;
      if (token != null) {
        await TasksFirestoreService.signInWithGoogleAccessToken(token);
      }
    } catch (e) {
      debugPrint('AuthService: ROCIs Tasks sign-in restore skipped: $e');
    }
  }

  /// Also signs in to ROCIs Tasks so synced tasks can load. Not awaited:
  /// signing in to Schedule never waits on it or fails because of it.
  void _signInToTasks(AuthCredential? credential) {
    final token = credential?.accessToken;
    if (token != null) {
      unawaited(TasksFirestoreService.signInWithGoogleAccessToken(token));
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In...');

      if (AppConfig.isGithubBuild && !kIsWeb) {
        // Browser-based Google sign-in through the web OAuth client.
        final result = await _auth.signInWithProvider(GoogleAuthProvider());
        _signInToTasks(result.credential);
        await _setUser(result.user);
        return result;
      }

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential result = await _auth.signInWithPopup(
          googleProvider,
        );
        _signInToTasks(result.credential);
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
      _signInToTasks(credential);
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
      unawaited(TasksFirestoreService.signInWithEmail(email, password));
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

    await TasksFirestoreService.signOut();
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

  /// Lets the app create its own calendars and manage only their events.
  static const calendarScope =
      'https://www.googleapis.com/auth/calendar.app.created';

  /// Google Sign-In for Calendar. On Android, access tokens only carry the
  /// scopes a client was configured with (`requestScopes` grants consent but
  /// never adds the scope to later tokens), so Calendar needs its own client.
  /// The native client is shared, so it keeps the same server client ID and
  /// sign-in keeps producing Firebase ID tokens.
  late final GoogleSignIn _calendarSignIn = GoogleSignIn(
    serverClientId: _serverClientId,
    scopes: const ['email', 'profile', calendarScope],
  );

  /// Why the last Calendar authorization failed (null if the user cancelled).
  String? lastCalendarAuthError;

  /// Authorization headers for Google Calendar, or null if the user hasn't
  /// granted access. With [interactive] the user may pick an account and
  /// approve the calendar permission; otherwise nothing is shown.
  Future<Map<String, String>?> googleCalendarHeaders({
    required bool interactive,
    bool refresh = false,
  }) async {
    lastCalendarAuthError = null;
    try {
      var account = await _calendarSignIn.signInSilently();
      if (account == null && interactive) {
        account = await _calendarSignIn.signIn();
      }
      if (account == null) return null;
      if (refresh) await account.clearAuthCache();
      return await account.authHeaders;
    } catch (e) {
      debugPrint('Google Calendar authorization failed: $e');
      lastCalendarAuthError = e.toString();
      return null;
    }
  }

  /// Whether the account signs in with a password (so deleting it needs one).
  bool get usesPassword =>
      _user?.providerData.any((p) => p.providerId == 'password') ?? false;

  /// Permanently deletes the signed-in account: its cloud data, the sign-in
  /// record and this device's copy. Firebase only deletes accounts after a
  /// recent sign-in, so the user confirms their identity first — with
  /// [password] for email accounts, otherwise through Google.
  ///
  /// Returns false if the user cancelled the Google confirmation.
  Future<bool> deleteAccount(
    FirestoreService firestore, {
    String? password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    if (usesPassword) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password!),
      );
    } else if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    } else if (AppConfig.isGithubBuild) {
      await user.reauthenticateWithProvider(GoogleAuthProvider());
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
    }

    // Data first: once the auth record is gone, security rules deny access.
    final uid = user.uid;
    await firestore.deleteAllUserData(uid);
    await user.delete();

    await LocalDbService.deleteDatabaseFor(uid);
    await TasksFirestoreService.signOut();
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    _user = null;
    notifyListeners();
    return true;
  }
}
