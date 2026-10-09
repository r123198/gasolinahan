class UserModel {
  final String id;
  final String name;
  final String email;
  final String profileImageUrl;
  final String joinDate;
  final String subscriptionTier;
  final int reportsCount;
  final int points;
  final double amountSaved;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.profileImageUrl,
    required this.joinDate,
    required this.subscriptionTier,
    required this.reportsCount,
    required this.points,
    required this.amountSaved,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? 'Unknown User',
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      joinDate: data['joinDate'] ?? 'Unknown',
      subscriptionTier: data['subscriptionTier'] ?? 'GASOLINAHAN FREE',
      reportsCount: data['reportsCount'] ?? 0,
      points: data['points'] ?? 0,
      amountSaved: (data['amountSaved'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'joinDate': joinDate,
      'subscriptionTier': subscriptionTier,
      'reportsCount': reportsCount,
      'points': points,
      'amountSaved': amountSaved,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? profileImageUrl,
    String? subscriptionTier,
    int? reportsCount,
    int? points,
    double? amountSaved,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      joinDate: joinDate,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      reportsCount: reportsCount ?? this.reportsCount,
      points: points ?? this.points,
      amountSaved: amountSaved ?? this.amountSaved,
    );
  }
}
