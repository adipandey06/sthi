import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitesathi/features/auth/data/firebase_auth_repo.dart';
import 'package:sitesathi/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:sitesathi/features/auth/presentation/cubits/auth_states.dart';
import 'package:sitesathi/features/web/data/firebase_webapp_repo.dart';
import 'package:sitesathi/features/web/presentation/pages/logged_in_landing_page.dart';
import 'package:sitesathi/features/web/presentation/pages/web_landing_page.dart';

class MainApp extends StatelessWidget {
  MainApp({super.key});

  final authRepo = FirebaseAuthRepo();
  final webappRepo = FirebaseWebappRepo();
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (context) => AuthCubit(authRepo: authRepo)..checkAuth(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(),

        home: BlocConsumer<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state is AuthInitial) {
              return Center(child: Text("AuthInitial"));
            }
            if (state is AuthLoading) {
              return Center(child: CircularProgressIndicator());
            }
        
            if (state is Authenticated) {
              return LoggedInLandingPage();
            }
        
            if (state is AuthError) {
              // Inform users SiteSathi is current admin-only + Join Waitlist Button
              return Center(child: Text(state.message));
            }
        
            return WebLandingPage();
          },
          listener: (context, state) {},
        ),
      ),
    );
  }
}
