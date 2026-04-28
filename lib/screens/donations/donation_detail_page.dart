// lib/screens/donations/donation_detail_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/loading_widget.dart';

class DonationDetailPage extends StatefulWidget {
  final String donationId;
  final Map<String, dynamic> donationData;

  const DonationDetailPage({
    super.key,
    required this.donationId,
    required this.donationData,
  });

  @override
  State<DonationDetailPage> createState() => _DonationDetailPageState();
}

class _DonationDetailPageState extends State<DonationDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, dynamic>? _eventManagerProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEventManagerDetails();
  }

  Future<void> _loadEventManagerDetails() async {
    try {
      final createdBy = widget.donationData['createdBy'] as String?;
      if (createdBy != null) {
        final profile = await _firestoreService.getUserProfile(createdBy);
        if (!mounted) return;
        setState(() {
          _eventManagerProfile = profile?.toMap();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openMap() async {
    final location = widget.donationData['location'] as GeoPoint?;
    if (location == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available for this donation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final lat = location.latitude;
    final lng = location.longitude;
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open maps'),
            backgroundColor: kAccentColor,
          ),
        );
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not make call'),
            backgroundColor: kAccentColor,
          ),
        );
      }
    }
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final dt = ts.toDate();
    return '${dt.day}/${dt.month}/${dt.year} at '
        '${dt.hour.toString().padLeft(2, '0')}:' 
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isEventManager = widget.donationData['createdBy'] == currentUserId;
    final isAccepted = (widget.donationData['status'] as String?) == 'accepted';
    final isConfirmed = widget.donationData['confirmedByEventManager'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Details'),
        backgroundColor: kSecondaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading details...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kSecondaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                color: kSecondaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.donationData['itemName'] ?? 'Food Donation',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: kTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          Icons.people,
                          'Serving Capacity',
                          '${widget.donationData['servingCapacity']} people',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.format_list_numbered,
                          'Quantity',
                          widget.donationData['count'] ?? 'N/A',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.description,
                          'Description',
                          widget.donationData['description'] ?? 'No description',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.access_time,
                          'Posted',
                          _formatDateTime(widget.donationData['createdAt']),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.check_circle,
                          'Accepted',
                          _formatDateTime(widget.donationData['acceptedAt']),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (widget.donationData['location'] != null)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on, color: kSecondaryColor),
                              SizedBox(width: 8),
                              Text(
                                'Pickup Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: kTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openMap,
                              icon: const Icon(Icons.map),
                              label: const Text('Open in Maps'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kSecondaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person, color: kPrimaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Event Manager Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.person_outline,
                          'Name',
                          widget.donationData['createdByName'] ?? 'N/A',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 20, color: kTextSecondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.donationData['createdByPhone'] ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: kTextPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if ((widget.donationData['createdByPhone'] as String?)?.isNotEmpty == true)
                              IconButton(
                                onPressed: () => _callPhone(widget.donationData['createdByPhone']),
                                icon: const Icon(Icons.call, color: kSecondaryColor),
                              ),
                          ],
                        ),
                        if (_eventManagerProfile != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.email,
                            'Email',
                            _eventManagerProfile!['email'] ?? 'N/A',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ ONLY show confirmation button when applicable
                  if (isAccepted && !isConfirmed && isEventManager)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await _firestoreService.confirmDonationDelivery(widget.donationId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Delivery confirmed successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to confirm: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                          ),
                          child: const Text(
                            'Confirm Food Delivered to NGO',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: kTextSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: kTextSecondary),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16, color: kTextPrimary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}