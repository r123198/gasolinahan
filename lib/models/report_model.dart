import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String userId;
  final String stationId;
  final double reportedRegularPrice;
  final double reportedPremiumPrice;
  final double reportedDieselPrice;
  final DateTime timestamp;
  final int pointsAwarded;
  final String status; // 'pending', 'approved', 'rejected'
  final String? photoUrl;

  ReportModel({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.reportedRegularPrice,
    required this.reportedPremiumPrice,
    required this.reportedDieselPrice,
    required this.timestamp,
    required this.pointsAwarded,
    required this.status,
    this.photoUrl,
  });

  factory ReportModel.fromMap(Map<String, dynamic> data, String id) {
    return ReportModel(
      id: id,
      userId: data['userId'] ?? '',
      stationId: data['stationId'] ?? '',
      reportedRegularPrice: (data['reportedRegularPrice'] ?? 0.0).toDouble(),
      reportedPremiumPrice: (data['reportedPremiumPrice'] ?? 0.0).toDouble(),
      reportedDieselPrice: (data['reportedDieselPrice'] ?? 0.0).toDouble(),
      timestamp: _parseDateTime(data['timestamp']),
      pointsAwarded: data['pointsAwarded'] ?? 0,
      status: data['status'] ?? 'pending',
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'stationId': stationId,
      'reportedRegularPrice': reportedRegularPrice,
      'reportedPremiumPrice': reportedPremiumPrice,
      'reportedDieselPrice': reportedDieselPrice,
      'timestamp': Timestamp.fromDate(timestamp),
      'pointsAwarded': pointsAwarded,
      'status': status,
      'photoUrl': photoUrl,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
