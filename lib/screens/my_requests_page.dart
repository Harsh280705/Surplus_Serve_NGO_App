import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/chat_message.dart' as model;
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';
import './messages/chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});
  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _firestoreService.getUserChatRooms(_authService.currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'Loading your requests...');
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading requests'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Requests Yet',
              message:
                  'You haven\'t made any donation requests yet. Browse available donations to get started!',
              icon: Icons.request_quote_outlined,
            );
          }
          final messages = snapshot.data!
              .map((doc) => model.ChatMessage.fromFirestore(doc))
              .where(
                (message) => message.senderId == _authService.currentUserId,
              )
              .toList();
          if (messages.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Requests Yet',
              message: 'You haven\'t made any donation requests yet.',
              icon: Icons.request_quote_outlined,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return _buildRequestCard(message);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(model.ChatMessage message) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.request_quote, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Donation Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(
                      'Sent: ${message.timestamp.day}/${message.timestamp.month}/${message.timestamp.year}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message.message,
            style: const TextStyle(fontSize: 14, color: kTextSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'View Conversation',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    donationId: message.donationId,
                    otherUserId: message.receiverId,
                    donationTitle: 'Donation Request',
                  ),
                ),
              );
            },
            backgroundColor: Colors.orange,
            icon: Icons.chat,
          ),
        ],
      ),
    );
  }
}
