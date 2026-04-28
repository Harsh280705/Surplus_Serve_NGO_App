// lib/models/donation.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Donation {
  final String id;
  final String itemName;
  final String count;
  final String servingCapacity;
  final String description;
  final String createdBy;
  final String status;
  final DateTime createdAt;
  final String createdByName;
  final String createdByPhone;
  final GeoPoint? location;
  final String? acceptedBy;
  final String? acceptedByName;
  final DateTime? acceptedAt;
  final int? editCount;
  final DateTime? lastEditedAt;
  final bool? confirmedByEventManager;
  final DateTime? confirmedAt;

  // ✅ NEW: Delivery fields
  final bool? deliveryRequested;
  final String? deliveryStatus;

  Donation({
    required this.id,
    required this.itemName,
    required this.count,
    required this.servingCapacity,
    required this.description,
    required this.createdBy,
    required this.status,
    required this.createdAt,
    this.createdByName = '',
    this.createdByPhone = '',
    this.location,
    this.acceptedBy,
    this.acceptedByName,
    this.acceptedAt,
    this.editCount,
    this.lastEditedAt,
    this.confirmedByEventManager,
    this.confirmedAt,
    // ✅ Initialize new fields
    this.deliveryRequested,
    this.deliveryStatus,
  });

  factory Donation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Donation(
      id: doc.id,
      itemName: data['itemName'] ?? '',
      count: data['count'] ?? '',
      servingCapacity: data['servingCapacity'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      status: data['status'] ?? 'available',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByName: data['createdByName'] ?? '',
      createdByPhone: data['createdByPhone'] ?? '',
      location: data['location'] as GeoPoint?,
      acceptedBy: data['acceptedBy'],
      acceptedByName: data['acceptedByName'],
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      editCount: data['editCount'] as int? ?? 0,
      lastEditedAt: (data['lastEditedAt'] as Timestamp?)?.toDate(),
      confirmedByEventManager: data['confirmedByEventManager'] as bool?,
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      // ✅ Parse new fields from Firestore
      deliveryRequested: data['deliveryRequested'] as bool?,
      deliveryStatus: data['deliveryStatus'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemName': itemName,
      'count': count,
      'servingCapacity': servingCapacity,
      'description': description,
      'createdBy': createdBy,
      'status': status,
      'createdAt': createdAt,
      'createdByName': createdByName,
      'createdByPhone': createdByPhone,
      if (location != null) 'location': location,
      if (acceptedBy != null) 'acceptedBy': acceptedBy,
      if (acceptedByName != null) 'acceptedByName': acceptedByName,
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      'editCount': editCount ?? 0,
      if (lastEditedAt != null) 'lastEditedAt': Timestamp.fromDate(lastEditedAt!),
      if (confirmedByEventManager != null) 'confirmedByEventManager': confirmedByEventManager,
      if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
      // ✅ Include new fields when writing to Firestore
      if (deliveryRequested != null) 'deliveryRequested': deliveryRequested,
      if (deliveryStatus != null) 'deliveryStatus': deliveryStatus,
    };
  }
}