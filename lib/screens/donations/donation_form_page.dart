// lib/screens/donation/donation_form_page.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_colors.dart';
import '../../models/donation.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';

class DonationFormPage extends StatefulWidget {
  final Donation? donation; // For edit mode
  
  const DonationFormPage({super.key, this.donation});

  @override
  State<DonationFormPage> createState() => _DonationFormPageState();
}

class _DonationFormPageState extends State<DonationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _countController = TextEditingController();
  final _servingController = TextEditingController();
  final _descriptionController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  Position? _currentPosition;
  bool _locationLoading = true;
  bool _isEditMode = false;
  bool _useCustomLocation = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.donation != null;
    
    if (_isEditMode) {
      // Pre-fill form for editing
      _itemNameController.text = widget.donation!.itemName;
      _countController.text = widget.donation!.count;
      _servingController.text = widget.donation!.servingCapacity;
      _descriptionController.text = widget.donation!.description;
      
      // Use existing location
      if (widget.donation!.location != null) {
        _currentPosition = Position(
          latitude: widget.donation!.location!.latitude,
          longitude: widget.donation!.location!.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
      _locationLoading = false;
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _locationLoading = false);
          _showLocationError('Location services are disabled.');
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
          setState(() => _locationLoading = false);
          _showLocationError('Location access denied. Enable in settings.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationLoading = false);
        _showLocationError(
          'Unable to get location. Donation will be added without map pin.',
        );
      }
    }
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ✅ NEW: Open map picker
  Future<void> _pickLocationOnMap() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location first...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final LatLng? pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialPosition: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
        ),
      ),
    );

    if (pickedLocation != null) {
      setState(() {
        _currentPosition = Position(
          latitude: pickedLocation.latitude,
          longitude: pickedLocation.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        _useCustomLocation = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Custom location selected'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: kAccentColor,
        ),
      );
      return;
    }

    // Parse serving capacity for final validation
    final servingCapacity = int.tryParse(_servingController.text.trim());
    if (servingCapacity == null || servingCapacity < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Minimum donation should serve at least 20 people to help reduce food waste effectively'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProfile = await _authService.getCurrentUserProfile();
      final userId = _authService.currentUserId;

      if (_isEditMode) {
        // Check edit constraints
        final canEdit = _canEditDonation(widget.donation!);
        if (!canEdit) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot edit: Either 30 minutes have passed or you have already edited 3 times'),
                backgroundColor: kAccentColor,
                duration: Duration(seconds: 4),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Update donation
        final updatedData = <String, dynamic>{
          'itemName': _itemNameController.text.trim(),
          'count': _countController.text.trim(),
          'servingCapacity': _servingController.text.trim(),
          'description': _descriptionController.text.trim(),
          'editCount': (widget.donation!.editCount ?? 0) + 1,
          'lastEditedAt': FieldValue.serverTimestamp(),
        };

        await _firestoreService.updateDonation(widget.donation!.id, updatedData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Donation updated successfully!'),
              backgroundColor: kPrimaryColor,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new donation
        final donationData = <String, dynamic>{
          'category': 'Food',
          'itemName': _itemNameController.text.trim(),
          'count': _countController.text.trim(),
          'servingCapacity': _servingController.text.trim(),
          'description': _descriptionController.text.trim(),
          'createdBy': userId,
          'createdByName': userProfile?.name ?? 'Anonymous',
          'createdByPhone': userProfile?.phone ?? '',
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
          'editCount': 0,
          if (_currentPosition != null)
            'location': GeoPoint(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
        };

        await _firestoreService.addDonation(donationData);

        if (userId != null && userProfile?.role == 'EventManager') {
          await _firestoreService.incrementEventManagerDonationCount(userId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Donation submitted successfully!'),
              backgroundColor: kPrimaryColor,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: kAccentColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _canEditDonation(Donation donation) {
    final now = DateTime.now();
    final createdAt = donation.createdAt;
    final timeDifference = now.difference(createdAt);
    
    if (timeDifference.inMinutes > 30) {
      return false;
    }

    if ((donation.editCount ?? 0) >= 3) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Donation' : 'Add Donation'),
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditMode ? 'Edit Your Donation' : 'Share Your Food',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEditMode 
                      ? 'You can edit this donation ${3 - (widget.donation?.editCount ?? 0)} more time(s) within 30 minutes of creation.'
                      : 'Help reduce food waste by sharing your excess food with organizations.',
                  style: const TextStyle(fontSize: 14, color: kTextSecondary),
                ),
                
                // ✅ Location section
                const SizedBox(height: 16),
                if (_locationLoading)
                  const Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 8),
                      Text(
                        'Getting your location...',
                        style: TextStyle(color: kTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                if (_currentPosition != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _useCustomLocation ? Icons.edit_location : Icons.location_on,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _useCustomLocation
                                    ? '📍 Custom location selected'
                                    : '📍 Using your current location',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, '
                          'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _getCurrentLocation,
                                icon: const Icon(Icons.my_location, size: 16),
                                label: const Text('Use My Location'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(color: Colors.green),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickLocationOnMap,
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text('Pick on Map'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (_currentPosition == null && !_locationLoading && !_isEditMode)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_off, color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '📍 Location not available',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Donation will not appear on map',
                          style: TextStyle(color: Colors.orange, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Food Item Name',
                  controller: _itemNameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Food item name is required';
                    }
                    return null;
                  },
                  prefixIcon: Icons.restaurant,
                ),
                const SizedBox(height: 16),
                
                // ✅ UPDATED: Allow text in quantity field
                AppTextField(
                  label: 'Quantity/Count',
                  controller: _countController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Quantity is required';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.text,
                  prefixIcon: Icons.format_list_numbered,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    '💡 E.g., "5 boxes", "10 kgs", "20 plates"',
                    style: TextStyle(
                      fontSize: 12,
                      color: kTextSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Serving Capacity (people)',
                  controller: _servingController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Serving capacity is required';
                    }
                    final capacity = int.tryParse(value.trim());
                    if (capacity == null) {
                      return 'Please enter a valid number';
                    }
                    if (capacity < 20) {
                      return 'Minimum 20 people required';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.people,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    '💡 Minimum donation should serve at least 20 people',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Description',
                  controller: _descriptionController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                  maxLines: 3,
                  prefixIcon: Icons.description,
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: _isEditMode ? 'Update Donation' : 'Submit Donation',
                  onPressed: _isLoading ? () {} : () => _submitDonation(),
                  isLoading: _isLoading,
                  backgroundColor: kAccentColor,
                  icon: _isEditMode ? Icons.update : Icons.send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _countController.dispose();
    _servingController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// ✅ NEW: Map Picker Page
class MapPickerPage extends StatefulWidget {
  final LatLng initialPosition;

  const MapPickerPage({super.key, required this.initialPosition});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late LatLng _selectedPosition;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedPosition),
            child: const Text(
              'DONE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (position) {
              setState(() {
                _selectedPosition = position;
              });
            },
            markers: {
              Marker(
                markerId: const MarkerId('selected_location'),
                position: _selectedPosition,
                draggable: true,
                onDragEnd: (newPosition) {
                  setState(() {
                    _selectedPosition = newPosition;
                  });
                },
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: kSecondaryColor, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tap or drag marker to select location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, color: kTextSecondary),
                  ),
                  Text(
                    'Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, color: kTextSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}