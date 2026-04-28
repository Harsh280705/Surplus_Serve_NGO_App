import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/donation.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'dart:math' show cos, sqrt, asin;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // ======================
  // USERS
  // ======================
  Future<void> createUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(userId).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // ======================
  // CHAT ROOMS - ENHANCED (DETERMINISTIC + SUBCOLLECTIONS)
  // ======================

  /// Get or create a unique chat room using a deterministic ID
  Future<String> getOrCreateChatRoom({
    required String donationId,
    required String otherUserId,
    required String donationTitle,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    final userIds = [currentUserId, otherUserId]..sort();
    final chatRoomId = '${donationId}_${userIds[0]}_${userIds[1]}';

    final chatRoomRef = _db.collection('chat_rooms').doc(chatRoomId);
    final chatRoomDoc = await chatRoomRef.get();

    if (!chatRoomDoc.exists) {
      await chatRoomRef.set({
        'id': chatRoomId,
        'donationId': donationId,
        'donationTitle': donationTitle,
        'participants': userIds,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'user_${userIds[0]}_unreadCount': 0,
        'user_${userIds[1]}_unreadCount': 0,
        'user_${userIds[0]}_nickname': null,
        'user_${userIds[1]}_nickname': null,
        'user_${userIds[0]}_deleted': false,
        'user_${userIds[1]}_deleted': false,
      });
    }

    return chatRoomId;
  }

  /// Send message to chat room’s subcollection
  Future<void> sendMessage({
    required String chatRoomId,
    required String message,
    required String donationId,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    final currentUser = await _authService.getCurrentUserProfile();
    if (currentUser == null) throw Exception('User profile not found');

    final chatRoomDoc = await _db.collection('chat_rooms').doc(chatRoomId).get();
    if (!chatRoomDoc.exists) throw Exception('Chat room not found');

    final participants = List<String>.from(chatRoomDoc.data()?['participants'] ?? []);
    final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');

    // Add to subcollection
    await _db.collection('chat_rooms').doc(chatRoomId).collection('messages').add({
      'senderId': currentUserId,
      'senderName': currentUser.name,
      'receiverId': otherUserId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'donationId': donationId,
      'isRead': false,
    });

    // Update chat room metadata
    await _db.collection('chat_rooms').doc(chatRoomId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
      'user_${otherUserId}_unreadCount': FieldValue.increment(1),
      'user_${otherUserId}_deleted': false,
    });
  }

  /// Get messages from subcollection
  Stream<List<QueryDocumentSnapshot>> getChatMessagesByRoom(String chatRoomId) {
    return _db
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Enhanced chat rooms with per-user metadata
  Stream<List<Map<String, dynamic>>> getUserChatRoomsEnhanced(String userId) {
    return _db
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .where('user_${userId}_deleted', isEqualTo: false)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> chatRooms = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere((id) => id != userId, orElse: () => '');

        if (otherUserId.isEmpty) continue;

        final otherUserDoc = await _db.collection('users').doc(otherUserId).get();
        final otherUserData = otherUserDoc.data();
        final otherUserName = otherUserData?['name'] ?? 'Unknown User';
        final otherUserLocation = otherUserData?['address'] ?? 'Location not available';

        chatRooms.add({
          'id': doc.id,
          'donationId': data['donationId'] ?? '',
          'donationTitle': data['donationTitle'] ?? 'Food Donation',
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'otherUserLocation': otherUserLocation,
          'otherUserNickname': data['user_${userId}_nickname'],
          'lastMessage': data['lastMessage'] ?? '',
          'lastMessageTime': (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'unreadCount': data['user_${userId}_unreadCount'] ?? 0,
        });
      }

      return chatRooms;
    });
  }

  /// Legacy method (for backward compatibility if needed)
  Stream<List<QueryDocumentSnapshot>> getUserChatRooms(String userId) {
    return _db
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .where('user_${userId}_deleted', isEqualTo: false)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> markMessagesAsRead(String chatRoomId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return;

    await _db.collection('chat_rooms').doc(chatRoomId).update({
      'user_${currentUserId}_unreadCount': 0,
    });
  }

  Future<void> setChatNickname({
    required String chatRoomId,
    required String nickname,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return;

    await _db.collection('chat_rooms').doc(chatRoomId).update({
      'user_${currentUserId}_nickname': nickname.trim(),
    });
  }

  /// Soft-delete for current user only
  Future<void> deleteChatRoom({required String chatRoomId}) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return;

    await _db.collection('chat_rooms').doc(chatRoomId).update({
      'user_${currentUserId}_deleted': true,
      'user_${currentUserId}_unreadCount': 0,
    });
  }

  // ======================
  // DONATIONS - WITH NOTIFICATIONS
  // ======================

  Future<DocumentReference> addDonationWithLocation(Donation donation) async {
    final data = donation.toFirestore();
    data['declinedBy'] = [];
    final docRef = await _db.collection('donations').add(data);
    
    if (donation.location != null) {
      await _notifyAllNgosAboutDonation(
        donationId: docRef.id,
        donationTitle: donation.itemName,
        donorLocation: donation.location!,
      );
    }
    
    return docRef;
  }

  Future<void> _notifyAllNgosAboutDonation({
    required String donationId,
    required String donationTitle,
    required GeoPoint donorLocation,
  }) async {
    try {
      final ngosSnapshot = await _db
          .collection('users')
          .where('userType', isEqualTo: 'ngo')
          .get();

      for (final ngoDoc in ngosSnapshot.docs) {
        final ngoData = ngoDoc.data();
        final ngoId = ngoDoc.id;
        final ngoLocation = ngoData['location'] as GeoPoint?;
        
        if (ngoLocation == null) continue;
        
        final distance = _calculateDistance(donorLocation, ngoLocation);
        final distanceStr = distance < 1 ? '<1' : distance.toStringAsFixed(1);
        
        await _db.collection('notifications').add({
          'userId': ngoId,
          'type': 'new_donation',
          'title': 'New Donation Available!',
          'body': '"$donationTitle" is available $distanceStr km away from your location',
          'donationId': donationId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final fcmToken = ngoData['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await NotificationService().showLocalNotification(
            title: 'New Donation Available!',
            body: '"$donationTitle" is available $distanceStr km away',
            payload: donationId,
          );
        }
      }
    } catch (e) {
      print('❌ Error in _notifyAllNgosAboutDonation: $e');
    }
  }

  double _calculateDistance(GeoPoint from, GeoPoint to) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((to.latitude - from.latitude) * p) / 2 +
        cos(from.latitude * p) *
            cos(to.latitude * p) *
            (1 - cos((to.longitude - from.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<DocumentReference> addDonation(Map<String, dynamic> data) async {
    return await _db.collection('donations').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'declinedBy': [],
    });
  }

  Future<void> updateDonation(String donationId, Map<String, dynamic> data) async {
    await _db.collection('donations').doc(donationId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getAllDonations() {
    return _db
        .collection('donations')
        .where('category', isEqualTo: 'Food')
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserDonations(String userId) {
    return _db
        .collection('donations')
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteDonation(String docId) async {
    await _db.collection('donations').doc(docId).delete();
  }

  // ======================
  // DELIVERY MANAGEMENT
  // ======================

  Future<void> createDeliveryRequest({
    required String donationId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String ngoId,
    String? ngoName,
    String? ngoPhone,
    String? donorName,
    String? donorPhone,
    String? servingCapacity,
  }) async {
    final deliveryData = {
      'donation_id': donationId,
      'ngo_id': ngoId,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'ngo_name': ngoName ?? '',
      'ngo_phone': ngoPhone ?? '',
      'donor_name': donorName ?? '',
      'donor_phone': donorPhone ?? '',
      'serving_capacity': servingCapacity ?? '0',
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'delivery_company': 'manual',
      'assignment_type': 'manual',
      'api_provider': FieldValue.delete(),
      'api_request_sent_at': FieldValue.delete(),
      'driver_name': FieldValue.delete(),
      'driver_phone': FieldValue.delete(),
      'vehicle_number': FieldValue.delete(),
      'driver_rating': FieldValue.delete(),
      'driver_assigned_at': FieldValue.delete(),
      'confirmed_at': FieldValue.delete(),
      'picked_up_at': FieldValue.delete(),
      'in_transit_at': FieldValue.delete(),
      'delivered_at': FieldValue.delete(),
    };

    await _db.collection('deliveries').doc(donationId).set(deliveryData);
  }

  Future<void> assignDelivery({
    required String donationId,
    required String deliveryCompany,
    required String assignmentType,
    String? apiProvider,
    String? driverName,
    String? driverPhone,
    String? vehicleNumber,
    double? driverRating,
  }) async {
    final updateData = <String, dynamic>{
      'delivery_company': deliveryCompany,
      'assignment_type': assignmentType,
      'status': 'confirmed',
      'confirmed_at': FieldValue.serverTimestamp(),
    };

    if (assignmentType == 'manual') {
      updateData['driver_name'] = driverName;
      updateData['driver_phone'] = driverPhone;
      updateData['vehicle_number'] = vehicleNumber;
      updateData['driver_rating'] = driverRating ?? 4.5;
    } else if (assignmentType == 'api') {
      updateData['api_provider'] = apiProvider;
      updateData['api_request_sent_at'] = FieldValue.serverTimestamp();
      updateData['driver_name'] = FieldValue.delete();
      updateData['driver_phone'] = FieldValue.delete();
      updateData['vehicle_number'] = FieldValue.delete();
      updateData['driver_rating'] = FieldValue.delete();
    }

    await _db.collection('deliveries').doc(donationId).update(updateData);
    await _db.collection('donations').doc(donationId).update({
      'deliveryStatus': 'confirmed',
      'deliveryConfirmedAt': FieldValue.serverTimestamp(),
      'deliveryCompany': deliveryCompany,
    });
  }

  Future<void> updateDeliveryStatus({
    required String donationId,
    required String status,
    double? driverLat,
    double? driverLng,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
    };

    if (driverLat != null && driverLng != null) {
      updateData['driver_lat'] = driverLat;
      updateData['driver_lng'] = driverLng;
    }

    switch (status) {
      case 'picked_up':
        updateData['picked_up_at'] = FieldValue.serverTimestamp();
        break;
      case 'in_transit':
        updateData['in_transit_at'] = FieldValue.serverTimestamp();
        break;
      case 'delivered':
        updateData['delivered_at'] = FieldValue.serverTimestamp();
        break;
    }

    await _db.collection('deliveries').doc(donationId).update(updateData);
    await _db.collection('donations').doc(donationId).update({
      'deliveryStatus': status,
    });
  }

  Future<Map<String, dynamic>?> getDelivery(String donationId) async {
    try {
      final doc = await _db.collection('deliveries').doc(donationId).get();
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Stream<DocumentSnapshot> streamDelivery(String donationId) {
    return _db.collection('deliveries').doc(donationId).snapshots();
  }

  Stream<QuerySnapshot> getDeliveriesForUser(String userId, String role) {
    if (role == 'NGO') {
      return _db
          .collection('deliveries')
          .where('ngo_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .snapshots();
    } else {
      throw UnimplementedError('Event Manager delivery listing not implemented directly.');
    }
  }

  // ======================
  // HELPER METHODS (SHARED)
  // ======================

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  Future<Donation?> getDonation(String donationId) async {
    try {
      final doc = await _db.collection('donations').doc(donationId).get();
      if (!doc.exists) return null;
      return Donation.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  // ======================
  // LEADERBOARD + RECENT ACTIVITY
  // ======================

  Stream<QuerySnapshot> getTopEventManagers({int limit = 20}) {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'EventManager')
        .orderBy('donationCount', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot> getTopNgos({int limit = 20}) {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'NGO')
        .orderBy('acceptedCount', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<void> incrementEventManagerDonationCount(String userId, {int delta = 1}) async {
    final userRef = _db.collection('users').doc(userId);
    await userRef.set({'donationCount': FieldValue.increment(delta)}, SetOptions(merge: true));
  }

  Future<void> incrementNgoAcceptedCount(String userId, {int delta = 1}) async {
    final userRef = _db.collection('users').doc(userId);
    await userRef.set({'acceptedCount': FieldValue.increment(delta)}, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getRecentDonationsForEventManager(String userId, {int limit = 10}) {
    return _db
        .collection('donations')
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot> getRecentAcceptancesForNgo(String userId, {int limit = 10}) {
    return _db
        .collection('donations')
        .where('acceptedBy', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('acceptedAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ======================
  // HISTORY & BROWSE
  // ======================

  Stream<QuerySnapshot> getAvailableDonationsForNgo(String ngoId) {
    return _db
        .collection('donations')
        .where('status', whereIn: ['available', 'accepted'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getNgoAcceptedDonations(String ngoId) {
    return _db
        .collection('donations')
        .where('acceptedBy', isEqualTo: ngoId)
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  Stream<QuerySnapshot> getEventManagerHistory(String userId, {int limit = 50}) {
    return _db
        .collection('donations')
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot> getNgoHistory(String userId, {int limit = 50}) {
    return _db
        .collection('donations')
        .where('acceptedBy', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('acceptedAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot>> getNgoHistoryOnce(String userId, {int limit = 50}) async {
    final snapshot = await _db.collection('donations').where('acceptedBy', isEqualTo: userId).get();
    final docs = snapshot.docs.where((doc) => doc['status'] == 'accepted').toList();
    docs.sort((a, b) {
      final aTime = (a['acceptedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      final bTime = (b['acceptedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return docs.take(limit).toList();
  }

  Future<List<QueryDocumentSnapshot>> getEventManagerHistoryOnce(String userId, {int limit = 50}) async {
    final snapshot = await _db.collection('donations').where('createdBy', isEqualTo: userId).get();
    final docs = snapshot.docs.toList();
    docs.sort((a, b) {
      final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return docs.take(limit).toList();
  }

  // ======================
  // DECLINE & CONFIRM
  // ======================

  Future<void> declineDonation(String donationId, String ngoId) async {
    await _db.collection('donations').doc(donationId).update({
      'declinedBy': FieldValue.arrayUnion([ngoId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getNgoConfirmedDonations(String ngoId) {
    return _db
        .collection('donations')
        .where('acceptedBy', isEqualTo: ngoId)
        .where('confirmedByEventManager', isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserConfirmedDonations(String userId) {
    return _db
        .collection('donations')
        .where('createdBy', isEqualTo: userId)
        .where('confirmedByEventManager', isEqualTo: true)
        .snapshots();
  }

  Future<void> confirmDonationDelivery(String donationId) async {
    await _db.collection('donations').doc(donationId).update({
      'confirmedByEventManager': true,
      'confirmedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getAcceptedDonationsForEventManager(String eventManagerId) {
    return _db
        .collection('donations')
        .where('createdBy', isEqualTo: eventManagerId)
        .where('status', isEqualTo: 'accepted')
        .where('confirmedByEventManager', isEqualTo: false)
        .orderBy('acceptedAt', descending: true)
        .snapshots();
  }

  // ======================
  // LEGACY DELIVERY METHODS (Optional)
  // ======================

  Future<void> updateDeliveryStatusLegacy({
    required String donationId,
    required String status,
    String? deliveryOrderId,
  }) async {
    final updateData = <String, dynamic>{
      'deliveryStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (deliveryOrderId != null) 'deliveryOrderId': deliveryOrderId,
      if (status == 'delivered') 'deliveryCompletedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('donations').doc(donationId).update(updateData);
  }

  Stream<QuerySnapshot> getDonationsWithDelivery(String userId, String role) {
    if (role == 'NGO') {
      return _db
          .collection('donations')
          .where('acceptedBy', isEqualTo: userId)
          .where('deliveryRequested', isEqualTo: true)
          .orderBy('acceptedAt', descending: true)
          .snapshots();
    } else {
      return _db
          .collection('donations')
          .where('createdBy', isEqualTo: userId)
          .where('deliveryRequested', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  Stream<QuerySnapshot> getAllDeliveryDonations() {
    return _db
        .collection('donations')
        .where('deliveryRequested', isEqualTo: true)
        .orderBy('deliveryRequestedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getPendingDeliveriesForNgo(String ngoId) {
    return _db
        .collection('donations')
        .where('acceptedBy', isEqualTo: ngoId)
        .where('deliveryRequested', isEqualTo: true)
        .where('deliveryStatus', whereIn: ['pending', 'confirmed', 'in_transit'])
        .orderBy('deliveryRequestedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getCompletedDeliveriesForNgo(String ngoId) {
    return _db
        .collection('donations')
        .where('acceptedBy', isEqualTo: ngoId)
        .where('deliveryRequested', isEqualTo: true)
        .where('deliveryStatus', isEqualTo: 'delivered')
        .orderBy('deliveryCompletedAt', descending: true)
        .snapshots();
  }

  // ======================
  // MIGRATIONS
  // ======================

  Future<void> migrateUsersAddAlternatePhone() async {
    try {
      final usersSnapshot = await _db.collection('users').get();
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        if (!data.containsKey('alternatePhone')) {
          await _db.collection('users').doc(doc.id).update({'alternatePhone': ''});
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> migrateDonationsAddDeliveryFields() async {
    try {
      final donationsSnapshot = await _db.collection('donations').get();
      for (var doc in donationsSnapshot.docs) {
        final data = doc.data();
        if (!data.containsKey('deliveryRequested')) {
          await _db.collection('donations').doc(doc.id).update({
            'deliveryRequested': null,
            'deliveryStatus': null,
            'deliveryOrderId': null,
            'deliveryRequestedAt': null,
            'deliveryCompletedAt': null,
          });
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot<Object?>>? getUnreadMessagesStream(String userId) {
        return _db
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .where('user_${userId}_deleted', isEqualTo: false)
        .snapshots();
  }
  }
  