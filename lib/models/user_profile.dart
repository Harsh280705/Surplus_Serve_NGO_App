// lib/models/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;          // ✅ This is your UID!
  final String name;
  final String email;
  final String phone;
  final String alternatePhone;
  final String address;
  final String role;
  final String? ngoName;
  final String? photoUrl;
  final double? latitude;   // ✅ Added
  final double? longitude;  // ✅ Added
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.alternatePhone = '',
    required this.address,
    required this.role,
    this.ngoName,
    this.photoUrl,
    this.latitude,   // ✅
    this.longitude,  // ✅
    required this.createdAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,  // ✅ This is your UID
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      alternatePhone: data['alternatePhone'] ?? '',
      address: data['address'] ?? '',
      role: data['role'] ?? 'NGO',
      ngoName: data['ngoName'],
      photoUrl: data['photoUrl'],
      latitude: data['latitude'] is double ? data['latitude'] as double : null,   // ✅
      longitude: data['longitude'] is double ? data['longitude'] as double : null, // ✅
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'alternatePhone': alternatePhone,
      'address': address,
      'role': role,
      if (ngoName != null) 'ngoName': ngoName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (latitude != null) 'latitude': latitude,     // ✅
      if (longitude != null) 'longitude': longitude, // ✅
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  bool isComplete() {
    final hasBasicInfo = name.isNotEmpty &&
        email.isNotEmpty &&
        phone.isNotEmpty &&
        address.isNotEmpty &&
        role.isNotEmpty;

    if (role == 'NGO') {
      return hasBasicInfo && (ngoName?.isNotEmpty == true);
    }

    return hasBasicInfo;
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? alternatePhone,
    String? address,
    String? role,
    String? ngoName,
    String? photoUrl,
    double? latitude,    // ✅
    double? longitude,   // ✅
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      address: address ?? this.address,
      role: role ?? this.role,
      ngoName: ngoName ?? this.ngoName,
      photoUrl: photoUrl ?? this.photoUrl,
      latitude: latitude ?? this.latitude,     // ✅
      longitude: longitude ?? this.longitude,  // ✅
      createdAt: createdAt ?? this.createdAt,
    );
  }
}