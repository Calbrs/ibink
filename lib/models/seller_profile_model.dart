class SellerProfileModel {
  final String userId;
  final String businessName;
  final String ownerName;
  final String email;
  final String? phone;
  final String? bio;
  final String? location;
  final DateTime memberSince;

  const SellerProfileModel({
    required this.userId,
    required this.businessName,
    required this.ownerName,
    required this.email,
    this.phone,
    this.bio,
    this.location,
    required this.memberSince,
  });

  factory SellerProfileModel.fromJson(Map<String, dynamic> j) => SellerProfileModel(
        userId: j['user_id'] as String,
        businessName: j['business_name'] as String,
        ownerName: j['owner_name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        bio: j['bio'] as String?,
        location: j['location'] as String?,
        memberSince: DateTime.tryParse(j['member_since'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId, 'business_name': businessName, 'owner_name': ownerName,
        'email': email, 'phone': phone, 'bio': bio, 'location': location,
        'member_since': memberSince.toIso8601String(),
      };
}

final SellerProfileModel dummySellerProfile = SellerProfileModel(
  userId: 'u1',
  businessName: 'Amara Crafts & Goods',
  ownerName: 'Amara Osei',
  email: 'amara@ibink.me',
  phone: '+254 712 345 678',
  bio: 'Quality products, sourced from local artisans across the region.',
  location: 'Nairobi, Kenya',
  memberSince: DateTime(2023, 3, 14),
);
