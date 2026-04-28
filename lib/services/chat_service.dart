import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_room.dart';
import 'auth_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Get all chat rooms for current user
  Stream<List<ChatRoom>> getChatRooms() {
    final userId = _authService.currentUserId;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final rooms = <ChatRoom>[];
      for (final doc in snapshot.docs) {
        final data = doc.data(); // No cast needed
        final otherUserId = (data['participants'] as List)
            .firstWhere((id) => id != userId, orElse: () => '');

        // Fetch other user's details including location name
        final otherUserDoc = await _db.collection('users').doc(otherUserId).get();
        final otherUser = otherUserDoc.data() ?? {};

        final room = ChatRoom(
          id: doc.id,
          donationId: data['donationId'] ?? '',
          donationTitle: data['donationTitle'] ?? '',
          otherUserId: otherUserId,
          otherUserName: otherUser['name'] ?? 'Unknown User',
          lastMessage: data['lastMessage'] ?? '',
          lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          unreadCount: data['unreadCount'] ?? 0,
          otherUserNickname: (data['nicknames'] as Map<String, dynamic>?)?[userId],
          otherUserLocation: otherUser['locationName'] ?? otherUser['city'] ?? 'Location not available',
        );
        rooms.add(room);
      }
      // Sort by last message time (newest first)
      rooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return rooms;
    });
  }

  // Get or create chat room for donation
  Future<String> getOrCreateChatRoom({
    required String donationId,
    required String otherUserId,
    required String donationTitle,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    // Check if chat room already exists for this donation
    final existingRooms = await _db
        .collection('chat_rooms')
        .where('donationId', isEqualTo: donationId)
        .where('participants', arrayContains: currentUserId)
        .get();

    if (existingRooms.docs.isNotEmpty) {
      return existingRooms.docs.first.id;
    }

    // Create new chat room
    final chatRoomRef = await _db.collection('chat_rooms').add({
      'donationId': donationId,
      'donationTitle': donationTitle,
      'participants': [currentUserId, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': 0,
      'nicknames': {}, // Initialize nicknames as empty map if needed
    });

    return chatRoomRef.id;
  }

  // Send message
  Future<void> sendMessage({
    required String chatRoomId,
    required String message,
    required String donationId,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    // Get chat room to find other participant
    final chatRoomDoc = await _db.collection('chat_rooms').doc(chatRoomId).get();
    final participants = (chatRoomDoc.data()?['participants'] as List?) ?? [];
    final otherUserId = participants.firstWhere((id) => id != currentUserId);

    // Get sender name
    final userDoc = await _db.collection('users').doc(currentUserId).get();
    final senderName = userDoc.data()?['name'] ?? 'Anonymous';

    // Manually create message data map (since toJson() doesn't exist)
    await _db.collection('chat_messages').add({
      'senderId': currentUserId,
      'receiverId': otherUserId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'donationId': donationId,
      'isRead': false,
      'senderName': senderName,
      'chatRoomId': chatRoomId, // Important for querying later
    });

    // Update last message in chat room
    await _db.collection('chat_rooms').doc(chatRoomId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  // Set nickname for other user in chat
  Future<void> setNickname({
    required String chatRoomId,
    required String nickname,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return;

    // Safely update nicknames map
    await _db.collection('chat_rooms').doc(chatRoomId).update({
      'nicknames.$currentUserId': nickname,
    });
  }

  // Delete chat room and all messages
  Future<void> deleteChat({
    required String chatRoomId,
  }) async {
    // Delete all messages in this chat room
    final messagesSnapshot = await _db
        .collection('chat_messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .get();

    final batch = _db.batch();
    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the chat room itself
    batch.delete(_db.collection('chat_rooms').doc(chatRoomId));
    await batch.commit();
  }
}