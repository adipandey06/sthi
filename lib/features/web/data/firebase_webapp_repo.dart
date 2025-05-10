import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:sitesathi/features/auth/domain/entities/app_user.dart';
import 'package:sitesathi/features/web/domain/entities/place_details_custom.dart';
import 'package:sitesathi/features/web/domain/entities/repo/webapp_repo.dart';
import 'package:sitesathi/features/web/domain/entities/requested_place_details.dart';

class FirebaseWebappRepo implements WebappRepo {
  @override
  Future<bool> checkPlaceStored(String placeId) async {
    try {
      DocumentReference placeDocRef = FirebaseFirestore.instance
          .collection('places')
          .doc(placeId);
      DocumentSnapshot placeDoc = await placeDocRef.get();

      return placeDoc.exists;
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<void> storePlaceToFirestore(
    PlaceDetailsCustom place,
    DateTime appointmentSlot,
    String eventId,
    String meetLink,
    String selectedRole,
    AppUser appUser,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      DocumentReference placeDoc = FirebaseFirestore.instance
          .collection('places')
          .doc(place.placeId);
      DocumentReference userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(appUser.userId);

      DocumentReference appointmentDoc =
          FirebaseFirestore.instance.collection('appointments').doc();
      String appointmentDocId = appointmentDoc.id;
      Timestamp timestamp = Timestamp.now();
      bool placeStore = await checkPlaceStored(place.placeId);

      if (placeStore) {
        batch.update(placeDoc, {
          'requested_by': FieldValue.arrayUnion([
            {'user_id': appUser.userId, 'timestamp': timestamp},
          ]),
          'appointments': FieldValue.arrayUnion([appointmentDocId]),
        });

        batch.update(userDoc, {
          'requested_places': FieldValue.arrayUnion([
            {'place_id': place.placeId, 'timestamp': timestamp},
          ]),
          'appointments': FieldValue.arrayUnion([appointmentDocId]),
        });
      } else {
        batch.set(placeDoc, {
          ...place.toJson(),
          'status': 'awaiting_appointment',
          'requested_by': FieldValue.arrayUnion([
            {'user_id': appUser.userId, 'timestamp': timestamp},
          ]),
          'appointments': FieldValue.arrayUnion([appointmentDocId]),
        }, SetOptions(merge: true));

        batch.update(userDoc, {
          'requested_places': FieldValue.arrayUnion([
            {'place_id': place.placeId, 'timestamp': timestamp},
          ]),
          'appointments': FieldValue.arrayUnion([appointmentDocId]),
        });
      }

      batch.set(appointmentDoc, {
        'appointment_id': appointmentDocId,
        'timestamp': timestamp,
        'requested_by_id': appUser.userId,
        'requested_place_id': place.placeId,
        'booked_slot': appointmentSlot,
        'selected_role': selectedRole,
        'event_id': eventId,
        'meet_link': meetLink,
        'status': 'pending',
      });

      await batch.commit();
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<List<RequestedPlaceDetails>> fetchUsersRequestPlaces(
    String userId,
  ) async {
    try {
      final placesRef = FirebaseFirestore.instance.collection('places');
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      final userSnap = await userDocRef.get();

      if (!userSnap.exists) return [];

      final rawRequested =
          userSnap.data()!['requested_places'] as List<dynamic>? ?? [];
      if (rawRequested.isEmpty) return [];

      final requestedPlaceIds =
          rawRequested.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final requestedPlaces = <RequestedPlaceDetails>[];

      for (var entry in requestedPlaceIds) {
        final placeId = entry['place_id'] as String?;
        if (placeId == null) {
          print('Skipping entry without place_id: $entry');
          continue;
        }

        final placeSnap = await placesRef.doc(placeId).get();
        if (!placeSnap.exists) {
          print('Place not found for place_id: $placeId');
          continue;
        }

        final placeData = placeSnap.data()!;
        final apptIds = placeData['appointments'] as List<dynamic>? ?? [];
        final appointments = <Map<String, dynamic>>[];

        for (var apptId in apptIds) {
          final apptDocRef = FirebaseFirestore.instance
              .collection('appointments')
              .doc(apptId as String);
          final apptSnap = await apptDocRef.get();
          if (apptSnap.exists && apptSnap.data() != null) {
            appointments.add(apptSnap.data()!);
          } else {
            print('Appointment not found or empty for id: $apptId');
          }
        }

        Map<String, dynamic>? lastAppt;
        for (var appt in appointments) {
          final requestedById = appt['requested_by_id'] as String?;
          final timestamp = appt['timestamp'] as Timestamp?;
          if (requestedById == null || timestamp == null) {
            print(
              'Skipping appointment with missing requested_by_id or timestamp: $appt',
            );
            continue;
          }
          if (requestedById == userId) {
            if (lastAppt == null ||
                timestamp.compareTo(lastAppt['timestamp'] as Timestamp) > 0) {
              lastAppt = appt;
            }
          }
        }

        if (lastAppt != null) {
          requestedPlaces.add(
            RequestedPlaceDetails.fromJson(placeData, lastAppt),
          );
        }
      }

      return requestedPlaces;
    } catch (e) {
      print('Error in fetchUsersRequestPlaces: $e');
      throw Exception('Error fetching requested places: $e');
    }
  }

  @override
  Future<void> rescheduleAppointment(
    AppUser appUser,
    String placeId,
    DateTime newSlot,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final userId = appUser.userId;

      // Get the place document to fetch existing appointments
      DocumentReference userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      DocumentReference placeDoc = FirebaseFirestore.instance
          .collection('places')
          .doc(placeId);
      DocumentSnapshot placeSnapshot = await placeDoc.get();
      DocumentSnapshot userSnapshot = await userDoc.get();
      if (!placeSnapshot.exists) {
        throw Exception("Place not found");
      }

      Map<String, dynamic> placeData =
          placeSnapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;
      List<String> appointmentId = List<String>.from(userData['appointments']);

      // Find the existing appointment for the user
      String? existingAppointmentId = appointmentId.first;
      Map<String, dynamic>? existingAppointment =
          (await FirebaseFirestore.instance
                      .collection('appointments')
                      .doc(existingAppointmentId)
                      .get())
                  .data()
              as Map<String, dynamic>;

      print('existing app : $existingAppointmentId');

      // Delete the existing Google Meet event if it exists
      final eventId = existingAppointment['event_id'] as String?;
      if (eventId != null && eventId.isNotEmpty) {
        try {
          final url = Uri.parse(
            'https://asia-east1-sitesathi-4f0e4.cloudfunctions.net/deleteGMeetEvent',
          );
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'eventId': eventId}),
          );

          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            if (responseData['success'] == true &&
                responseData['eventId'] == eventId) {
              print('Google Meet event deleted successfully');
            } else {
              print('Google Meet event deletion failed: ${response.body}');
            }
          } else {
            print(
              'Failed to delete Google Meet event: ${response.statusCode} ${response.body}',
            );
          }
        } catch (e) {
          print('⚠️ Failed to delete GMeet event: $e');
        }
      }

