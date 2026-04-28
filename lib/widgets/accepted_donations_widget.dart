// lib/widgets/accepted_donations_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../services/firestore_service.dart';
import '../widgets/app_card.dart';
import '../screens/donations/donation_detail_page.dart';

class AcceptedDonationsWidget extends StatelessWidget {
  final String ngoId;

  const AcceptedDonationsWidget({
    super.key,
    required this.ngoId,
  });

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'My Accepted Donations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirestoreService().getNgoAcceptedDonations(ngoId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: kTextSecondary.withValues(alpha:0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No accepted donations yet',
                            style: TextStyle(
                              color: kTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final donations = snapshot.data!.docs;

            return SizedBox(
              height: 180,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: donations.length > 5 ? 5 : donations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final doc = donations[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DonationDetailPage(
                            donationId: doc.id,
                            donationData: data,
                          ),
                        ),
                      );
                    },
                    child: AppCard(
                      child: SizedBox(
                        width: 280,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: kSecondaryColor.withValues(alpha:0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: kSecondaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['itemName'] ?? 'Food Donation',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: kTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Serves ${data['servingCapacity']} people',
                              style: const TextStyle(
                                fontSize: 13,
                                color: kTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quantity: ${data['count']}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: kTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (data['location'] != null)
                              const Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 14, color: kSecondaryColor),
                                  SizedBox(width: 4),
                                  Text(
                                    'Location available',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: kSecondaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            const Spacer(),
                            Text(
                              'Accepted ${_timeAgo(data['acceptedAt'])}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}