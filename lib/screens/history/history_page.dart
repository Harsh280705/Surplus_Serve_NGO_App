// lib/screens/history/history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart'; // ✅ Added
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_card.dart';
import '../donations/donation_detail_page.dart';
import '../delivery/delivery_tracking_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoadingProfile = true;
  String? _userId;
  String _role = '';

  // Replace with your actual Flask server URL
  static const String _flaskServerUrl = 'http://192.168.29.226:5000';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (!mounted) return;
      _userId = _authService.currentUserId;
      _role = profile?.role ?? '';
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} • '
        '${dt.hour.toString().padLeft(2, '0')}:' 
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }

  Widget? _getDeliveryStatusBadge(Map<String, dynamic> data) {
    final deliveryRequested = (data['deliveryRequested'] as bool?) ?? false;
    if (!deliveryRequested) return null;
    final status = data['deliveryStatus'] as String? ?? 'pending';
    IconData icon;
    Color color;
    String label;
    switch (status) {
      case 'pending': 
        icon = Icons.hourglass_empty; color = Colors.orange; label = 'Delivery Pending'; break;
      case 'confirmed': 
        icon = Icons.local_shipping; color = Colors.blue; label = 'Confirmed'; break;
      case 'in_transit': 
        icon = Icons.directions_car; color = Colors.purple; label = 'In Transit'; break;
      case 'delivered': 
        icon = Icons.check_circle; color = Colors.green; label = 'Delivered'; break;
      default: 
        icon = Icons.help_outline; color = Colors.grey; label = 'Unknown'; 
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ✅ FIXED: Uses LIVE LOCATION like Browse Page (instead of stored lat/lng)
  Future<void> _openDeliveryWebpage(String donationId, Map<String, dynamic> data) async {
    final location = data['location'] as GeoPoint?;
    if (location == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation location not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // ✅ Get NGO's CURRENT location
    Position? ngoPosition;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        throw Exception('Location permission denied');
      }
      ngoPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get your location: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final ngoDoc = await _authService.getCurrentUserProfile();
    if (ngoDoc == null) return;

    final url = Uri.parse(
      '$_flaskServerUrl/api/delivery/request?'
      'donation_id=$donationId'
      '&ngo_id=${ngoDoc.id}'
      '&pickup_lat=${location.latitude}'
      '&pickup_lng=${location.longitude}'
      '&dropoff_lat=${ngoPosition.latitude}'
      '&dropoff_lng=${ngoPosition.longitude}'
      '&ngo_name=${Uri.encodeComponent(ngoDoc.name)}'
      '&ngo_phone=${Uri.encodeComponent(ngoDoc.phone)}'
      '&donor_name=${Uri.encodeComponent(data['createdByName'] ?? '')}'
      '&donor_phone=${Uri.encodeComponent(data['createdByPhone'] ?? '')}'
      '&serving_capacity=${data['servingCapacity'] ?? 0}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryTrackingPage(donationId: donationId),
            ),
          );
        }
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open delivery page: $e'),
            backgroundColor: kAccentColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : _userId == null
              ? const Center(
                  child: Text(
                    'Unable to load user information.',
                    style: TextStyle(color: kTextSecondary),
                  ),
                )
              : (_role != 'EventManager' && _role != 'NGO')
                  ? const Center(
                      child: Text(
                        'History is available only for Event Managers and NGOs.',
                        style: TextStyle(color: kTextSecondary),
                      ),
                    )
                  : _buildHistoryView(),
    );
  }

  Widget _buildHistoryView() {
    final userId = _userId;
    if (userId == null) {
      return const Center(
        child: Text(
          'Unable to load user information.',
          style: TextStyle(color: kTextSecondary),
        ),
      );
    }

    final isEventManager = _role == 'EventManager';

    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: isEventManager
          ? _firestoreService.getEventManagerHistoryOnce(userId, limit: 50)
          : _firestoreService.getNgoHistoryOnce(userId, limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: kAccentColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading history',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kTextSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isEventManager
                      ? Icons.restaurant_outlined
                      : Icons.inventory_2_outlined,
                  size: 64,
                  color: kTextSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  isEventManager
                      ? 'No donations created yet.'
                      : 'No donations accepted yet.',
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final dataMap = doc.data() as Map<String, dynamic>?;
              
              if (dataMap == null) {
                return const SizedBox.shrink();
              }

              final itemName = (dataMap['itemName'] ?? 'Food donation').toString();
              final description = (dataMap['description'] ?? '').toString();
              final servingCapacity = (dataMap['servingCapacity'] ?? '').toString();
              final status = (dataMap['status'] ?? '').toString();

              final createdAt = dataMap['createdAt'] as Timestamp?;
              final acceptedAt = dataMap['acceptedAt'] as Timestamp?;

              Color statusColor;
              String statusLabel;
              if (status == 'accepted') {
                statusColor = kSecondaryColor;
                statusLabel = 'Accepted';
              } else if (status == 'available') {
                statusColor = kPrimaryColor;
                statusLabel = 'Available';
              } else {
                statusColor = kTextSecondary;
                statusLabel = status.toUpperCase();
              }

              final children = <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        itemName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(color: kTextSecondary),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Serves $servingCapacity people',
                  style: const TextStyle(color: kTextSecondary),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Created: ${_formatDateTime(createdAt)} • ${_timeAgo(createdAt)}',
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (acceptedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Accepted: ${_formatDateTime(acceptedAt)}',
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ];

              if (dataMap.containsKey('deliveryRequested')) {
                final badge = _getDeliveryStatusBadge(dataMap);
                if (badge != null) children.add(badge);
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DonationDetailPage(
                        donationId: doc.id,
                        donationData: dataMap,
                      ),
                    ),
                  );
                },
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...children,
                      if (_role == 'NGO' &&
                          status == 'accepted' &&
                          (dataMap['deliveryRequested'] as bool?) == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _openDeliveryWebpage(doc.id, dataMap),
                                icon: const Icon(Icons.local_shipping, size: 18),
                                label: const Text('Manage Delivery'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}