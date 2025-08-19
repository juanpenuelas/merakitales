import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyDkhY8P3z__1JZfXjJ8GwXzJmt1ehtUqI4",
            authDomain: "merakitales-5rltbl.firebaseapp.com",
            projectId: "merakitales-5rltbl",
            storageBucket: "merakitales-5rltbl.appspot.com",
            messagingSenderId: "650643926570",
            appId: "1:650643926570:web:c706eca9cbf1aa02665d53"));
  } else {
    await Firebase.initializeApp();
  }
}
