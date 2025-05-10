import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String userId;
  final Timestamp createdTimestamp;
  final Timestamp lastUpdatedTimestamp;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String authPlatform; // 'google', 'apple', 'manual', etc.
  final List<Map<String, dynamic>> requestedPlaces; // Added
  final List<String> appointments; // Added
  String? accessToken;

  AppUser({
    required this.userId,
    required this.createdTimestamp,
    required this.lastUpdatedTimestamp,
    required this.displayName,
    required this.email,
    this.phoneNumber = '',
    required this.authPlatform,
    this.requestedPlaces = const [],
    this.appointments = const [],
    this.accessToken,
  });

  // Convert AppUser to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'created_timestamp': createdTimestamp,
      'last_updated_timestamp': lastUpdatedTimestamp,
      'display_name': displayName,
      'email': email,
      'phone_number': phoneNumber,
      'auth_platform': authPlatform,
      'requested_places': requestedPlaces,
      'appointments': appointments,
    };
  }

  // Create AppUser from Firestore JSON
  factory AppUser.fromJson(Map<String, dynamic> json) {
    // Handle the requested_places field
    List<Map<String, dynamic>> requestedPlaces = [];
    final rawRequestedPlaces = json['requested_places'];
    if (rawRequestedPlaces is List) {
      requestedPlaces = rawRequestedPlaces
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else if (rawRequestedPlaces is String) {
      // Handle case where requested_places is a single DocID string
      requestedPlaces = [
        {'docId': rawRequestedPlaces} // Wrap string in a minimal map
      ];
    } else {
      requestedPlaces = []; // Fallback for null or invalid types
    }

    // Handle the appointments field (from previous fix)
    List<String> appointments = [];
    final rawAppointments = json['appointments'];
    if (rawAppointments is List<dynamic>) {
      appointments = rawAppointments.map((e) => e.toString()).toList();
    } else if (rawAppointments is String) {
      appointments = [rawAppointments];
    } else {
      appointments = [];
    }

    return AppUser(
      userId: json['user_id'] as String,
      createdTimestamp: json['created_timestamp'] as Timestamp,
      lastUpdatedTimestamp: json['last_updated_timestamp'] as Timestamp,
      displayName: json['display_name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phone_number'] as String? ?? '',
      authPlatform: json['auth_platform'] as String,
      requestedPlaces: requestedPlaces,
      appointments: appointments,
    );
  }

  // copyWith method to create a modified copy of AppUser
  AppUser copyWith({
    String? userId,
    Timestamp? createdTimestamp,
    Timestamp? lastUpdatedTimestamp,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? authPlatform,
    bool? onboardingComplete,
    List<Map<String, dynamic>>? requestedPlaces,
    List<String>? appointments,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      createdTimestamp: createdTimestamp ?? this.createdTimestamp,
      lastUpdatedTimestamp: lastUpdatedTimestamp ?? this.lastUpdatedTimestamp,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      authPlatform: authPlatform ?? this.authPlatform,
      requestedPlaces: requestedPlaces ?? this.requestedPlaces,
      appointments: appointments ?? this.appointments,
      accessToken: accessToken,
    );
  }
}