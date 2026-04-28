import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../models/chat_message.dart' as chat_model;
import '../../models/chat_room.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';
import '../messages/chat_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: kSecondaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _firestoreService.getUserChatRooms(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'Loading messages...');
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Messages',
              message:
                  'You don\'t have any messages yet. Contact donors or browse donations to start chatting!',
              icon: Icons.chat_bubble_outline,
            );
          }
          // Convert Firestore docs -> ChatMessage list
          final messages = snapshot.data!
              .map((doc) => chat_model.ChatMessage.fromFirestore(doc))
              .toList();
          // Group by donation + other user
          final chatRooms = _groupMessagesByChat(messages);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              return _buildChatRoomCard(chatRoom);
            },
          );
        },
      ),
    );
  }

  List<ChatRoom> _groupMessagesByChat(List<chat_model.ChatMessage> messages) {
    final Map<String, ChatRoom> chatRoomMap = {};
    final currentUserId = _authService.currentUserId!;
    for (final message in messages) {
      final otherUserId = message.senderId == currentUserId
          ? message.receiverId
          : message.senderId;
      final chatKey = '${message.donationId}_$otherUserId';
      if (!chatRoomMap.containsKey(chatKey)) {
        chatRoomMap[chatKey] = ChatRoom(
          id: chatKey,
          donationId: message.donationId,
          donationTitle: 'Food Donation', // Placeholder, ideally fetch donation title
          otherUserId: otherUserId,
          otherUserName:
              message.senderName.isNotEmpty ? message.senderName : 'Unknown',
          lastMessage: message.message,
          lastMessageTime: message.timestamp,
        );
      } else {
        final existingRoom = chatRoomMap[chatKey]!;
        if (message.timestamp.isAfter(existingRoom.lastMessageTime)) {
          chatRoomMap[chatKey] = ChatRoom(
            id: existingRoom.id,
            donationId: existingRoom.donationId,
            donationTitle: existingRoom.donationTitle,
            otherUserId: existingRoom.otherUserId,
            otherUserName: message.senderName.isNotEmpty
                ? message.senderName
                : existingRoom.otherUserName,
            lastMessage: message.message,
            lastMessageTime: message.timestamp,
          );
        }
      }
    }
    final chatRooms = chatRoomMap.values.toList();
    chatRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return chatRooms;
  }

  Widget _buildChatRoomCard(ChatRoom chatRoom) {
    return AppCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kPrimaryColor,
          child: Text(
            chatRoom.otherUserName.isNotEmpty
                ? chatRoom.otherUserName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          chatRoom.otherUserName.isNotEmpty
              ? chatRoom.otherUserName
              : 'Unknown User',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chatRoom.donationTitle,
              style: const TextStyle(
                fontSize: 12,
                color: kSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              chatRoom.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kTextSecondary),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${chatRoom.lastMessageTime.hour}:${chatRoom.lastMessageTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: kTextSecondary),
            ),
            if (chatRoom.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: kAccentColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  chatRoom.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                donationId: chatRoom.donationId,
                otherUserId: chatRoom.otherUserId,
                donationTitle: chatRoom.donationTitle,
              ),
            ),
          );
        },
      ),
    );
  }
}
