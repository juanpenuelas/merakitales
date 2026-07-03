import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDkhY8P3z__1JZfXjJ8GwXzJmt1ehtUqI4",
      authDomain: "merakitales-5rltbl.firebaseapp.com",
      projectId: "merakitales-5rltbl",
      storageBucket: "merakitales-5rltbl.appspot.com",
      messagingSenderId: "650643926570",
      appId: "1:650643926570:web:c706eca9cbf1aa02665d53",
    ),
  );

  runApp(const MerakiAdminApp());
}
