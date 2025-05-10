import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitesathi/features/web/domain/entities/place_details_custom.dart';
import 'package:sitesathi/features/web/domain/entities/requested_place_details.dart';
import 'package:sitesathi/features/web/presentation/cubit/webapp_cubit.dart';
import 'package:sitesathi/features/web/presentation/cubit/webapp_states.dart';
import 'package:sitesathi/features/web/presentation/pages/components/place_card.dart';

// Cache TextStyles to prevent GoogleFonts stack overflow
class AppTextStyles {
  static final TextStyle interRegular = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
  static final TextStyle interBold = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );
  static final TextStyle interSemiBold = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static final TextStyle interMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
}

class LoggedInLandingPage extends StatefulWidget {
  const LoggedInLandingPage({super.key});

  @override
  State<LoggedInLandingPage> createState() => _LoggedInLandingPageState();
}

class _LoggedInLandingPageState extends State<LoggedInLandingPage> {
  WebappCubit get webappCubit => context.read<WebappCubit>();
  PlaceDetailsCustom? tempSelectedPlace;
  Map<String, PlaceCard> requestedPlaceCardsMap = {};
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  PlaceDetailsCustom? previousPlaceDetails;

  TextEditingController placeController = TextEditingController();
  FocusNode placeNode = FocusNode();

  bool _hasAnimatedToSecondPage = false;
  bool _isFetchingPlaceDetails = false;
  bool _placeStoredLast = false;
  bool _preAuthSelected = false;
  Prediction? _selectedPrediction;

  late Future<void> _checkPlaceStoredFuture;

  @override
  void initState() {
    super.initState();
    _checkPlaceStoredFuture = _checkPlaceStored();
    webappCubit.fetchUsersRequestPlaces();
    _preAuthSelected = webappCubit.preAuthSelectedPrediction != null;
    debugPrint(
      'initState: preAuthSelectedPrediction = ${webappCubit.preAuthSelectedPrediction}',
    );
    if (_preAuthSelected) {
      setState(() {
        _isFetchingPlaceDetails = true;
      });
      webappCubit.selectPlace(webappCubit.preAuthSelectedPrediction!);
      webappCubit
          .fetchPlaceDetails()
          .then((_) {
            if (mounted) {
              setState(() {
                tempSelectedPlace = webappCubit.placeDetails;
                _isFetchingPlaceDetails = false;
              });
            }
          })
          .catchError((e) {
            debugPrint('Error fetching preAuth place details: $e');
            if (mounted) {
              setState(() {
                _isFetchingPlaceDetails = false;
                _preAuthSelected = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load pre-selected place: $e'),
                ),
              );
            }
          });
    }
  }

  @override
  void dispose() {
    placeController.dispose();
    placeNode.dispose();
    super.dispose();
  }

