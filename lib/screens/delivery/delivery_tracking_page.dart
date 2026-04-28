// lib/screens/delivery/delivery_tracking_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../constants/app_colors.dart';
import '../../widgets/app_card.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final String donationId;

  const DeliveryTrackingPage({super.key, required this.donationId});

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _deliverySubscription;
  
  Map<String, dynamic>? _deliveryData;
  Map<String, dynamic>? _donationData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveryData();
  }

  Future<void> _loadDeliveryData() async {
    try {
      // Load donation details
      final donationDoc = await FirebaseFirestore.instance
          .collection('donations')
          .doc(widget.donationId)
          .get();

      if (donationDoc.exists) {
        setState(() {
          _donationData = donationDoc.data();
        });
      }

      // Listen to delivery updates in real-time
      _deliverySubscription = FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.donationId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _deliveryData = snapshot.data();
            _isLoading = false;
          });
          _updateMapCamera();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading delivery data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateMapCamera() {
    if (_mapController == null || _deliveryData == null) return;

    final pickupLat = _deliveryData!['pickup_lat'] as double?;
    final pickupLng = _deliveryData!['pickup_lng'] as double?;
    final dropoffLat = _deliveryData!['dropoff_lat'] as double?;
    final dropoffLng = _deliveryData!['dropoff_lng'] as double?;
    final driverLat = _deliveryData!['driver_lat'] as double?;
    final driverLng = _deliveryData!['driver_lng'] as double?;

    if (pickupLat == null || pickupLng == null) return;

    // Calculate bounds to fit all markers
    double minLat = pickupLat;
    double maxLat = pickupLat;
    double minLng = pickupLng;
    double maxLng = pickupLng;

    if (dropoffLat != null && dropoffLng != null) {
      minLat = minLat < dropoffLat ? minLat : dropoffLat;
      maxLat = maxLat > dropoffLat ? maxLat : dropoffLat;
      minLng = minLng < dropoffLng ? minLng : dropoffLng;
      maxLng = maxLng > dropoffLng ? maxLng : dropoffLng;
    }

    if (driverLat != null && driverLng != null) {
      minLat = minLat < driverLat ? minLat : driverLat;
      maxLat = maxLat > driverLat ? maxLat : driverLat;
      minLng = minLng < driverLng ? minLng : driverLng;
      maxLng = maxLng > driverLng ? maxLng : driverLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_deliveryData == null) return markers;

    final pickupLat = _deliveryData!['pickup_lat'] as double?;
    final pickupLng = _deliveryData!['pickup_lng'] as double?;
    final dropoffLat = _deliveryData!['dropoff_lat'] as double?;
    final dropoffLng = _deliveryData!['dropoff_lng'] as double?;
    final driverLat = _deliveryData!['driver_lat'] as double?;
    final driverLng = _deliveryData!['driver_lng'] as double?;

    // Pickup location (Event Manager/Donor)
    if (pickupLat != null && pickupLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickupLat, pickupLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '📍 Pickup Location',
            snippet: _deliveryData!['donor_name'] ?? 'Donor',
          ),
        ),
      );
    }

    // Dropoff location (NGO)
    if (dropoffLat != null && dropoffLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(dropoffLat, dropoffLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: '📍 Dropoff Location',
            snippet: _deliveryData!['ngo_name'] ?? 'NGO',
          ),
        ),
      );
    }

    // Driver location (if available)
    if (driverLat != null && driverLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driverLat, driverLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: '🚗 Delivery Partner',
            snippet: _deliveryData!['driver_name'] ?? 'On the way',
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildStatusBadge(String status) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case 'pending':
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        label = 'Pending Assignment';
        break;
      case 'confirmed':
        icon = Icons.check_circle;
        color = Colors.blue;
        label = 'Driver Assigned';
        break;
      case 'picked_up':
        icon = Icons.local_shipping;
        color = Colors.purple;
        label = 'Picked Up';
        break;
      case 'in_transit':
        icon = Icons.directions_car;
        color = Colors.indigo;
        label = 'In Transit';
        break;
      case 'delivered':
        icon = Icons.done_all;
        color = Colors.green;
        label = 'Delivered';
        break;
      case 'cancelled':
        icon = Icons.cancel;
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Delivery'),
        backgroundColor: kSecondaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deliveryData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No delivery information available',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Delivery request may still be processing',
                        style: TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Map Section
                      SizedBox(
                        height: 300,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              _deliveryData!['pickup_lat'] ?? 0.0,
                              _deliveryData!['pickup_lng'] ?? 0.0,
                            ),
                            zoom: 13,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _updateMapCamera();
                          },
                          markers: _buildMarkers(),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: false,
                        ),
                      ),

                      // Delivery Status
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: _buildStatusBadge(
                                _deliveryData!['status'] ?? 'pending',
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Driver Details Card
                            if (_deliveryData!['driver_name'] != null) ...[
                              AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.person, color: kSecondaryColor),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delivery Partner',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    _buildInfoRow(
                                      'Name',
                                      _deliveryData!['driver_name'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      'Phone',
                                      _deliveryData!['driver_phone'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      'Vehicle',
                                      _deliveryData!['vehicle_number'] ?? 'N/A',
                                    ),
                                    if (_deliveryData!['driver_rating'] != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Text(
                                            'Rating: ',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: kTextSecondary,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_deliveryData!['driver_rating']}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Donation Details
                            if (_donationData != null) ...[
                              AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.inventory_2, color: kAccentColor),
                                        SizedBox(width: 8),
                                        Text(
                                          'Donation Details',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    _buildInfoRow(
                                      'Item',
                                      _donationData!['itemName'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      'Serves',
                                      '${_donationData!['servingCapacity']} people',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      'Quantity',
                                      _donationData!['count'] ?? 'N/A',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Pickup Location
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.location_on, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text(
                                        'Pickup Location',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  _buildInfoRow(
                                    'Donor',
                                    _deliveryData!['donor_name'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    'Phone',
                                    _deliveryData!['donor_phone'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    'Address',
                                    '${_deliveryData!['pickup_lat']?.toStringAsFixed(6)}, ${_deliveryData!['pickup_lng']?.toStringAsFixed(6)}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Dropoff Location
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.location_on, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text(
                                        'Dropoff Location',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  _buildInfoRow(
                                    'NGO',
                                    _deliveryData!['ngo_name'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    'Phone',
                                    _deliveryData!['ngo_phone'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    'Address',
                                    '${_deliveryData!['dropoff_lat']?.toStringAsFixed(6)}, ${_deliveryData!['dropoff_lng']?.toStringAsFixed(6)}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Timeline
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.timeline, color: kPrimaryColor),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delivery Timeline',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  if (_deliveryData!['created_at'] != null)
                                    _buildTimelineItem(
                                      'Requested',
                                      _formatTimestamp(_deliveryData!['created_at']),
                                      Colors.blue,
                                    ),
                                  if (_deliveryData!['confirmed_at'] != null)
                                    _buildTimelineItem(
                                      'Driver Assigned',
                                      _formatTimestamp(_deliveryData!['confirmed_at']),
                                      Colors.green,
                                    ),
                                  if (_deliveryData!['picked_up_at'] != null)
                                    _buildTimelineItem(
                                      'Picked Up',
                                      _formatTimestamp(_deliveryData!['picked_up_at']),
                                      Colors.purple,
                                    ),
                                  if (_deliveryData!['delivered_at'] != null)
                                    _buildTimelineItem(
                                      'Delivered',
                                      _formatTimestamp(_deliveryData!['delivered_at']),
                                      Colors.green,
                                      isLast: true,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              color: kTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    String title,
    String time,
    Color color, {
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: color.withOpacity(0.3),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _deliverySubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}