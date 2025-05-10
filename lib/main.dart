import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sitesathi/features/web/presentation/pages/landing_parent_page.dart';
import 'package:sitesathi/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // ✅ Enables offline data caching
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // ✅ No limit on cache size
  );

  runApp(LandingParentPage());
}
