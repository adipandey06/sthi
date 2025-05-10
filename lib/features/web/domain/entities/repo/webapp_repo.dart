import 'package:sitesathi/features/auth/domain/entities/app_user.dart';
import 'package:sitesathi/features/web/domain/entities/place_details_custom.dart';
import 'package:sitesathi/features/web/domain/entities/requested_place_details.dart';

abstract class WebappRepo {
  Future<bool> checkPlaceStored(String placeId);
  Future<void> storePlaceToFirestore(
    PlaceDetailsCustom place,
    DateTime appointmentSlot,
    String meetLink,
    String eventId,
    String selectedRole,
    AppUser appUser,
  ); // CREATE
  Future<List<RequestedPlaceDetails>> fetchUsersRequestPlaces(
    String userId,
  ); // READ

  Future<Map<String, String>> scheduleMeeting(
    AppUser appUser,
    DateTime appointmentSlot,
    RequestedPlaceDetails requestedPlaceDetails,
  );

  // Store appintment Details
  Future<void> rescheduleAppointment(
    AppUser appUser,
    String placeId,
    DateTime newSlot,
  );

  Future<PlaceDetailsCustom?> fetchPlaceDetails(
    String placeId,
  ); // This is FIne.
  Future<void> deleteRequestPlace(RequestedPlaceDetails place,
  AppUser appUser,); // DELETE

  Future<void> fetchBusySlots(DateTime date); // This is fine.
}
