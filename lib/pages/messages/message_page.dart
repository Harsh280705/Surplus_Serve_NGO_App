import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getUserChatRoomsEnhanced(currentUserId),
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
              message: 'You don\'t have any messages yet. Contact donors or browse donations to start chatting!',
              icon: Icons.chat_bubble_outline,
            );
          }
          
          final chatRooms = snapshot.data!;
          
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

  Widget _buildChatRoomCard(Map<String, dynamic> chatRoom) {
    final displayName = chatRoom['otherUserNickname'] ?? chatRoom['otherUserName'];
    final location = chatRoom['otherUserLocation'] ?? 'Location not available';
    final lastMessage = chatRoom['lastMessage'] ?? '';
    final lastMessageTime = chatRoom['lastMessageTime'] as DateTime;
    final unreadCount = chatRoom['unreadCount'] as int? ?? 0;
    final chatRoomId = chatRoom['id'] as String;
    final donationId = chatRoom['donationId'] as String;
    final otherUserId = chatRoom['otherUserId'] as String;
    final donationTitle = chatRoom['donationTitle'] as String;
    
    return AppCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kPrimaryColor,
          child: Text(
            displayName.toString().isNotEmpty
                ? displayName.toString()[0].toUpperCase()
                : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          displayName.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 12, color: kSecondaryColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      fontSize: 11,
                      color: kSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              donationTitle,
              style: const TextStyle(
                fontSize: 12,
                color: kTextSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kTextSecondary),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(lastMessageTime),
                  style: const TextStyle(fontSize: 11, color: kTextSecondary),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await _confirmDeleteChat(context, chatRoomId);
                    } else if (value == 'nickname') {
                      await _showNicknameDialog(
                        context,
                        chatRoomId,
                        displayName.toString(),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'nickname',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Set Nickname'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Chat', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: kAccentColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () async {
          // Mark as read when opening
          await _firestoreService.markMessagesAsRead(chatRoomId);
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  donationId: donationId,
                  otherUserId: otherUserId,
                  donationTitle: donationTitle,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _showNicknameDialog(
    BuildContext context,
    String chatRoomId,
    String currentName,
  ) async {
    final TextEditingController controller = TextEditingController();
    controller.text = currentName;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Nickname'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter nickname',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nickname = controller.text.trim();
                if (nickname.isNotEmpty) {
                  await _firestoreService.setChatNickname(
                    chatRoomId: chatRoomId,
                    nickname: nickname,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nickname updated!')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kSecondaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteChat(BuildContext context, String chatRoomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete this chat? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteChatRoom(chatRoomId: chatRoomId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      }
    }
  }
}