  Future<void> _checkPlaceStored() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _placeStoredLast = prefs.getBool('placeStored') ?? false;
    debugPrint('Checked placeStored: $_placeStoredLast');
  }

  Future<void> _updatePlaceStored(bool hasPlaces) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('placeStored', hasPlaces);
    _placeStoredLast = hasPlaces;
  }

  void _onClose() async {
    debugPrint(
      'Closing card, tempSelectedPlace: ${tempSelectedPlace != null}, requestedPlaceCards: ${requestedPlaceCardsMap.length}',
    );

    // Reset state immediately
    setState(() {
      if (tempSelectedPlace != null) {
        placeController.clear();
        tempSelectedPlace = null;
        webappCubit.clearSelectedPlace();
      } else if (requestedPlaceCardsMap.isNotEmpty) {
        final removedPlaceId = requestedPlaceCardsMap.keys.first;
        requestedPlaceCardsMap.remove(removedPlaceId);
        webappCubit.deletePlaceFromFirestore();
        webappCubit.clearSelectedPlace();
        debugPrint('Removed card with placeId: $removedPlaceId');
      }

      if (requestedPlaceCardsMap.isEmpty && tempSelectedPlace == null) {
        _hasAnimatedToSecondPage = false;
        _updatePlaceStored(false);
      }
      _isFetchingPlaceDetails = false;
      _selectedPrediction = null;
      _preAuthSelected = false; // Clear preAuthSelected after closing
    });

    // Perform carousel animation asynchronously without blocking state updates
    _carouselController
        .animateToPage(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        )
        .then((_) {
          debugPrint('Animated back to page 0');
        });
  }

  Widget _buildPlaceholder() {
    return Column(
      children: [
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GooglePlaceAutoCompleteTextField(
            isCrossBtnShown: false,
            isLatLngRequired: false,
            businessTypes: ['establishment', 'store'],
            loadedWidget: const Icon(Icons.check_circle, color: Color.fromARGB(255, 139, 139, 139), size: 18,),
            loadingWidget: const SizedBox(
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
            textEditingController: placeController,
            focusNode: placeNode,
            googleAPIKey: 'AIzaSyDYKtjvqqH-IUA1jcbluo__AmdmavaiYho', // Deprecated
            inputDecoration: InputDecoration(
              hintText: "'Sample, Place'",
              hintStyle: AppTextStyles.interRegular.copyWith(
                color: const Color.fromARGB(255, 139, 139, 139),
              ),
              contentPadding: const EdgeInsets.all(24),
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              prefixIcon: const Padding(
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
              if (postalCodeResponse.placeId != null) {
                setState(() {
                  _isFetchingPlaceDetails = true;
                  _selectedPrediction = postalCodeResponse;
                  _hasAnimatedToSecondPage = true;
                });

                // Move to page 1 immediately
                _carouselController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                );

                try {
                  context.read<WebappCubit>().selectPlace(postalCodeResponse);
                  await context.read<WebappCubit>().fetchPlaceDetails();
                  await _updatePlaceStored(true);
                  if (mounted) {
                    setState(() {
                      _isFetchingPlaceDetails = false;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _isFetchingPlaceDetails = false;
                      _selectedPrediction = null;
                    });
                    placeController.clear();
                    context.read<WebappCubit>().clearSelectedPlace();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to fetch place details: $e'),
                      ),
                    );
                    debugPrint("Error selecting place: $e");
                  }
                }
              } else {
                debugPrint("Invalid selection");
              }
            },
            showError: false,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > screenHeight;

    return FutureBuilder<void>(
      future: _checkPlaceStoredFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        return BlocConsumer<WebappCubit, WebappState>(
          listener: (context, state) async {
            if (state is WebappLoaded) {
              final tempReqPlaces = webappCubit.requestedPlaces ?? [];
              debugPrint('tempReqPlaces: $tempReqPlaces');

              // Update requestedPlaceCardsMap only for new or changed places
              final newPlaceIds = tempReqPlaces.map((p) => p.placeId).toSet();
              requestedPlaceCardsMap.removeWhere(
                (placeId, _) => !newPlaceIds.contains(placeId),
              );

              for (final placeDetails in tempReqPlaces) {
                if (!requestedPlaceCardsMap.containsKey(placeDetails.placeId)) {
                  debugPrint(
                    'Adding PlaceCard for placeId: ${placeDetails.placeId}',
                  );
                  requestedPlaceCardsMap[placeDetails.placeId] = PlaceCard(
                    key: ValueKey(placeDetails.placeId),
                    placeDetails: placeDetails,
                    cardHeight: screenHeight * 0.625,
                    cardWidth: screenWidth * 0.85,
                    isLoading: false,
                    onClose: _onClose,
                  );
                } else {
                  // Check if placeDetails has changed significantly
                  final existingPlace =
                      requestedPlaceCardsMap[placeDetails.placeId]!
                          .placeDetails;
                  if (existingPlace.status != placeDetails.status ||
                      existingPlace.nextAppointment?['booked_slot'] !=
                          placeDetails.nextAppointment?['booked_slot']) {
                    debugPrint(
                      'Updating PlaceCard for placeId: ${placeDetails.placeId}',
                    );
                    requestedPlaceCardsMap[placeDetails.placeId] = PlaceCard(
                      key: ValueKey(placeDetails.placeId),
                      placeDetails: placeDetails,
                      cardHeight: screenHeight * 0.625,
                      cardWidth: screenWidth * 0.85,
                      isLoading: false,
                      onClose: _onClose,
                    );
                  }
                }
              }

              await _updatePlaceStored(tempReqPlaces.isNotEmpty);

              if (_preAuthSelected &&
                  webappCubit.preAuthSelectedPrediction != null &&
                  tempSelectedPlace == null) {
                tempSelectedPlace = webappCubit.placeDetails;
              } else {
                tempSelectedPlace = webappCubit.placeDetails;
              }

              if (requestedPlaceCardsMap.isEmpty &&
                  !_preAuthSelected &&
                  tempSelectedPlace == null) {
                await _carouselController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
                _hasAnimatedToSecondPage = false;
              } else if ((requestedPlaceCardsMap.isNotEmpty ||
                      _preAuthSelected ||
                      tempSelectedPlace != null) &&
                  !_hasAnimatedToSecondPage) {
                _hasAnimatedToSecondPage = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _carouselController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                });
              }

              if (requestedPlaceCardsMap.isNotEmpty) {
                webappCubit.clearSelectedPlace();
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Places loaded successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(milliseconds: 800),
                ),
              );
            }
          },
          builder: (context, state) {
            debugPrint(
              'Building, state: $state, tempSelectedPlace: ${tempSelectedPlace != null}, requestedPlaceCards: ${requestedPlaceCardsMap.length}, _isFetchingPlaceDetails: $_isFetchingPlaceDetails, _placeStoredLast: $_placeStoredLast, preAuthSelectedPrediction: ${webappCubit.preAuthSelectedPrediction}',
            );

            bool isLoading = state is WebappLoading;

            if (state is WebappError) {
              return Center(
                child: Text(state.message, style: AppTextStyles.interRegular),
              );
            }

            final carouselItems = [
              _buildPlaceholder(),
              if (_preAuthSelected &&
                  webappCubit.preAuthSelectedPrediction != null &&
                  tempSelectedPlace == null)
                PlaceCard(
                  placeDetails: RequestedPlaceDetails(
                    placeId:
                        webappCubit.preAuthSelectedPrediction!.placeId ??
                        'loading',
                    placeName:
                        webappCubit.preAuthSelectedPrediction!.description ??
                        'Loading...',
                    formattedAddress: '',
                    status: 'loading',
                    lastInteractionTimestamp: Timestamp.now(),
                  ),
                  awaitConfirm: true,
                  onClose: _onClose,
                  cardHeight: screenHeight * 0.65,
                  cardWidth: screenWidth * 0.85,
                  isLoading: _isFetchingPlaceDetails,
                )
              else if (requestedPlaceCardsMap.isNotEmpty)
                requestedPlaceCardsMap.values.first
              else if (_placeStoredLast)
                PlaceCard(
                  placeDetails: RequestedPlaceDetails(
                    placeId: 'loading',
                    placeName: 'Loading...',
                    formattedAddress: '',
                    status: 'loading',
                    lastInteractionTimestamp: Timestamp.now(),
                  ),
                  awaitConfirm: false,
                  onClose: _onClose,
                  cardHeight: screenHeight * 0.65,
                  cardWidth: screenWidth * 0.85,
                  isLoading: true,
                )
              else if (tempSelectedPlace != null)
                PlaceCard(
                  key: ValueKey('temp_${tempSelectedPlace!.placeId}'),
                  placeDetails: RequestedPlaceDetails.fromPDC(
                    tempSelectedPlace!,
                  ),
                  awaitConfirm: true,
                  onClose: _onClose,
                  cardHeight: screenHeight * 0.65,
                  cardWidth: screenWidth * 0.85,
                  isLoading: isLoading,
                )
              else if (_isFetchingPlaceDetails && _selectedPrediction != null)
                PlaceCard(
                  placeDetails: RequestedPlaceDetails(
                    placeId: _selectedPrediction!.placeId ?? 'loading',
                    placeName: _selectedPrediction!.description ?? 'Loading...',
                    formattedAddress: '',
                    status: 'loading',
                    lastInteractionTimestamp: Timestamp.now(),
                  ),
                  awaitConfirm: true,
                  onClose: _onClose,
                  cardHeight: screenHeight * 0.65,
                  cardWidth: screenWidth * 0.85,
                  isLoading: true,
                ),
            ];

            print(screenHeight);

            return Column(
              children: [
                const SizedBox(height: 8),
                CarouselSlider(
                  carouselController: _carouselController,
                  disableGesture: true,
                  options: CarouselOptions(
                    height: screenHeight * 0.75,
                    
                    autoPlay: false,
                    viewportFraction: 1.0,
                    initialPage:
                        (_placeStoredLast ||
                                _preAuthSelected ||
                                tempSelectedPlace != null)
                            ? 1
                            : 0,
                    enableInfiniteScroll: false,
                    enlargeCenterPage: false,
                    padEnds: true,
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                  ),
                  items: carouselItems,
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }
}
