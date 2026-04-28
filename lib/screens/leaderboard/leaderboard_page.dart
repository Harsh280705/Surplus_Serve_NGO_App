import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  String _formatRole(String role) {
    if (role == 'EventManager') return 'Event Manager';
    return role;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final currentUserId = auth.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: kPrimaryColor,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final role = userSnap.data!['role'];

          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('donations').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final Map<String, int> leaderboard = {};

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;

                if (role == 'EventManager' && data['createdBy'] != null) {
                  leaderboard[data['createdBy']] =
                      (leaderboard[data['createdBy']] ?? 0) + 1;
                }

                if (role == 'NGO' && data['acceptedBy'] != null) {
                  leaderboard[data['acceptedBy']] =
                      (leaderboard[data['acceptedBy']] ?? 0) + 1;
                }
              }

              final sorted = leaderboard.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final uid = sorted[index].key;
                  final count = sorted[index].value;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .get(),
                    builder: (context, user) {
                      if (!user.hasData) return const SizedBox.shrink();

                      final u = user.data!;
                      final name = (u['name'] ?? '').toString();
                      final roleText = _formatRole(u['role']);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kPrimaryColor.withValues(alpha:0.1),
                          child: Text('${index + 1}'),
                        ),
                        title: Text(name),
                        subtitle: Text(
                          role == 'EventManager'
                              ? '$count donations'
                              : '$count accepted',
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(name),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Role: $roleText'),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Joined: ${u['createdAt']?.toDate().toString().split(" ").first}',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
