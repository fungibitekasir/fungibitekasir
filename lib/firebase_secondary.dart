import 'package:firebase_core/firebase_core.dart';

class SecondaryFirebase {
  static FirebaseApp? _app;

  static Future<FirebaseApp> get secondaryApp async {
    if (_app != null) return _app!;

    _app = await Firebase.initializeApp(
      name: 'secondary',
      options: Firebase.app().options,
    );

    return _app!;
  }
}
