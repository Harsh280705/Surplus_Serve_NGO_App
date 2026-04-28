import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => ChatListScreenState();
}

class ChatListScreenState extends State<ChatListScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final userId = 'your_current_user_id';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getUserChatRoomsEnhanced(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No chats yet'));
          }
          
          final chatRooms = snapshot.data!;
          
          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final room = chatRooms[index];
              return ChatRoomTile(
                chatRoom: room,
                onNicknameSet: () {
                  setState(() {});
                },
                onChatDeleted: () {
                  setState(() {});
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ChatRoomTile extends StatelessWidget {
  final Map<String, dynamic> chatRoom;
  final VoidCallback onNicknameSet;
  final VoidCallback onChatDeleted;
  
  const ChatRoomTile({
    super.key,
    required this.chatRoom,
    required this.onNicknameSet,
    required this.onChatDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = chatRoom['otherUserNickname'] ?? chatRoom['otherUserName'];
    final location = chatRoom['otherUserLocation'] ?? 'Location not available';
    final lastMessage = chatRoom['lastMessage'] ?? '';
    final unreadCount = chatRoom['unreadCount'] as int? ?? 0;
    final chatRoomId = chatRoom['id'] as String? ?? '';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        title: Text(displayName ?? 'Unknown User'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(location),
            const SizedBox(height: 4),
            Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  await _deleteChat(context, chatRoomId);
                } else if (value == 'nickname') {
                  await _showNicknameDialog(context, chatRoomId, displayName ?? '');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'nickname',
                  child: Text('Set Nickname'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Chat'),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          _showChatNotImplemented(context);
        },
      ),
    );
  }
  
  Future<void> _showNicknameDialog(BuildContext context, String chatRoomId, String currentName) async {
    final TextEditingController controller = TextEditingController();
    controller.text = currentName;
    
    if (!context.mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Nickname'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter nickname for $currentName',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final nickname = controller.text.trim();
                if (nickname.isNotEmpty) {
                  await FirestoreService().setChatNickname(
                    chatRoomId: chatRoomId,
                    nickname: nickname,
                  );
                  onNicknameSet();
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _deleteChat(BuildContext context, String chatRoomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context, false);
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await FirestoreService().deleteChatRoom(chatRoomId: chatRoomId);
      onChatDeleted();
    }
  }
  
  void _showChatNotImplemented(BuildContext context) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat screen not implemented yet')),
      );
    }
  }
}