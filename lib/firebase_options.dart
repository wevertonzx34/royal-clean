// Firebase configuration registered in royal-clean-fire.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'Firebase Royal Clean está configurado para Android. '
      'Cadastre esta plataforma no projeto royal-clean-fire e execute '
      'flutterfire configure antes de utilizá-la.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDPQ_SniaYRnx6dOnl0rCtZwyO-WzIJ_EM',
    appId: '1:589116886810:web:727e7e73d00f16d45ba6a3',
    messagingSenderId: '589116886810',
    projectId: 'royal-clean-fire',
    authDomain: 'royal-clean-fire.firebaseapp.com',
    storageBucket: 'royal-clean-fire.firebasestorage.app',
    measurementId: 'G-544VZ9FWD4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD6PkOHwUxBwjc7ljDNZC8vzfr-h3OsZ0I',
    appId: '1:589116886810:android:1c02b03ec2e428515ba6a3',
    messagingSenderId: '589116886810',
    projectId: 'royal-clean-fire',
    storageBucket: 'royal-clean-fire.firebasestorage.app',
  );
}
