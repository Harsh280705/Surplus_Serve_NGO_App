// lib/screens/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = true;

  // Settings states
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isDarkMode = false;
  bool _appLockEnabled = false;
  bool _locationEnabled = false;
  String _fontSize = 'normal';
  String _dateFormat = 'DD/MM/YYYY';
  String _timeFormat = '12h';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _pushNotifications = prefs.getBool('pushNotifications') ?? true;
      _emailNotifications = prefs.getBool('emailNotifications') ?? true;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _appLockEnabled = prefs.getBool('appLockEnabled') ?? false;
      _fontSize = prefs.getString('fontSize') ?? 'normal';
      _dateFormat = prefs.getString('dateFormat') ?? 'DD/MM/YYYY';
      _timeFormat = prefs.getString('timeFormat') ?? '12h';
      _isLoading = false;
    });

    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    setState(() {
      _locationEnabled = status.isGranted;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    if (value) {
      // Request notification permission using Permission.notification
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        _showSnackBar('Notification permission denied');
        return;
      }
    }
    setState(() => _pushNotifications = value);
    await _saveSetting('pushNotifications', value);
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    setState(() => _emailNotifications = value);
    await _saveSetting('emailNotifications', value);

    // Update in Firestore
    final userId = _authService.currentUserId;
    if (userId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'emailNotificationsEnabled': value});
    }
  }

  Future<void> _toggleSound(bool value) async {
    setState(() => _soundEnabled = value);
    await _saveSetting('soundEnabled', value);
  }

  Future<void> _toggleVibration(bool value) async {
    setState(() => _vibrationEnabled = value);
    await _saveSetting('vibrationEnabled', value);
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() => _isDarkMode = value);
    await _saveSetting('isDarkMode', value);
    _showSnackBar('App theme will change on restart');
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      // Check if biometric is available
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        _showSnackBar('Biometric authentication not available on this device');
        return;
      }

      // Show PIN setup dialog
      final pin = await _showPinSetupDialog();
      if (pin == null) return;

      await _saveSetting('appLockPin', pin);
    }

    setState(() => _appLockEnabled = value);
    await _saveSetting('appLockEnabled', value);
  }

  Future<void> _toggleLocationPermission(bool value) async {
    if (value) {
      final status = await Permission.location.request();
      setState(() => _locationEnabled = status.isGranted);
    } else {
      await openAppSettings();
      _showSnackBar('Please disable location in system settings');
    }
  }

  Future<void> _changeFontSize(String size) async {
    setState(() => _fontSize = size);
    await _saveSetting('fontSize', size);
    _showSnackBar('Font size changed to $size');
  }

  Future<void> _changeDateFormat(String format) async {
    setState(() => _dateFormat = format);
    await _saveSetting('dateFormat', format);
  }

  Future<void> _changeTimeFormat(String format) async {
    setState(() => _timeFormat = format);
    await _saveSetting('timeFormat', format);
  }

  Future<void> _scheduleAccountDeletion() async {
    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed) return;

    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      final deletionDate = DateTime.now().add(const Duration(days: 30));

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'scheduledForDeletion': true,
        'deletionDate': Timestamp.fromDate(deletionDate),
      });

      _showSnackBar(
        'Account will be deleted on ${deletionDate.day}/${deletionDate.month}/${deletionDate.year} if no login is detected',
      );

      await _authService.signOut();
    } catch (e) {
      _showSnackBar('Error scheduling deletion: $e');
    }
  }

  Future<String?> _showPinSetupDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Set PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter a 4-digit PIN to secure your app'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.length == 4) {
                  Navigator.pop(context, controller.text);
                } else {
                  _showSnackBar('PIN must be 4 digits');
                }
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'Your account will be permanently deleted 30 days after your last login. '
              'If you login within 30 days, the deletion will be cancelled.\n\n'
              'Are you sure you want to proceed?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showPermissionInfo(String permission, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission'),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading settings...'),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Notifications'),
          _buildSettingCard(
            'Push Notifications',
            'Receive notifications about donations and messages',
            Icons.notifications_rounded,
            Switch(
              value: _pushNotifications,
              onChanged: _togglePushNotifications,
              activeTrackColor: kPrimaryColor.withValues(alpha:0.5),
              activeThumbColor: kPrimaryColor,
            ),
          ),
          _buildSettingCard(
            'Email Notifications',
            'Receive updates via email',
            Icons.email_rounded,
            Switch(
              value: _emailNotifications,
              onChanged: _toggleEmailNotifications,
              activeTrackColor: kPrimaryColor.withValues(alpha:0.5),
              activeThumbColor: kPrimaryColor,
            ),
          ),
          _buildSettingCard(
            'Sound',
            'Play sound for notifications',
            Icons.volume_up_rounded,
            Switch(
              value: _soundEnabled,
              onChanged: _toggleSound,
              activeTrackColor: kPrimaryColor.withValues(alpha:0.5),
              activeThumbColor: kPrimaryColor,
            ),
          ),
          _buildSettingCard(
            'Vibration',
            'Vibrate for notifications',
            Icons.vibration_rounded,
            Switch(
              value: _vibrationEnabled,
              onChanged: _toggleVibration,
              activeTrackColor: kPrimaryColor.withValues(alpha:0.5),
              activeThumbColor: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Appearance'),
          _buildSettingCard(
            'Dark Mode',
            'Switch to dark theme',
            Icons.dark_mode_rounded,
            Switch(
              value: _isDarkMode,
              onChanged: _toggleDarkMode,
              activeTrackColor: kPrimaryColor.withValues(alpha:0.5),
              activeThumbColor: kPrimaryColor,
            ),
          ),
          _buildTappableCard(
            'Font Size',
            _fontSize.toUpperCase(),
            Icons.text_fields_rounded,
            () => _showFontSizeDialog(),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Security & Privacy'),
          _buildSettingCard(
            'App Lock',
            'Secure app with PIN or fingerprint',
            Icons.lock_rounded,
            Switch(
              value: _appLockEnabled,
              onChanged: _toggleAppLock,
              activeTrackColor: kPrimaryColor.withValues(alpha:0.5),
              activeThumbColor: kPrimaryColor,
            ),
          ),
          _buildSettingCard(
            'Location Access',
            'Allow app to access your location',
            Icons.location_on_rounded,
            Switch(
              value: _locationEnabled,
              onChanged: _toggleLocationPermission,
              activeTrackColor: kPrimaryColor.withValues(alpha:0.5),
              activeThumbColor: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Date & Time'),
          _buildTappableCard(
            'Date Format',
            _dateFormat,
            Icons.calendar_today_rounded,
            () => _showDateFormatDialog(),
          ),
          _buildTappableCard(
            'Time Format',
            _timeFormat,
            Icons.access_time_rounded,
            () => _showTimeFormatDialog(),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Permissions Info'),
          _buildTappableCard(
            'Camera Permission',
            'Why we need camera access',
            Icons.camera_alt_rounded,
            () => _showPermissionInfo(
              'Camera',
              'We need camera access to allow you to take photos of food donations and update your profile picture.',
            ),
          ),
          _buildTappableCard(
            'Storage Permission',
            'Why we need storage access',
            Icons.storage_rounded,
            () => _showPermissionInfo(
              'Storage',
              'We need storage access to save and retrieve donation photos and documents from your device.',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Account'),
          AppCard(
            child: AppButton(
              text: 'Schedule Account Deletion',
              onPressed: _scheduleAccountDeletion,
              backgroundColor: Colors.red,
              icon: Icons.delete_forever_rounded,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: kTextPrimary,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    String title,
    String subtitle,
    IconData icon,
    Widget trailing,
  ) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kPrimaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildTappableCard(
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return AppCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kPrimaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: kTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

void _showFontSizeDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Font Size'),
      content: RadioGroup<String>(
        groupValue: _fontSize,
        onChanged: (value) {
          if (value != null) {
            _changeFontSize(value);
            Navigator.pop(context);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            RadioListTile<String>(
              title: Text('Small'),
              value: 'small',
            ),
            RadioListTile<String>(
              title: Text('Normal'),
              value: 'normal',
            ),
            RadioListTile<String>(
              title: Text('Large'),
              value: 'large',
            ),
          ],
        ),
      ),
    ),
  );
}

void _showDateFormatDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Date Format'),
      content: RadioGroup<String>(
        groupValue: _dateFormat,
        onChanged: (value) {
          if (value != null) {
            _changeDateFormat(value);
            Navigator.pop(context);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            RadioListTile<String>(
              title: Text('DD/MM/YYYY'),
              value: 'DD/MM/YYYY',
            ),
            RadioListTile<String>(
              title: Text('MM/DD/YYYY'),
              value: 'MM/DD/YYYY',
            ),
            RadioListTile<String>(
              title: Text('YYYY-MM-DD'),
              value: 'YYYY-MM-DD',
            ),
          ],
        ),
      ),
    ),
  );
}


void _showTimeFormatDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Time Format'),
      content: RadioGroup<String>(
        groupValue: _timeFormat,
        onChanged: (value) {
          if (value != null) {
            _changeTimeFormat(value);
            Navigator.pop(context);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            RadioListTile<String>(
              title: Text('12-hour (AM/PM)'),
              value: '12h',
            ),
            RadioListTile<String>(
              title: Text('24-hour'),
              value: '24h',
            ),
          ],
        ),
      ),
    ),
  );
}
}