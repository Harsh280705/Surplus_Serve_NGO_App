// lib/screens/donations/browse_donations_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show sqrt, asin, sin, cos, pi;
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'donation_detail_page.dart';
import '../delivery/delivery_tracking_page.dart';

class BrowseDonationsPage extends StatefulWidget {
  const BrowseDonationsPage({super.key});

  @override
  State<BrowseDonationsPage> createState() => _BrowseDonationsPageState();
}

class _BrowseDonationsPageState extends State<BrowseDonationsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _isLoadingProfile = true;
  UserRoleInfo? _roleInfo;
  String? _actionInProgressId;

  // ✅ Radius filter for NGO
  double _radiusKm = 10.0; // Default 10 km
  Position? _ngoLocation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = await _authService.getCurrentUserProfile();
      if (!mounted) return;
      _roleInfo = UserRoleInfo(
        id: _authService.currentUserId,
        role: user?.role ?? '',
        name: user?.name ?? '',
        phone: user?.phone ?? '',
      );
      if (_roleInfo?.role == 'NGO') {
        await _getNgoLocation();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _getNgoLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Enable in settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _ngoLocation = position;
        });

        final accuracyStatus = position.accuracy < 20
            ? '✅ High accuracy'
            : position.accuracy < 50
                ? '⚠️ Medium accuracy'
                : '❌ Low accuracy';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📍 Location updated\n'
              'Accuracy: ±${position.accuracy.toStringAsFixed(1)}m\n'
              '$accuracyStatus',
            ),
            backgroundColor: position.accuracy < 50 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // ✅ Haversine formula - FREE and accurate for radius filtering
  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double lat1Rad = _degreesToRadians(lat1);
    final double lat2Rad = _degreesToRadians(lat2);
    final double a = (sin(dLat / 2) * sin(dLat / 2)) +
        (sin(dLon / 2) * sin(dLon / 2)) * cos(lat1Rad) * cos(lat2Rad);
    final double c = 2 * asin(sqrt(a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  // ✅ NEW: Show delivery options dialog
  Future<void> _showDeliveryOptionsDialog(DocumentSnapshot doc) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery Options'),
        content: const Text('How would you like to receive the donation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'pickup'),
            child: const Text('I will pick it up'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'delivery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kSecondaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Request Delivery'),
          ),
        ],
      ),
    );

    if (choice == 'pickup') {
      await _acceptDonation(doc, requestDelivery: false);
    } else if (choice == 'delivery') {
      await _acceptDonation(doc, requestDelivery: true);
    }
  }

  // ✅ NEW: Open delivery webpage and then redirect to tracking page
  Future<void> _openDeliveryWebpage(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'] as GeoPoint?;

    if (location == null || _ngoLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location information not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Replace with your actual Flask server URL
    const String flaskServerUrl = 'http://192.168.29.226:5000';
    final url = Uri.parse(
        '$flaskServerUrl/api/delivery/request?'
        'donation_id=${doc.id}'
        '&ngo_id=${_roleInfo!.id}'
        '&pickup_lat=${location.latitude}'
        '&pickup_lng=${location.longitude}'
        '&dropoff_lat=${_ngoLocation!.latitude}'
        '&dropoff_lng=${_ngoLocation!.longitude}'
        '&ngo_name=${Uri.encodeComponent(_roleInfo!.name)}'
        '&ngo_phone=${Uri.encodeComponent(_roleInfo!.phone)}'
        '&donor_name=${Uri.encodeComponent(data['createdByName'] ?? '')}'
        '&donor_phone=${Uri.encodeComponent(data['createdByPhone'] ?? '')}'
        '&serving_capacity=${data['servingCapacity'] ?? 0}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );

        // Wait a moment for the webpage to process, then navigate to tracking page
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryTrackingPage(donationId: doc.id),
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

  // ✅ Accept donation (NGO only)
  Future<void> _acceptDonation(DocumentSnapshot doc, {required bool requestDelivery}) async {
    if (_roleInfo == null || _roleInfo!.role != 'NGO') return;
    final ngoId = _roleInfo!.id!;
    final ngoName = _roleInfo!.name;
    final data = doc.data() as Map<String, dynamic>;
    final eventManagerId = data['createdBy'] as String?;

    if (eventManagerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation has no owner.'),
            backgroundColor: kAccentColor,
          ),
        );
      }
      return;
    }

    setState(() {
      _actionInProgressId = doc.id;
    });

    try {
      await FirebaseFirestore.instance.collection('donations').doc(doc.id).update({
        'status': 'accepted',
        'acceptedBy': ngoId,
        'acceptedByName': ngoName,
        'acceptedAt': FieldValue.serverTimestamp(),
        'confirmedByEventManager': false,
        'deliveryRequested': requestDelivery,
        if (requestDelivery) 'deliveryStatus': 'pending',
        if (requestDelivery) 'deliveryRequestedAt': FieldValue.serverTimestamp(),
      });

      await _firestoreService.incrementNgoAcceptedCount(ngoId);
      
      // ✅ FIXED: Replaced ensureChatExists with getOrCreateChatRoom
      await _firestoreService.getOrCreateChatRoom(
        donationId: doc.id,
        otherUserId: eventManagerId,
        donationTitle: data['itemName'] ?? 'Food Donation',
      );

      if (mounted) {
        if (requestDelivery) {
          // Open delivery webpage
          await _openDeliveryWebpage(doc);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              requestDelivery
                  ? 'Donation accepted! Please complete delivery request.'
                  : 'Donation accepted! Chat created with donor.',
            ),
            backgroundColor: kSecondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting donation: $e'),
            backgroundColor: kAccentColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgressId = null;
        });
      }
    }
  }

  Future<void> _declineDonation(DocumentSnapshot doc) async {
    if (_roleInfo == null || _roleInfo!.role != 'NGO') return;
    final data = doc.data() as Map<String, dynamic>;
    final itemName = data['itemName'] ?? 'this donation';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Donation'),
        content: Text(
          'Are you sure you want to decline "$itemName"?\nYou won\'t see this donation again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Decline',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ngoId = _roleInfo!.id!;
    setState(() {
      _actionInProgressId = doc.id;
    });

    try {
      await FirebaseFirestore.instance.collection('donations').doc(doc.id).update({
        'declinedBy': FieldValue.arrayUnion([ngoId]),
      });

      await NotificationService().notifyNgoDeclineInApp(
        ngoId: ngoId,
        donationId: doc.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining donation: $e'),
            backgroundColor: kAccentColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgressId = null;
        });
      }
    }
  }

  // ✅ Confirm donation delivery (Event Manager only)
  Future<void> _confirmDonationDelivery(DocumentSnapshot doc) async {
    if (_roleInfo == null || _roleInfo!.role != 'Event Manager') return;
    final data = doc.data() as Map<String, dynamic>;
    final itemName = data['itemName'] ?? 'this donation';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Text(
          'Confirm that "$itemName" has been delivered to the NGO?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _actionInProgressId = doc.id;
    });

    try {
      await _firestoreService.confirmDonationDelivery(doc.id);

      final ngoId = data['acceptedBy'] as String?;
      if (ngoId != null) {
        await NotificationService().notifyDonationConfirmed(
          ngoId: ngoId,
          donationId: doc.id,
          donationName: itemName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery confirmed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgressId = null;
        });
      }
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return 'more than a day ago';
  }

  // ✅ Get delivery status badge
  Widget _getDeliveryStatusBadge(Map<String, dynamic> data) {
    final deliveryRequested = (data['deliveryRequested'] as bool?) ?? false;
    if (!deliveryRequested) return const SizedBox.shrink();

    final String deliveryStatus = data['deliveryStatus'] ?? 'pending';
    IconData icon;
    Color color;
    String label;

    switch (deliveryStatus) {
      case 'pending':
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        label = 'Delivery Pending';
        break;
      case 'confirmed':
        icon = Icons.local_shipping;
        color = Colors.blue;
        label = 'Delivery Confirmed';
        break;
      case 'in_transit':
        icon = Icons.directions_car;
        color = Colors.purple;
        label = 'In Transit';
        break;
      case 'delivered':
        icon = Icons.check_circle;
        color = Colors.green;
        label = 'Delivered';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        label = 'Unknown Status';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getDonationsStream() {
    final userId = _roleInfo!.id!;
    final userRole = _roleInfo!.role;

    if (userRole == 'NGO') {
      return _firestoreService.getAvailableDonationsForNgo(userId);
    } else if (userRole == 'Event Manager') {
      return FirebaseFirestore.instance
          .collection('donations')
          .where('createdBy', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .orderBy('acceptedAt', descending: true)
          .snapshots();
    } else {
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _roleInfo?.role == 'Event Manager'
              ? 'Pending Confirmations'
              : 'Browse Donations',
        ),
        backgroundColor: kSecondaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✅ Radius UI for NGO
                if (_roleInfo?.role == 'NGO') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Search Radius',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kTextPrimary,
                              ),
                            ),
                            if (_isLoadingLocation)
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else if (_ngoLocation == null)
                              TextButton.icon(
                                onPressed: _getNgoLocation,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Get Location'),
                                style: TextButton.styleFrom(
                                  foregroundColor: kSecondaryColor,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _ngoLocation == null
                                  ? Icons.location_off
                                  : Icons.location_on,
                              color: _ngoLocation == null ? Colors.orange : Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _ngoLocation == null
                                    ? 'Location not available – showing all donations'
                                    : 'Showing donations within ${_radiusKm.toStringAsFixed(0)} km',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _ngoLocation == null ? Colors.orange : kTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              '1 km',
                              style: TextStyle(fontSize: 12, color: kTextSecondary),
                            ),
                            Expanded(
                              child: Slider(
                                value: _radiusKm,
                                min: 1.0,
                                max: 50.0,
                                divisions: 49,
                                activeColor: kSecondaryColor,
                                label: '${_radiusKm.toStringAsFixed(0)} km',
                                onChanged: _ngoLocation == null
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _radiusKm = value;
                                        });
                                      },
                              ),
                            ),
                            const Text(
                              '50 km',
                              style: TextStyle(fontSize: 12, color: kTextSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
                // ✅ Donations list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getDonationsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      List<DocumentSnapshot> filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final userId = _roleInfo!.id;
                        final userRole = _roleInfo!.role;

                        if (userRole == 'NGO') {
                          final declinedBy = data['declinedBy'] as List<dynamic>?;
                          if (declinedBy != null && declinedBy.contains(userId)) {
                            return false;
                          }

                          final now = DateTime.now();
                          // ✅ FIXED: Use acceptedAt for 24-hour visibility of accepted donations
                          if (data['status'] == 'accepted' && data['acceptedBy'] == userId) {
                            final acceptedAt = (data['acceptedAt'] as Timestamp?)?.toDate();
                            if (acceptedAt != null && now.difference(acceptedAt).inHours < 24) {
                              return true;
                            }
                          }
                          // ✅ Keep using createdAt for 'available' donations
                          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                          if (data['status'] == 'available') {
                            if (createdAt != null && now.difference(createdAt).inHours < 24) {
                              return true;
                            }
                          }
                          return false;
                        }

                        if (userRole == 'Event Manager') {
                          return data['status'] == 'accepted' &&
                              data['confirmedByEventManager'] != true;
                        }

                        return false;
                      }).toList();

                      // ✅ Apply Haversine radius filter
                      if (_roleInfo?.role == 'NGO' && _ngoLocation != null) {
                        filteredDocs = filteredDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final location = data['location'] as GeoPoint?;
                          if (location == null) return false;
                          final distance = _calculateHaversineDistance(
                            _ngoLocation!.latitude,
                            _ngoLocation!.longitude,
                            location.latitude,
                            location.longitude,
                          );
                          return distance <= _radiusKm;
                        }).toList();
                      }

                      if (filteredDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _roleInfo!.role == 'NGO'
                                      ? Icons.search_off
                                      : Icons.inbox,
                                  size: 64,
                                  color: kTextSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _roleInfo!.role == 'NGO'
                                      ? (_ngoLocation == null
                                          ? 'Enable location to see nearby donations'
                                          : 'No donations within ${_radiusKm.toStringAsFixed(0)} km')
                                      : 'No pending confirmations.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: kTextSecondary),
                                ),
                                if (_roleInfo!.role == 'NGO' && _ngoLocation != null) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _radiusKm = (_radiusKm + 10).clamp(1.0, 50.0);
                                      });
                                    },
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: const Text('Increase Radius'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: kSecondaryColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final bool isLoading = _actionInProgressId == doc.id;
                          final bool isAccepted = data['status'] == 'accepted';
                          final bool canAccept = _roleInfo?.role == 'NGO' && data['status'] == 'available';
                          final bool canConfirm = _roleInfo?.role == 'Event Manager' &&
                              isAccepted &&
                              data['createdBy'] == _roleInfo!.id &&
                              data['confirmedByEventManager'] != true;

                          // ✅ Distance badge
                          String? distanceText;
                          if (_roleInfo?.role == 'NGO' &&
                              _ngoLocation != null &&
                              data['location'] != null) {
                            final location = data['location'] as GeoPoint;
                            final distance = _calculateHaversineDistance(
                              _ngoLocation!.latitude,
                              _ngoLocation!.longitude,
                              location.latitude,
                              location.longitude,
                            );
                            distanceText = '${distance.toStringAsFixed(1)} km';
                          }

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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          data['itemName'] ?? 'Food Donation',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: kTextPrimary,
                                          ),
                                        ),
                                      ),
                                      if (distanceText != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: kSecondaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.pin_drop_outlined,
                                                size: 12,
                                                color: kSecondaryColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                distanceText,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: kSecondaryColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Serves ${data['servingCapacity']} people',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Quantity: ${data['count']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data['description'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: kTextSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Posted ${_timeAgo(data['createdAt'])}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kTextSecondary,
                                    ),
                                  ),
                                  if (isAccepted) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: kSecondaryColor, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: _roleInfo!.role == 'NGO'
                                                      ? 'Accepted by you '
                                                      : 'Accepted by ${data['acceptedByName'] ?? 'NGO'} ',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: kTextSecondary,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: _timeAgo(data['acceptedAt']),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: kSecondaryColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // ✅ Show delivery status badge
                                    _getDeliveryStatusBadge(data),
                                  ],
                                  const SizedBox(height: 12),
                                  if (canAccept)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: isLoading
                                              ? null
                                              : () => _declineDonation(doc),
                                          child: isLoading
                                              ? const SizedBox(
                                                  height: 16,
                                                  width: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Text('Decline'),
                                        ),
                                        const SizedBox(width: 8),
                                        AppButton(
                                          text: 'Accept',
                                          onPressed: isLoading
                                              ? () {}
                                              : () => _showDeliveryOptionsDialog(doc),
                                          backgroundColor: kSecondaryColor,
                                          icon: Icons.check,
                                          fullWidth: false,
                                        ),
                                      ],
                                    )
                                  else if (canConfirm)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        onPressed: isLoading
                                            ? null
                                            : () => _confirmDonationDelivery(doc),
                                        icon: isLoading
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.check, size: 20),
                                        label: const Text('Confirm Delivery'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    )
                                  else if (isAccepted && _roleInfo!.role == 'NGO')
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // ✅ Show "Manage Delivery" button if delivery was requested
                                        if ((data['deliveryRequested'] as bool?) ?? false)
                                          TextButton.icon(
                                            onPressed: () => _openDeliveryWebpage(doc),
                                            icon: const Icon(Icons.local_shipping, size: 18),
                                            label: const Text('Manage Delivery'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.blue,
                                            ),
                                          ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: kSecondaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'ACCEPTED',
                                            style: TextStyle(
                                              color: kSecondaryColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class UserRoleInfo {
  final String? id;
  final String role;
  final String name;
  final String phone;

  UserRoleInfo({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
  });
}