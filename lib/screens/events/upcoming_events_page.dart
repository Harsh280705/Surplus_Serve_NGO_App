import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

class UpcomingEventsPage extends StatelessWidget {
  const UpcomingEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final uid = auth.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Activity'),
        backgroundColor: kPrimaryColor,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final role = userSnap.data!['role'];

          Query query = FirebaseFirestore.instance
              .collection('donations')
              .orderBy('createdAt', descending: true)
              .limit(20);

          if (role == 'EventManager') {
            query = query.where('createdBy', isEqualTo: uid);
          } else {
            query = query.where('acceptedBy', isEqualTo: uid);
          }

          return StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                children: snapshot.data!.docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(d['itemName']),
                      subtitle: Text(
                        role == 'EventManager'
                            ? 'Serves ${d['servingCapacity']} people'
                            : 'Accepted from ${d['createdByName']}',
                      ),
                      trailing: Text(d['status']),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
