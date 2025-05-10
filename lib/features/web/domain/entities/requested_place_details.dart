import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sitesathi/features/web/domain/entities/place_details_custom.dart';

class RequestedPlaceDetails {
  final String placeId;
  final String placeName;
  final String formattedAddress;
  final String status;
  final Timestamp lastInteractionTimestamp;
  final Map<String, dynamic>? nextAppointment;

  RequestedPlaceDetails({
    required this.placeId,
    required this.placeName,
    required this.formattedAddress,
    required this.status,
    required this.lastInteractionTimestamp,
    this.nextAppointment,
  });

  /// Create from Firestore JSON and an appointment map
  factory RequestedPlaceDetails.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> appointmentDoc,
  ) {
    return RequestedPlaceDetails(
      placeId: json['place_id'] as String? ?? 'Unknown',
      placeName: json['name'] as String? ?? 'Unknown',
      formattedAddress: json['formatted_address'] as String? ?? 'Unknown',
      status: json['status'] as String? ?? 'pending',
      lastInteractionTimestamp: appointmentDoc['timestamp'] as Timestamp? ?? Timestamp.now(),
      nextAppointment: appointmentDoc,
    );
  }

  /// Create from a PlaceDetailsCustom instance
  factory RequestedPlaceDetails.fromPDC(
    PlaceDetailsCustom pdc,
  ) {
    return RequestedPlaceDetails(
      placeId: pdc.placeId,
      placeName: pdc.name,
      formattedAddress: pdc.formattedAddress,
      status: 'pending',
      lastInteractionTimestamp: Timestamp.now(),
      nextAppointment: null,
    );
  }

  RequestedPlaceDetails copyWith({
    String? placeId,
    String? placeName,
    String? formattedAddress,
    String? status,
    Timestamp? lastInteractionTimestamp,
    Map<String, dynamic>? nextAppointment,
  }) {
    return RequestedPlaceDetails(
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      status: status ?? this.status,
      lastInteractionTimestamp:
          lastInteractionTimestamp ?? this.lastInteractionTimestamp,
      nextAppointment: nextAppointment ?? this.nextAppointment,
    );
  }
}