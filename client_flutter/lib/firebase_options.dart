import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'this project is for Android and Windows.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwis2I3KjySFxT_8BvcmDgQODqbQVvDMA',
    appId: '1:535899227507:android:eb490a29328c40e083b106',
    messagingSenderId: '535899227507',
    projectId: 'saka-manage',
    storageBucket: 'saka-manage.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDwtdMm69kVlqe0vSInUHUK7G5WtlXl3do',
    appId: '1:535899227507:web:0ea17a55dc184e6683b106',
    messagingSenderId: '535899227507',
    projectId: 'saka-manage',
    storageBucket: 'saka-manage.firebasestorage.app',
  );
}
