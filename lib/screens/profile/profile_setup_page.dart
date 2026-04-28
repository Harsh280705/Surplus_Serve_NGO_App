// lib/screens/profile/profile_setup_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';

class ProfileSetupPage extends StatefulWidget {
  final String userId;
  final String? role;

  const ProfileSetupPage({
    super.key,
    required this.userId,
    this.role,
  });

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _ngoNameController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _selectedRole;
  
  // ✅ NEW: Store existing user data
  String? _existingName;
  String? _existingEmail;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.role;
    _loadExistingProfile();
  }

  // ✅ NEW: Load existing profile data (name, email) from Firestore OR Firebase Auth
  Future<void> _loadExistingProfile() async {
    try {
      // Try to get from Firestore first
      final profile = await _firestoreService.getUserProfile(widget.userId);
      if (profile != null && mounted) {
        setState(() {
          _existingName = profile.name;
          _existingEmail = profile.email;
        });
        return;
      }
    } catch (e) {
      print('No existing Firestore profile found: $e');
    }

    // ✅ If not in Firestore, get from Firebase Auth (Google Sign-In)
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && mounted) {
        setState(() {
          _existingName = currentUser.displayName;
          _existingEmail = currentUser.email;
        });
        print('✅ Got name and email from Firebase Auth: $_existingName, $_existingEmail');
      }
    } catch (e) {
      print('Error getting Firebase Auth data: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _addressController.dispose();
    _ngoNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your account type')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profileData = {
        'phone': _phoneController.text.trim(),
        'alternatePhone': _alternatePhoneController.text.trim(),
        'address': _addressController.text.trim(),
        'role': _selectedRole,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ✅ ALWAYS include name and email (from Firestore OR Firebase Auth)
      if (_existingName != null && _existingName!.isNotEmpty) {
        profileData['name'] = _existingName;
      }
      if (_existingEmail != null && _existingEmail!.isNotEmpty) {
        profileData['email'] = _existingEmail;
      }

      if (_selectedRole == 'NGO') {
        profileData['ngoName'] = _ngoNameController.text.trim();
      }

      await _firestoreService.updateUserProfile(widget.userId, profileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile completed successfully!'),
              ],
            ),
            backgroundColor: kPrimaryColor,
          ),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: kAccentColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelAndSignOut() async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Setup?'),
        content: const Text('Are you sure you want to cancel? You will be signed out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Sign Out', style: TextStyle(color: kAccentColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _cancelAndSignOut();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _cancelAndSignOut(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedRole == null)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Type',
                          style: AppTheme.headingS.copyWith(
                            color: kTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration: const InputDecoration(border: InputBorder.none),
                            items: const [
                              DropdownMenuItem(
                                value: 'NGO',
                                child: Row(
                                  children: [
                                    Icon(Icons.volunteer_activism_rounded, color: kSecondaryColor),
                                    SizedBox(width: 12),
                                    Text('NGO / Organization'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'EventManager',
                                child: Row(
                                  children: [
                                    Icon(Icons.event_rounded, color: kAccentColor),
                                    SizedBox(width: 12),
                                    Text('Event Manager / Donor'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedRole = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_selectedRole == null) const SizedBox(height: AppTheme.spacingXL),

                // ✅ PERSONAL INFORMATION SECTION (Always visible)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: AppTheme.headingS.copyWith(
                          color: kTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      
                      // Name (read-only, from Google)
                      TextFormField(
                        initialValue: _existingName ?? '',
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          helperText: 'From your Google account',
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacingM),
                      
                      // Email (read-only, from Google)
                      TextFormField(
                        initialValue: _existingEmail ?? '',
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          helperText: 'From your Google account',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),

                if (_selectedRole == 'NGO') ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NGO Information',
                          style: AppTheme.headingS.copyWith(
                            color: kTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        TextFormField(
                          controller: _ngoNameController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'NGO name is required';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'NGO Name / Organization Name',
                            prefixIcon: const Icon(Icons.business_outlined),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            helperText: 'Enter the name of your NGO or the NGO you work for',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                ],

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information',
                        style: AppTheme.headingS.copyWith(
                          color: kTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      
                      // Primary Phone
                      TextFormField(
                        controller: _phoneController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          final digitsOnly = value.replaceAll(RegExp(r'[^0-9+]'), '');
                          if (digitsOnly.length < 10 || digitsOnly.length > 15) {
                            return 'Please enter a valid phone number (10–15 digits)';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Primary Phone Number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacingM),
                      
                      // Alternate Phone
                      TextFormField(
                        controller: _alternatePhoneController,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final digitsOnly = value.replaceAll(RegExp(r'[^0-9+]'), '');
                            if (digitsOnly.length < 10 || digitsOnly.length > 15) {
                              return 'Please enter a valid phone number (10–15 digits)';
                            }
                          }
                          return null;
                        },
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: _selectedRole == 'NGO' 
                              ? 'NGO Center Number / Alternate Number'
                              : 'Alternate Phone Number (Optional)',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          helperText: 'Optional',
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacingM),
                      
                      // Address
                      TextFormField(
                        controller: _addressController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return _selectedRole == 'NGO'
                                ? 'NGO address is required so donors can find you'
                                : 'Address is required';
                          }
                          return null;
                        },
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: _selectedRole == 'NGO' 
                              ? 'NGO Address'
                              : 'Full Address',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          helperText: _selectedRole == 'NGO'
                              ? 'Enter the complete address of your NGO center'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXXL),

                AppButton(
                  text: _isLoading ? 'Saving...' : 'Save & Continue',
                  onPressed: _isLoading ? () {} : () => _saveProfile(),
                  backgroundColor: kPrimaryColor,
                  isLoading: _isLoading,
                  icon: Icons.check,
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                TextButton.icon(
                  onPressed: _isLoading ? null : () => _cancelAndSignOut(),
                  icon: const Icon(Icons.logout, color: kAccentColor),
                  label: const Text('Cancel and Sign Out'),
                  style: TextButton.styleFrom(
                    foregroundColor: kAccentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}