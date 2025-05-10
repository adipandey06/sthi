import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sitesathi/features/auth/domain/entities/app_user.dart';

import 'package:sitesathi/features/auth/domain/entities/repo/auth_repo.dart';

class FirebaseAuthRepo implements AuthRepo {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      final firebaseUser = firebaseAuth.currentUser;

      if (firebaseUser == null) {
        return null;
      }
      Map<String, dynamic> userDoc =
          (await FirebaseFirestore.instance
                      .collection('users')
                      .doc(firebaseUser.uid)
                      .get())
                  .data()
              as Map<String, dynamic>;
      return AppUser.fromJson(userDoc);
    } catch (e) {
      print("Error : $e");
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> continueWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        scopes: [ // CalendarApi.calendarScope ,CalendarApi.calendarEventsScope
          'https://www.googleapis.com/auth/userinfo.profile',          
        ]
      ).signIn();

      // If the user does not cancel the sign-in process
      if (googleUser == null) {
        return null; // The user canceled the login
      }

      // Get authentication details from the Google account
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential for Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase using the Google credential
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

          Map<String, dynamic> result = ({
            'accessToken' : googleAuth.accessToken,
            'user' : userCredential.user
          });

      return result;
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<void> logout() async {
    await firebaseAuth.signOut();
    await GoogleSignIn().signOut();
  }
}
