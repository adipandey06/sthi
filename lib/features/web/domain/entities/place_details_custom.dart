import 'dart:convert';

/// A custom representation of Google Place Details, with JSON
/// serialization/deserialization.
class PlaceDetailsCustom {
  final String placeId;
  final String name;
  final String formattedAddress;
  final Geometry? geometry;
  final String? formattedPhoneNumber;
  final String? website;
  final List<String>? types;
  final String? url;
  final double? rating;
  final int? userRatingsTotal;
  final List<Photo>? photos;

  PlaceDetailsCustom({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    this.geometry,
    this.formattedPhoneNumber,
    this.website,
    this.types,
    this.url,
    this.rating,
    this.userRatingsTotal,
    this.photos,
  });

  /// Construct from a JSON map (as returned by the Places API).
  factory PlaceDetailsCustom.fromJson(Map<String, dynamic> json) {
    return PlaceDetailsCustom(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      formattedAddress: json['formatted_address'] as String,
      geometry: json['geometry'] != null
          ? Geometry.fromJson(json['geometry'] as Map<String, dynamic>)
          : null,
      formattedPhoneNumber: json['formatted_phone_number'] as String?,
      website: json['website'] as String?,
      types: (json['types'] as List<dynamic>?)?.map((e) => e as String).toList(),
      url: json['url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: json['user_ratings_total'] as int?,
      photos: (json['photos'] as List<dynamic>?)
          ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert this object into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'name': name,
      'formatted_address': formattedAddress,
      'geometry': geometry?.toJson(),
      'formatted_phone_number': formattedPhoneNumber,
      'website': website,
      'types': types,
      'url': url,
      'rating': rating,
      'user_ratings_total': userRatingsTotal,
      'photos': photos?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}

/// Geometry wrapper containing the location.
class Geometry {
  final Location location;

  Geometry({required this.location});

  factory Geometry.fromJson(Map<String, dynamic> json) {
    return Geometry(
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location.toJson(),
    };
  }
}

/// A latitude/longitude pair.
class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }
}

/// A photo metadata wrapper for Google Places API photos.
class Photo {
  final String photoReference;
  final int height;
  final int width;
  final List<String>? htmlAttributions;

  Photo({
    required this.photoReference,
    required this.height,
    required this.width,
    this.htmlAttributions,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      photoReference: json['photo_reference'] as String,
      height: json['height'] as int,
      width: json['width'] as int,
      htmlAttributions: (json['html_attributions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'photo_reference': photoReference,
      'height': height,
      'width': width,
      'html_attributions': htmlAttributions,
    };
  }
}