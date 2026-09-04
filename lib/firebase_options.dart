// File generated for rocis-schedule Firebase project.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD2OHYo8F6h486p58HkL8VCFDSdu7HH67c',
    appId: '1:318456267857:web:0d72df7ff505f88c53a470',
    messagingSenderId: '318456267857',
    projectId: 'rocis-schedule',
    authDomain: 'rocis-schedule.firebaseapp.com',
    databaseURL:
        'https://rocis-schedule-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'rocis-schedule.firebasestorage.app',
    measurementId: 'G-K0V8B4QXDM',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDfHAfG-A3o0ZUyMtudxKkah6wsTKy9z10',
    appId: '1:318456267857:android:4e12279b28b58c3353a470',
    messagingSenderId: '318456267857',
    projectId: 'rocis-schedule',
    databaseURL:
        'https://rocis-schedule-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'rocis-schedule.firebasestorage.app',
  );
}
