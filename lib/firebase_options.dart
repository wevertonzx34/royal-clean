// Android configuration from the Firebase console google-services.json.
// Register other platforms in royal-clean-fire before enabling them here.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'Firebase Royal Clean está configurado para Android. '
      'Cadastre esta plataforma no projeto royal-clean-fire e execute '
      'flutterfire configure antes de utilizá-la.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD6PkOHwUxBwjc7ljDNZC8vzfr-h3OsZ0I',
    appId: '1:589116886810:android:1c02b03ec2e428515ba6a3',
    messagingSenderId: '589116886810',
    projectId: 'royal-clean-fire',
    storageBucket: 'royal-clean-fire.firebasestorage.app',
  );
}
