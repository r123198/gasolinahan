import 'package:cloud_firestore/cloud_firestore.dart';

class StationModel {
  final String id;
  final String name;
  final String brand;
  final String address;
  final double latitude;
  final double longitude;
  final double regularPrice;
  final double premiumPrice;
  final double dieselPrice;
  final DateTime lastUpdated;

  StationModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.regularPrice,
    required this.premiumPrice,
    required this.dieselPrice,
    required this.lastUpdated,
  });

  factory StationModel.fromMap(Map<String, dynamic> data, String id) {
    return StationModel(
      id: id,
      name: data['name'] ?? 'Unknown Station',
      brand: data['brand'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      regularPrice: (data['regularPrice'] ?? 0.0).toDouble(),
      premiumPrice: (data['premiumPrice'] ?? 0.0).toDouble(),
      dieselPrice: (data['dieselPrice'] ?? 0.0).toDouble(),
      lastUpdated: _parseDateTime(data['lastUpdated']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'regularPrice': regularPrice,
      'premiumPrice': premiumPrice,
      'dieselPrice': dieselPrice,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
