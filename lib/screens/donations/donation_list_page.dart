// lib/screens/donations/donation_list_page.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../models/donation.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';
import 'donation_form_page.dart';

class DonationListPage extends StatefulWidget {
  const DonationListPage({super.key});

  @override
  State<DonationListPage> createState() => _DonationListPageState();
}

class _DonationListPageState extends State<DonationListPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donations'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getUserDonations(_authService.currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'Loading your donations...');
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading donations: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Donations Yet',
              message:
                  'You haven\'t created any donations yet. Start sharing your surplus food!',
              icon: Icons.restaurant_outlined,
            );
          }

          final donations = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Donation(
              id: doc.id,
              itemName: data['itemName'] ?? '',
              count: data['count'] ?? '',
              servingCapacity: data['servingCapacity'] ?? '',
              description: data['description'] ?? '',
              createdBy: data['createdBy'] ?? '',
              status: data['status'] ?? 'available',
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              createdByName: data['createdByName'] ?? '',
              createdByPhone: data['createdByPhone'] ?? '',
              location: data['location'] as GeoPoint?,
              editCount: data['editCount'] as int? ?? 0,
              lastEditedAt: (data['lastEditedAt'] as Timestamp?)?.toDate(),
              acceptedBy: data['acceptedBy'] ?? '',
              acceptedByName: data['acceptedByName'] ?? '',
              acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
              confirmedByEventManager: data['confirmedByEventManager'] as bool? ?? false,
              confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
              deliveryRequested: data['deliveryRequested'] as bool? ?? false,
              deliveryStatus: data['deliveryStatus'] as String? ?? 'pending',
            );
          }).toList();

          donations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: donations.length,
            itemBuilder: (context, index) {
              final donation = donations[index];
              return _buildDonationCard(donation);
            },
          );
        },
      ),
    );
  }

  Widget _buildDonationCard(Donation donation) {
    final now = DateTime.now();
    final timeDifference = now.difference(donation.createdAt);
    final isAccepted = donation.status == 'accepted';
    final isConfirmed = donation.confirmedByEventManager ?? false;
    final bool passed24Hrs = timeDifference.inHours >= 24;

    // ✅ Determine actual display status
    String displayStatus = donation.status;
    Color statusColor;

    if (isConfirmed) {
      statusColor = Colors.green;
      displayStatus = 'CONFIRMED';
    } else if (isAccepted) {
      statusColor = kSecondaryColor;
      displayStatus = 'ACCEPTED';
    } else if (donation.status == 'available' && passed24Hrs) {
      statusColor = kTextSecondary;
      displayStatus = 'NOT AVAILABLE';
    } else if (donation.status == 'available') {
      statusColor = kPrimaryColor;
      displayStatus = 'AVAILABLE';
    } else {
      statusColor = Colors.orange;
      displayStatus = donation.status.toUpperCase();
    }

    // ✅ Check if donation is editable (only if NOT accepted AND within rules)
    final canEdit = !isAccepted &&
        timeDifference.inMinutes <= 30 &&
        (donation.editCount ?? 0) < 3;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant, color: kPrimaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donation.itemName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(
                      'Serves ${donation.servingCapacity} people',
                      style: const TextStyle(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // ✅ Only show menu if NOT accepted
              if (!isAccepted)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editDonation(donation, canEdit);
                    } else if (value == 'delete') {
                      _deleteDonation(donation);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      enabled: canEdit,
                      child: Row(
                        children: [
                          Icon(Icons.edit,
                              color: canEdit ? null : Colors.grey),
                          const SizedBox(width: 8),
                          Text('Edit',
                              style: TextStyle(
                                  color: canEdit ? null : Colors.grey)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: kAccentColor),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Quantity: ${donation.count}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            donation.description,
            style: const TextStyle(fontSize: 14, color: kTextSecondary),
          ),
          if (donation.location != null) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.location_on, color: kTextSecondary, size: 16),
                SizedBox(width: 4),
                Text(
                  'Location added',
                  style: TextStyle(fontSize: 12, color: kTextSecondary),
                ),
              ],
            ),
          ],
          
          // ✅ Show CONFIRMED message
          if (isConfirmed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Delivery Confirmed ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          TextSpan(
                            text: donation.confirmedAt != null
                                ? '• ${_formatDate(donation.confirmedAt!)}'
                                : '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
          // ✅ Show ACCEPTED message (if not confirmed yet)
          else if (isAccepted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kSecondaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: kSecondaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Accepted by ',
                            style: TextStyle(
                              fontSize: 13,
                              color: kTextSecondary,
                            ),
                          ),
                          TextSpan(
                            text: (donation.acceptedByName ?? '').isNotEmpty
                                ? donation.acceptedByName
                                : 'an NGO',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: kSecondaryColor,
                            ),
                          ),
                          const TextSpan(
                            text: '\nWaiting for delivery confirmation.',
                            style: TextStyle(
                              fontSize: 12,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // ✅ Show delivery status if applicable (NEW)
          if (donation.deliveryRequested == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getDeliveryStatusColor(donation.deliveryStatus).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getDeliveryStatusColor(donation.deliveryStatus).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getDeliveryStatusIcon(donation.deliveryStatus),
                    size: 14,
                    color: _getDeliveryStatusColor(donation.deliveryStatus),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Delivery: ${_getDeliveryStatusText(donation.deliveryStatus)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _getDeliveryStatusColor(donation.deliveryStatus),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isAccepted && !isConfirmed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.directions_walk, size: 14, color: Colors.blue),
                  SizedBox(width: 6),
                  Text(
                    'Self Pickup',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // ✅ Show 24-hour warning for available donations
          if (donation.status == 'available' && passed24Hrs) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.access_time, color: Colors.orange, size: 16),
                SizedBox(width: 4),
                Text(
                  '24-hour window has passed',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          // ✅ Show edit expiration reason (if not accepted)
          if (!isAccepted && !canEdit) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    timeDifference.inMinutes > 30
                        ? 'Edit time expired (30 min limit)'
                        : 'Max edits reached (3/3)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // ✅ Show edit count (if applicable and not accepted)
          if (!isAccepted && canEdit && (donation.editCount ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Edited ${donation.editCount}/3 times',
              style: const TextStyle(fontSize: 11, color: kTextSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Created: ${donation.createdAt.day}/${donation.createdAt.month}/${donation.createdAt.year}',
                style: const TextStyle(fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _editDonation(Donation donation, bool canEdit) {
    if (!canEdit) {
      final now = DateTime.now();
      final timeDifference = now.difference(donation.createdAt);
      final reason = timeDifference.inMinutes > 30
          ? 'The 30-minute edit window has expired'
          : 'You have already edited this donation 3 times';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot edit: $reason'),
          backgroundColor: kAccentColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DonationFormPage(donation: donation),
      ),
    );
  }

  Future<void> _deleteDonation(Donation donation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Donation'),
        content: Text(
          'Are you sure you want to delete "${donation.itemName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: kAccentColor)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _firestoreService.deleteDonation(donation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Donation deleted successfully'),
              backgroundColor: kPrimaryColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting donation: $e'),
              backgroundColor: kAccentColor,
            ),
          );
        }
      }
    }
  }

  // ✅ Helper methods for delivery status UI
  Color _getDeliveryStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'in_transit':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getDeliveryStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'in_transit':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _getDeliveryStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Unknown';
    }
  }
}