      // Create a new Google Meet event for the new slot
      Map<String, String> meetDetails = await scheduleMeeting(
        appUser,
        newSlot,
        RequestedPlaceDetails.fromJson(placeData, {}),
      );

      final newEventId = meetDetails['event_id'];
      final newMeetLink = meetDetails['meet_link'];

      if (newEventId == null || newMeetLink == null) {
        throw Exception("Failed to create new Google Meet event");
      }

      // Create a new appointment document for the rescheduled slot
      DocumentReference newAppointmentDoc =
          FirebaseFirestore.instance.collection('appointments').doc();
      String newAppointmentId = newAppointmentDoc.id;
      Timestamp timestamp = Timestamp.now();

      batch.set(newAppointmentDoc, {
        'appointment_id': newAppointmentId,
        'timestamp': timestamp,
        'requested_by_id': userId,
        'requested_place_id': placeId,
        'booked_slot': newSlot,
        'event_id': newEventId,
        'meet_link': newMeetLink,
        'status': 'pending',
      });

      // Update the existing appointment document to reflect rescheduling
      batch.update(
        FirebaseFirestore.instance
            .collection('appointments')
            .doc(existingAppointmentId),
        {'status': 'rescheduled : $newAppointmentId', 'timestamp': timestamp},
      );

      // Update the place document to include the new appointment
      batch.update(placeDoc, {
        'appointments': FieldValue.arrayUnion([newAppointmentId]),
      });

