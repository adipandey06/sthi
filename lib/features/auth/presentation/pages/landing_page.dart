import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitesathi/features/auth/presentation/cubits/auth_cubit.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    Future<void> signInWithGoogle() async {
    final authCubit = context.read<AuthCubit>();
    try {
      await authCubit.continueWithGoogle();
      return;
    } catch (e) {
      print('Google sign-in error: $e');
      await authCubit.logout();
      return;
    }
  }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: screenWidth * 0.9 > 400 ? 400 : screenWidth * 0.9,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
        
              FloatingActionButton.extended(
                backgroundColor: Colors.white,
                icon: const Icon(
                  Icons.login,
                  color: Colors.black,
                  weight: 0.2,
                ),
                onPressed: () {
                  signInWithGoogle();
                },
                label: Text(
                  "Continue with Google",
                  style: TextStyle(
                    color: Colors.black,
                    
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
