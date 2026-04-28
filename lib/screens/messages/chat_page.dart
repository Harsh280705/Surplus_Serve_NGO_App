// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/donation.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/loading_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String donationId;
  final String otherUserId;
  final String donationTitle;
  const ChatPage({
    super.key,
    required this.donationId,
    required this.otherUserId,
    required this.donationTitle,
  });
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  UserProfile? _otherUserProfile;
  Donation? _donation;
  String? _chatRoomId; // ✅ ADD THIS

  @override
  void initState() {
    super.initState();
    _loadChatData();
  }

  Future<void> _loadChatData() async {
    final otherUser = await _firestoreService.getUserProfile(
      widget.otherUserId,
    );
    final donation = await _firestoreService.getDonation(widget.donationId);
    
    // ✅ GET CHAT ROOM ID
    final chatRoomId = await _firestoreService.getOrCreateChatRoom(
      donationId: widget.donationId,
      otherUserId: widget.otherUserId,
      donationTitle: widget.donationTitle,
    );
    
    if (mounted) {
      setState(() {
        _otherUserProfile = otherUser;
        _donation = donation;
        _chatRoomId = chatRoomId; // ✅ STORE IT
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final currentUser = await _authService.getCurrentUserProfile();
    if (currentUser == null || _chatRoomId == null) return; // ✅ ADD NULL CHECK
    try {
      // ✅ FIXED: Use new named parameters
      await _firestoreService.sendMessage(
        chatRoomId: _chatRoomId!, // ✅ REQUIRED
        message: _messageController.text.trim(), // ✅ REQUIRED
        donationId: widget.donationId, // ✅ REQUIRED
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: kAccentColor,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _otherUserProfile?.name ?? 'Loading...',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.donationTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: kSecondaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_otherUserProfile != null)
            IconButton(
              onPressed: () => _showUserInfo(),
              icon: const Icon(Icons.info_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_donation != null) _buildDonationHeader(),
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              // ✅ UPDATE STREAM TO USE CHAT ROOM ID
              stream: _chatRoomId != null 
                ? _firestoreService.getChatMessagesByRoom(_chatRoomId!) 
                : Stream.value([]),
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
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(fontSize: 16, color: kTextSecondary),
                    ),
                  );
                }
                final messages = snapshot.data!
                    .map((doc) => ChatMessage.fromFirestore(doc))
                    .toList();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDonationHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimaryLight.withValues(alpha:0.1),
        border: const Border(
          bottom: BorderSide(color: kPrimaryLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant, color: kPrimaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _donation!.itemName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                Text(
                  'Serves ${_donation!.servingCapacity} people • ${_donation!.count}',
                  style: const TextStyle(fontSize: 12, color: kTextSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _donation!.status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderId == _authService.currentUserId;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? kSecondaryColor : kCardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: TextStyle(
                fontSize: 16,
                color: isMe ? Colors.white : kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white70 : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kCardColor,
        border: Border(top: BorderSide(color: kPrimaryLight, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: kSecondaryColor,
            mini: true,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showUserInfo() {
    if (_otherUserProfile == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_otherUserProfile!.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${_otherUserProfile!.email}'),
            const SizedBox(height: 8),
            Text('Phone: ${_otherUserProfile!.phone}'),
            const SizedBox(height: 8),
            Text('Address: ${_otherUserProfile!.address}'),
            const SizedBox(height: 8),
            Text('Type: ${_otherUserProfile!.role}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}