      batch.update(placeDoc, {
        'appointments': FieldValue.arrayRemove([existingAppointmentId]),
      });

      // Update the user document to include the new appointment
      batch.update(userDoc, {
        'appointments': FieldValue.arrayUnion([newAppointmentId]),
      });

      batch.update(userDoc, {
        'appointments': FieldValue.arrayRemove([existingAppointmentId]),
      });

      // Commit the batch operation
      await batch.commit();
    } catch (e) {
      throw Exception("Error rescheduling appointment: $e");
    }
  }

  @override
  Future<PlaceDetailsCustom?> fetchPlaceDetails(String placeId) async {
    try {
      const String googleAPIKey = 'AIzaSyDYKtjvqqH-IUA1jcbluo__AmdmavaiYho'; // Deprecated
      final String url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$googleAPIKey&fields=name,formatted_address,geometry,type,formatted_phone_number,international_phone_number,website';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetailsCustom.fromJson(data);
        } else {
          print('API Error: ${data['error_message'] ?? data['status']}');
          return null;
        }
      } else {
        print('HTTP Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception: $e');
      throw Exception('Failed to fetch place details: $e');
    }
  }

  Future<PlaceDetailsCustom?> fetchPlaceDetailsServerless(
    String placeId,
  ) async {
    try {
      if (placeId.isEmpty ||
          !RegExp(r'^ChIJ[0-9A-Za-z_-]+$').hasMatch(placeId)) {
        print('Invalid placeId: $placeId');
        throw Exception('Invalid placeId');
      }

      final googleAPIKey = 'AIzaSyDYKtjvqqH-IUA1jcbluo__AmdmavaiYho'; // Deprecated
      final url =
          'https://asia-east1-sitesathi-4f0e4.cloudfunctions.net/placeDetailsProxy?place_id=$placeId&key=$googleAPIKey';

      final response = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetailsCustom.fromJson(data['result']);
        } else {
          print('API Error: ${data['error_message'] ?? data['status']}');
          print('Response: ${response.body}');
          return null;
        }
      } else {
        print('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception: $e');
      throw Exception('Failed to fetch place details: $e');
    }
  }

  @override
  Future<void> deleteRequestPlace(
    RequestedPlaceDetails place,
    AppUser appUser,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final placeDoc = firestore.collection('places').doc(place.placeId);
      final userDoc = firestore.collection('users').doc(appUser.userId);

      final userSnapshot = await userDoc.get();
      final userMap = userSnapshot.data() as Map<String, dynamic>;
      final List userAppointments = userMap['appointments'];
      final List requestedPlaces = userMap['requested_places'];

      if (userAppointments.isEmpty) throw Exception('No appointments found.');

      final matchingPlaceEntry = requestedPlaces.firstWhere(
        (entry) => entry['place_id'] == place.placeId,
        orElse: () => null,
      );

      if (matchingPlaceEntry == null) {
        throw Exception('Requested place not found in user document.');
      }

      final originalTimestamp = matchingPlaceEntry['timestamp'];
      final appointmentId = userAppointments.first;
      final appointmentDoc = firestore
          .collection('appointments')
          .doc(appointmentId);
      final appointmentSnapshot = await appointmentDoc.get();
      final appointmentData =
          appointmentSnapshot.data() as Map<String, dynamic>;

      final eventId = appointmentData['event_id'];
      if (eventId != null && eventId is String && eventId.isNotEmpty) {
        try {
          final url = Uri.parse(
            'https://asia-east1-sitesathi-4f0e4.cloudfunctions.net/deleteGMeetEvent',
          );
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'eventId': eventId}),
          );

          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            if (responseData['success'] == true &&
                responseData['eventId'] == eventId) {
              print('Google Meet event deleted successfully');
            } else {
              print('Google Meet event deletion failed: ${response.body}');
            }
          } else {
            print(
              'Failed to delete Google Meet event: ${response.statusCode} ${response.body}',
            );
          }
        } catch (e) {
          print('⚠️ Failed to delete GMeet event: $e');
        }
      }

      final placeSnapshot = await placeDoc.get();
      final placeData = placeSnapshot.data() as Map<String, dynamic>;
      final List requestedBy = placeData['requested_by'];

      final requestedByEntry = requestedBy.firstWhere(
        (entry) => entry['user_id'] == appUser.userId,
        orElse: () => null,
      );

      if (requestedByEntry == null) {
        throw Exception(
          'User was not part of requested_by list for this place.',
        );
      }

      final requestedByTimestamp = requestedByEntry['timestamp'];

      if (requestedBy.length <= 1) {
        batch.update(placeDoc, {
          'requested_by': FieldValue.arrayRemove([
            {'user_id': appUser.userId, 'timestamp': requestedByTimestamp},
          ]),
          'appointments': FieldValue.arrayRemove([appointmentId]),
        });
        batch.update(appointmentDoc, {
          'status': 'cancelled',
          'timestamp': Timestamp.now(),
        });
        batch.update(userDoc, {
          'requested_places': FieldValue.arrayRemove([
            {'place_id': place.placeId, 'timestamp': originalTimestamp},
          ]),
          'appointments': FieldValue.arrayRemove([appointmentId]),
        });
      } else {
        batch.update(placeDoc, {
          'requested_by': FieldValue.arrayRemove([
            {'user_id': appUser.userId, 'timestamp': requestedByTimestamp},
          ]),
          'appointments': FieldValue.arrayRemove([appointmentId]),
        });
        batch.update(appointmentDoc, {
          'status': 'cancelled',
          'timestamp': Timestamp.now(),
        });
        batch.update(userDoc, {
          'requested_places': FieldValue.arrayRemove([
            {'place_id': place.placeId, 'timestamp': originalTimestamp},
          ]),
          'appointments': FieldValue.arrayRemove([appointmentId]),
        });
      }

      await batch.commit();
    } catch (e) {
      print('❌ Failed to delete place: $e');
      throw Exception('Failed to delete place: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBusySlots(DateTime date) async {
    final url = Uri.parse(
      'https://asia-east1-sitesathi-4f0e4.cloudfunctions.net/fetchBusySlots',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'date': date.toIso8601String()}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['busyTimes']);
    } else {
      throw Exception('Failed to fetch busy slots');
    }
  }

  @override
  Future<Map<String, String>> scheduleMeeting(
    AppUser appUser,
    DateTime appointmentSlot,
    RequestedPlaceDetails requestedPlaceDetails,
  ) async {
    final localStartTime = appointmentSlot;
    final startTimeUtc = localStartTime.subtract(
      const Duration(hours: 5, minutes: 30),
    );
    final url = Uri.parse(
      'https://asia-east1-sitesathi-4f0e4.cloudfunctions.net/createGMeetAndInvite',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'startTime': startTimeUtc.toIso8601String(),
          'attendeeEmail': appUser.email,
          'summary':
              'Intro Meeting with STHI and ${requestedPlaceDetails.placeName}',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final eventId = data['eventId'] as String? ?? '';
        final meetLink = data['meetLink'] as String? ?? '';
        return {'event_id': eventId, 'meet_link': meetLink};
      } else {
        throw Exception(
          'Failed to schedule meeting (status ${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
