import 'package:sitesathi/features/auth/domain/entities/app_user.dart';


abstract class AuthRepo {
  // Future<AppUser?> loginWithEmailPassword(String email, String password);
  // Future<AppUser?> registerWithEmailPassword (String email, String password, String firstName, String lastName);
  Future<void> logout();
  Future<AppUser?> getCurrentUser();
  // Future<void> forgotPassword(String email);
  Future<Map<String, dynamic>?> continueWithGoogle();

}