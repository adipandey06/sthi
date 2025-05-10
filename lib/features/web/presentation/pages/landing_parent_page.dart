import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitesathi/features/auth/data/firebase_auth_repo.dart';
import 'package:sitesathi/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:sitesathi/features/auth/presentation/cubits/auth_states.dart';
import 'package:sitesathi/features/web/data/firebase_webapp_repo.dart';
import 'package:sitesathi/features/web/presentation/cubit/webapp_cubit.dart';
import 'package:sitesathi/features/web/presentation/pages/logged_in_landing_page.dart';
import 'package:sitesathi/features/web/presentation/pages/web_landing_page.dart';

class LandingParentPage extends StatelessWidget {
  LandingParentPage({super.key});

  final FirebaseAuthRepo authRepo = FirebaseAuthRepo();
  final FirebaseWebappRepo webappRepo = FirebaseWebappRepo();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(authRepo: authRepo)..checkAuth(),
          ),
        ],
        child: Builder(
          builder: (context) {
            final authCubit = context.read<AuthCubit>();
            return LandingContent(authCubit: authCubit, webappRepo: webappRepo);
          },
        ),
      ),
    );
  }
}

class LandingContent extends StatelessWidget {
  final AuthCubit authCubit;
  final FirebaseWebappRepo webappRepo;

  const LandingContent({
    super.key,
    required this.authCubit,
    required this.webappRepo,
  });

  Future<bool> _checkLastAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('lastAuth') ?? false;
  }

  Future<void> _clearPlaceStored() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('placeStored', false);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = screenSize.width > screenSize.height;

    return MultiBlocProvider(
      providers: [
        BlocProvider<WebappCubit>(
          create: (_) => WebappCubit(webappRepo: webappRepo, authCubit: authCubit),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildBackground(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.03),
            child: FutureBuilder<bool>(
              future: _checkLastAuth(),
              builder: (context, snapshot) {
                return BlocConsumer<AuthCubit, AuthState>(
                  listener: (context, state) {
                    if (state is Unauthenticated) {
                      _clearPlaceStored(); // Clear placeStored on logout
                    }
                  },
                  builder: (context, state) {
                    // Determine isAuthenticated based on state or lastAuth
                    bool isAuthenticated;
                    if (state is Authenticated) {
                      isAuthenticated = true;
                    } else if (state is Unauthenticated) {
                      isAuthenticated = false;
                    } else {
                      // Use lastAuth for AuthLoading or AuthInitial
                      isAuthenticated = snapshot.connectionState == ConnectionState.done
                          ? snapshot.data ?? false
                          : false;
                    }

                    final appBar = Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width * 0.05,
                      ),
                      child: _buildConditionalAppBar(
                        context,
                        isWideScreen,
                        isAuthenticated,
                      ),
                    );

                    if (state is AuthLoading) {
                      return Column(
                        children: [
                          appBar,
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    }

                    if (state is AuthInitial) {
                      return Column(
                        children: [
                          appBar,
                          const Expanded(
                            child: Center(child: Text('Initializing...')),
                          ),
                        ],
                      );
                    }

                    if (state is AuthError) {
                      return Column(
                        children: [
                          appBar,
                          Expanded(child: Center(child: Text(state.message))),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        appBar,
                        Expanded(
                          child: state is Authenticated
                              ? const LoggedInLandingPage()
                              : Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenSize.width * 0.05,
                                  ),
                                  child: const WebLandingPage(),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "SITESATHI",
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(150),
                            fontSize: 14,
                            letterSpacing: 4.0,
                            fontWeight: FontWeight.w100,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/unsplash-backdrop-2400p.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: Container(color: Colors.black.withAlpha(128), child: child),
    );
  }

  Widget _buildConditionalAppBar(
    BuildContext context,
    bool isWideScreen,
    bool isAuthenticated,
  ) {

    WebappCubit webappCubit = context.read<WebappCubit>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'sthi.',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w600,
            letterSpacing: -2,
          ),
        ),
        if (isWideScreen)
          Row(children: [_headerButton('About'), _headerButton('Contact')]),
        isAuthenticated
            ? _headerButton(
                'Logout',
                filled: true,
                onPressed: () {
                  context.read<AuthCubit>().logout();
                },
              )
            : isWideScreen
                ? _headerButton('Login', filled: true, onPressed: () {
                  webappCubit.authCubit.continueWithGoogle();
                })
                : const Icon(Icons.menu, color: Colors.white, size: 32),
      ],
    );
  }

  TextButton _headerButton(
    String label, {
    bool filled = false,
    VoidCallback? onPressed,
  }) {
    return TextButton(
      onPressed: onPressed ?? () {},
      style: TextButton.styleFrom(
        backgroundColor:
            filled ? Colors.white.withAlpha(25) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        splashFactory: NoSplash.splashFactory,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}