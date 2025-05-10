import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitesathi/features/auth/domain/entities/app_user.dart';
import 'package:sitesathi/features/auth/domain/entities/repo/auth_repo.dart';
import 'package:sitesathi/features/auth/presentation/cubits/auth_states.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo authRepo;
  late AppUser? _currentUser;
  late Prediction? _selectedPlace;

  AuthCubit({required this.authRepo}) : super(AuthInitial());

  AppUser? get currentUser => _currentUser;

  Prediction? get selectedPlace => _selectedPlace;

  // Check if user is already authenticated
  void checkAuth() async {
    emit(AuthLoading());
    final AppUser? user = await authRepo.getCurrentUser();

    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (user != null) {
      _currentUser = user;
      prefs.setBool('lastAuth', true);
      emit(Authenticated(user));
    } else {
      prefs.setBool('lastAuth', false);
      emit(Unauthenticated());
    }
  }

  // Logout
  Future<void> logout() async {
    await authRepo.logout();
    emit(Unauthenticated());
  }

  Future<void> continueWithGoogle() async {
    emit(AuthLoading());
    try {
      // Call your auth repo to initiate Google sign-in
      Map<String, dynamic>? result = await authRepo.continueWithGoogle();

      if (result == null) {
        // No result means sign-in was canceled or failed silently
        emit(Unauthenticated());
        return;
      }

      // If the sign-in was successful, continue as usual
      User user = result['user'];
      String accessToken = result['accessToken'];
      int attempts = 0;
      const int maxAttempts = 10;
      DocumentSnapshot<Map<String, dynamic>> userDoc;

      while (attempts < maxAttempts) {
        userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          AppUser appUser = AppUser.fromJson(userData);
          appUser.accessToken = accessToken;
          _currentUser = appUser;
          checkAuth();
          return; // Exit once user data is successfully retrieved
        } else {
          attempts++;
          await Future.delayed(const Duration(seconds: 4));
        }
      }

      // If user document is still not found after retrying
      logout();
      emit(Unauthenticated());
    } catch (e) {
      // Handle the specific case for popup closure
      if (e is PlatformException && e.code == 'popup_closed') {
        // Google Sign-In was closed without sign-in
        emit(Unauthenticated());
      } else {
        // Handle other errors (network issues, FirebaseAuth issues, etc.)
        print("Error during Google sign-in: $e");
        emit(Unauthenticated());
      }
    }
  }
}
