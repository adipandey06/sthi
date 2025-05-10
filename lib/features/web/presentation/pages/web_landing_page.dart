import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart' show Prediction;
import 'package:sitesathi/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:sitesathi/features/auth/presentation/cubits/auth_states.dart';
import 'package:sitesathi/features/web/presentation/cubit/webapp_cubit.dart';
import 'package:sitesathi/features/web/presentation/pages/components/join_waitlist_button.dart';

// Handle Vendor - Keep it always expanded and fill out info.
// Add a contact page / form.
// About page with vague idea of what we'll do but intrguing and exciting
// Make login button usable

class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key});

  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

class _WebLandingPageState extends State<WebLandingPage> {
  late PageController _pageController;

  TextEditingController placesController = TextEditingController();
  FocusNode placesNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    placesController.dispose();
    placesNode.dispose();
    super.dispose();
  }

  void _onJoinWaitlistPressed() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _onRoleSelected() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        return PageView(
          scrollDirection: Axis.vertical,
          physics: const NeverScrollableScrollPhysics(),
          allowImplicitScrolling: true,
          controller: _pageController,
          children: [
            InitialPage(onJoinWaitlistPressed: _onJoinWaitlistPressed),
            SelectRolePage(onRoleSelected: _onRoleSelected),
            FindBusinessPage(
              placesController: placesController,
              placesNode: placesNode,
            ),
          ],
        );
      },
    );
  }
}

class InitialPage extends StatelessWidget {
  final VoidCallback onJoinWaitlistPressed;

