import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitesathi/features/auth/domain/entities/app_user.dart';
import 'package:sitesathi/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:sitesathi/features/web/data/firebase_webapp_repo.dart';
import 'package:sitesathi/features/web/domain/entities/place_details_custom.dart';
import 'package:sitesathi/features/web/domain/entities/requested_place_details.dart';
import 'webapp_states.dart';

class WebappCubit extends Cubit<WebappState> {
  final FirebaseWebappRepo webappRepo;
  final AuthCubit authCubit;
  WebappCubit({required this.authCubit, required this.webappRepo})
      : super(WebappInitial());

  Prediction? _preAuthSelectedPrediction;
  String? _preAuthSelectedRole;
  PlaceDetailsCustom? _placeDetails;
  List<RequestedPlaceDetails>? _requestedPlaces;

  Prediction? get preAuthSelectedPrediction => _preAuthSelectedPrediction;
  String? get preAuthSelectedRole => _preAuthSelectedRole;
  PlaceDetailsCustom? get placeDetails => _placeDetails;
  List<RequestedPlaceDetails>? get requestedPlaces => _requestedPlaces;

  Future<void> fetchUsersRequestPlaces() async {
    emit(WebappLoading());
    try {
      print('called');
      AppUser? currentUser = authCubit.currentUser;
      if (currentUser != null) {
        print('step 1');
        if (_preAuthSelectedPrediction != null) {
          print('step 2');
          PlaceDetailsCustom? placeDetails = await webappRepo
              .fetchPlaceDetailsServerless(
                _preAuthSelectedPrediction?.placeId ?? '',
              );
          if (placeDetails != null) {
            print(placeDetails.toJson());
            _placeDetails = placeDetails;
          }
        }
        print('step 3');
        List<RequestedPlaceDetails> places = await webappRepo
            .fetchUsersRequestPlaces(currentUser.userId);
        _requestedPlaces = places;
        emit(WebappLoaded());
      } else {
        _requestedPlaces = [];
        debugPrint('User not authenticated while fetching requested places');
        emit(WebappLoaded());
      }
    } catch (e) {
      _requestedPlaces = [];
      emit(WebappError("Error caught in fetchUsersRequestPlaces : $e"));
      print('Error fetching users places from WebappCubit : $e');
    }
  }

  Future<void> deletePlaceFromFirestore() async {
    emit(WebappLoading());
    try {
      final currentUser = authCubit.currentUser;
      if (currentUser != null) {
        if (_requestedPlaces != null && _requestedPlaces!.isNotEmpty) {
          final placeToDelete = _requestedPlaces!.first;
          await webappRepo.deleteRequestPlace(placeToDelete, currentUser);
          _requestedPlaces = List.from(_requestedPlaces!)..removeAt(0);
          (await SharedPreferences.getInstance()).setBool('placeStored', false);
          emit(WebappLoaded());
        } else {
          emit(WebappLoaded());
          return;
        }
      } else {
        emit(WebappError('Unauthenticated while deleting place.'));
      }
    } catch (e) {
      emit(WebappError(e.toString()));
    }
  }

  void selectPlace(Prediction prediction) {
    _preAuthSelectedPrediction = prediction;
  }

  void selectRole(String roleName) {
    _preAuthSelectedRole = roleName;
  }

  Future<void> storePlaceToFirestore(
    PlaceDetailsCustom placeDetails,
    DateTime appointmentSlot,
    String meetLink,
    String eventId,
  ) async {
    emit(WebappLoading());

    try {
      AppUser? currentUser = authCubit.currentUser;
      if (currentUser != null) {
        await webappRepo.storePlaceToFirestore(
          placeDetails,
          appointmentSlot,
          eventId,
          meetLink,
          preAuthSelectedRole ?? 'Unknown',
          currentUser,
        );
        emit(WebappLoaded());
      } else {
        emit(
          WebappError(
            "User not authenticated while storing place to firestore",
          ),
        );
      }
    } catch (e) {
      print('Error storing place to Firestore: $e');
      emit(WebappError(e.toString()));

      return;
    }
  }

  Future<void> fetchPlaceDetails() async {
    emit(WebappLoading());
    try {
      if (_preAuthSelectedPrediction != null) {
        PlaceDetailsCustom?
        placeDetails = await webappRepo.fetchPlaceDetailsServerless(
          _preAuthSelectedPrediction?.placeId ?? '',
        ); // Switch to .fetchPlaceDetails after allowing sitesathi.com in API. This is a temporary solution to avoid CORS issues.

        if (placeDetails != null) {
          print(placeDetails.toJson());
          _placeDetails = placeDetails;
          emit(WebappLoaded());
        } else {
          print("Error fetching place details from cubit : $placeDetails");
          emit(WebappError('Place details not found'));
        }
      } else {
        print("Error fetching place details from cubit : $placeDetails");
        emit(WebappError('preAuthPrediction not selected'));
      }
    } catch (e) {
      print('Error fetching place details from Cubit : $e');
    }
  }

  Future<void> confirmPlace(
    RequestedPlaceDetails requestedPlaceDetails,
    String selectedRole,
    DateTime appointmentSlot,
  ) async {
    emit(WebappLoading());
    try {
      AppUser? currentUser = authCubit.currentUser;
      if (currentUser != null) {
        if (placeDetails != null) {
          Map<String, String> meetDetails = await webappRepo.scheduleMeeting(
            currentUser,
            appointmentSlot,
            requestedPlaceDetails,
          );

          final eventId = meetDetails['event_id'];
          final meetLink = meetDetails['meet_link'];

          if (eventId != null && meetLink != null) {
            await webappRepo.storePlaceToFirestore(
              placeDetails!,
              appointmentSlot,
              eventId,
              meetLink,
              _preAuthSelectedRole ?? selectedRole,
              currentUser,
            );
            (await SharedPreferences.getInstance()).setBool('placeStored', true);
            clearSelectedPlace();
            await fetchUsersRequestPlaces();
          }
        }
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> rescheduleAppointment(String placeId, DateTime newSlot) async {
    emit(WebappLoading());
    try {
      AppUser? currentUser = authCubit.currentUser;
      if (currentUser != null) {
        await webappRepo.rescheduleAppointment(currentUser, placeId, newSlot);
        await fetchUsersRequestPlaces();  // Refresh the list of requested places
      } else {
        emit(WebappError('User not authenticated'));
      }
    } catch (e) {
      emit(WebappError('Error rescheduling appointment: $e'));
    }
  }

  //Overall function

  void clearSelectedPlace() {
    _preAuthSelectedPrediction = null;
    _placeDetails = null;
  }
}