  const InitialPage({required this.onJoinWaitlistPressed, super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWideScreen = screenWidth > screenHeight;

    return isWideScreen
        ? Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: CarouselSlider(
                        options: CarouselOptions(
                          enableInfiniteScroll: true,
                          scrollDirection: Axis.vertical,
                          height: 256,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 3),
                          autoPlayAnimationDuration: const Duration(
                            milliseconds: 800,
                          ),
                          autoPlayCurve: Curves.fastOutSlowIn,
                          pauseAutoPlayOnTouch: true,
                        ),
                        items: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Easy.",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 96,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                "Easy description.",
                                style: GoogleFonts.inter(
                                  color: Colors.grey,
                                  fontSize: 32,
                                  letterSpacing: -1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Quick.",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 96,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                "Quick description.",
                                style: GoogleFonts.inter(
                                  color: Colors.grey,
                                  fontSize: 32,
                                  letterSpacing: -1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Reliable.",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 96,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                "Reliable description.",
                                style: GoogleFonts.inter(
                                  color: Colors.grey,
                                  fontSize: 32,
                                  letterSpacing: -1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: JoinWaitlistButton(
                        onPressed: onJoinWaitlistPressed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
        : Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Spacer(),
                    CarouselSlider(
                      options: CarouselOptions(
                        enableInfiniteScroll: true,
                        scrollDirection: Axis.vertical,
                        height: 256,
                        enlargeCenterPage: true,

                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 3),
                        autoPlayAnimationDuration: const Duration(
                          milliseconds: 800,
                        ),
                        autoPlayCurve: Curves.fastOutSlowIn,
                        pauseAutoPlayOnTouch: true,
                      ),
                      items: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Easy.",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 96,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              "Easy description.",
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontSize: 32,
                                letterSpacing: -1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Quick.",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 96,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              "Quick description.",
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontSize: 32,
                                letterSpacing: -1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Reliable.",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 96,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              "Reliable description.",
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontSize: 32,
                                letterSpacing: -1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Spacer(),

                    // SizedBox(height: screenHeight * 0.05),
                    JoinWaitlistButton(
                      onPressed: onJoinWaitlistPressed,
                      buttonWidth: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
  }
}

class SelectRolePage extends StatefulWidget {
  final VoidCallback onRoleSelected;

  const SelectRolePage({required this.onRoleSelected, super.key});

  @override
  State<SelectRolePage> createState() => _SelectRolePageState();
}

class _SelectRolePageState extends State<SelectRolePage> {
  final _siteManagerController = ExpansionTileController();
  final _vendorController = ExpansionTileController();
  String? _expandedCard;

  void _handleExpansion(String roleName, bool expanded) {
    if (expanded) {
      setState(() {
        _expandedCard = roleName;
      });
      // Synchronize animations in the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (roleName == 'Site Manager') {
          _siteManagerController.expand();
          _vendorController.collapse();
        } else if (roleName == 'Vendor') {
          _vendorController.expand();
          _siteManagerController.collapse();
        }
      });
    } else {
      setState(() {
        _expandedCard = null;
      });
      // Collapse the current card
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (roleName == 'Site Manager') {
          _siteManagerController.collapse();
        } else if (roleName == 'Vendor') {
          _vendorController.collapse();
        }
      });
    }
  }

  @override
  void dispose() {
    // _siteManagerController.dispose();
    // _vendorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWideScreen = screenWidth > screenHeight;
    final cardWidth = isWideScreen ? screenWidth * 0.4 : screenWidth * 0.9;
    final cardHeight = isWideScreen ? screenHeight * 0.75 : screenHeight * 0.35;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Flex(
            direction: isWideScreen ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // _RoleCard(
              //   roleName: 'Site Manager',
              //   cardWidth: cardWidth,
              //   cardHeight: cardHeight,
              //   isWideScreen: isWideScreen,
              //   controller: _siteManagerController,
              //   isExpanded: _expandedCard == 'Site Manager',
              //   onExpansionChanged:
              //       (expanded) => _handleExpansion('Site Manager', expanded),
              //   onSelect: () {
              //     context.read<WebappCubit>().selectRole('Site Manager');
              //     widget.onRoleSelected();
              //   },
              // ),
              // Text(
              //   "OR",
              //   style: GoogleFonts.inter(
              //     color: Colors.white,
              //     fontSize: 32,
              //     fontWeight: FontWeight.w600,
              //   ),
              // ),
              _RoleCard(
                roleName: 'Vendor',
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isWideScreen: isWideScreen,
                controller: _vendorController,
                // isExpanded: _expandedCard == 'Vendor',
                isExpanded: true,
                onExpansionChanged:
                    (expanded) => _handleExpansion('Vendor', expanded),
                onSelect: () {
                  context.read<WebappCubit>().selectRole('Vendor');
                  widget.onRoleSelected();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String roleName;
  final double cardWidth;
  final double cardHeight;
  final bool isWideScreen;
  final ExpansionTileController controller;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback onSelect;

  const _RoleCard({
    required this.roleName,
    required this.cardWidth,
    required this.cardHeight,
    required this.isWideScreen,
    required this.controller,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: ExpansionTile(
          minTileHeight: cardHeight * 0.2,
          controller: controller,
          maintainState: true,
          enabled: !isWideScreen,
          initiallyExpanded: isWideScreen,
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white60,
          expansionAnimationStyle: AnimationStyle(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            reverseCurve: Curves.easeInOut,
            reverseDuration: Duration(milliseconds: 300),
          ),
          tilePadding: EdgeInsets.symmetric(
            horizontal: cardWidth * 0.075,
            vertical: isWideScreen ? cardHeight * 0.05 : 4.0,
          ),
          childrenPadding: EdgeInsets.symmetric(
            horizontal: cardWidth * 0.075,
            vertical: cardHeight * 0.05,
          ),
          title: Text(
            roleName,
            style: GoogleFonts.inter(
              color: Colors.black,
              fontSize: 24,
              letterSpacing: -1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(
            Icons.business,
            size: cardHeight * 0.1,
            color: Colors.black54,
          ),
          onExpansionChanged: onExpansionChanged,
          children: [
            AnimatedOpacity(
              opacity: isExpanded || (isWideScreen || !isExpanded) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    "Select this role if you are a $roleName",
                    style: GoogleFonts.inter(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "• Feature 1 for $roleName\n"
                    "• Feature 2 for $roleName\n"
                    "• Feature 3 for $roleName",
                    style: GoogleFonts.inter(
                      color: Colors.black87,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        "Select $roleName",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FindBusinessPage extends StatelessWidget {
  final TextEditingController placesController;
  final FocusNode placesNode;

  const FindBusinessPage({
    required this.placesController,
    required this.placesNode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Find your Business",
            style: GoogleFonts.inter(
              fontSize: 32,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          GooglePlaceAutoCompleteTextField(
            businessTypes: [
              'hardware_store',
              'general_contractor',
              // 'establishment',
            ], // Construction-related businesses
            latitude: 12.9584765, // Bengaluru, for Aargee Steel Inc
            longitude: 77.5909347,
            radius: 20000, // 10km
            placeType: null,
            isCrossBtnShown: false,
            isLatLngRequired: false,
            loadedWidget: const Icon(
              Icons.check_circle,
              color: Color.fromARGB(255, 139, 139, 139),
              size: 18,
            ),
            loadingWidget: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 139, 139, 139),
                strokeWidth: 2,
                strokeCap: StrokeCap.round,
              ),
            ),
            countries: ['in'],
            debounceTime: 400,
            textEditingController: placesController,
            focusNode: placesNode,
            googleAPIKey: 'AIzaSyDYKtjvqqH-IUA1jcbluo__AmdmavaiYho',
            inputDecoration: const InputDecoration(
              hintText: "'Sample, Place'",
              hintStyle: TextStyle(color: Color.fromARGB(255, 139, 139, 139)),
              contentPadding: EdgeInsets.all(24),
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              prefixIcon: Padding(
                padding: EdgeInsets.fromLTRB(32, 0, 8, 0),
                child: Icon(
                  Icons.search,
                  color: Color.fromARGB(255, 139, 139, 139),
                  size: 24,
                ),
              ),
            ),
            boxDecoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            itemClick: (Prediction postalCodeResponse) async {
              try {
                // Only proceed if a valid place is selected
                if (postalCodeResponse.placeId != null) {
                  context.read<WebappCubit>().selectPlace(postalCodeResponse);

                  // Check if the user is Unauthenticated before proceeding
                  if (FirebaseAuth.instance.currentUser == null) {
                    context.read<AuthCubit>().continueWithGoogle();
                  }
                } else {
                  // Handle cancellation or invalid selection if needed
                  debugPrint("User canceled or invalid selection");
                }
              } catch (e) {
                placesController.clear();
                if (context.mounted) {
                  context.read<WebappCubit>().clearSelectedPlace();
                }
                debugPrint("Error selecting place: $e");
              }
            },
            showError: false,
          ),
        ],
      ),
    );
  }
}
