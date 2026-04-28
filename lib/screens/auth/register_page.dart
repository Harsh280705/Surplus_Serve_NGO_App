// lib/screens/auth/register_page.dart (FIXED VERSION)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/validators.dart';
import '../../widgets/animated_widgets.dart';
import '../profile/profile_setup_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedRole = 'NGO';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.red;
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;

  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      int strength = 0;
      if (_hasMinLength) strength++;
      if (_hasUppercase) strength++;
      if (_hasNumber) strength++;
      if (_hasSymbol) strength++;

      _passwordStrength = strength / 4;

      if (strength == 0) {
        _passwordStrengthText = '';
        _passwordStrengthColor = Colors.transparent;
      } else if (strength == 1) {
        _passwordStrengthText = 'Weak';
        _passwordStrengthColor = Colors.red;
      } else if (strength == 2) {
        _passwordStrengthText = 'Fair';
        _passwordStrengthColor = Colors.orange;
      } else if (strength == 3) {
        _passwordStrengthText = 'Good';
        _passwordStrengthColor = Colors.blue;
      } else {
        _passwordStrengthText = 'Strong';
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Passwords do not match')),
            ],
          ),
          backgroundColor: kAccentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          margin: const EdgeInsets.all(AppTheme.spacingM),
        ),
      );
      return;
    }

    if (_passwordStrength < 0.75) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Please use a stronger password (at least Good strength)'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          margin: const EdgeInsets.all(AppTheme.spacingM),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    _progressController.forward();

    try {
      final userCredential = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      await _firestoreService.createUserProfile(userCredential.user!.uid, {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'alternatePhone': '', // ADD THIS - empty by default
        'address': _addressController.text.trim(),
        'role': _selectedRole,
        'photoUrl': userCredential.user!.photoURL ?? '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Registration successful!')),
              ],
            ),
            backgroundColor: kPrimaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            margin: const EdgeInsets.all(AppTheme.spacingM),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: kAccentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            margin: const EdgeInsets.all(AppTheme.spacingM),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _progressController.reverse();
      }
    }
  }

  Future<void> _socialRegister(String provider) async {
    setState(() => _isLoading = true);
    try {
      UserCredential? userCredential;
      switch (provider) {
        case 'google':
          userCredential = await _authService.signInWithGoogle();
          break;
      }

      if (userCredential != null && userCredential.user != null) {
        final userId = userCredential.user!.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (!userDoc.exists) {
          // New Google user - show role selection dialog
          final selectedRole = await _showRoleSelectionDialog();

          if (selectedRole == null) {
            await _authService.signOut();
            if (mounted) setState(() => _isLoading = false);
            return;
          }

          // Create basic profile with Google info
          await _firestoreService.createUserProfile(userId, {
            'name': userCredential.user!.displayName ?? 'Google User',
            'email': userCredential.user!.email ?? '',
            'phone': '', // Empty - will be completed in profile setup
            'address': '', // Empty - will be completed in profile setup
            'role': selectedRole,
            'photoUrl': userCredential.user!.photoURL ?? '',
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Welcome! Please complete your profile.'),
                    ),
                  ],
                ),
                backgroundColor: kPrimaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                margin: const EdgeInsets.all(AppTheme.spacingM),
              ),
            );
            
            // Navigate to profile setup
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileSetupPage(
                  userId: userId,
                  role: selectedRole,
                ),
              ),
            );
          }
        } else {
          // Existing user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Account already exists. Signing you in...')),
                  ],
                ),
                backgroundColor: kPrimaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                margin: const EdgeInsets.all(AppTheme.spacingM),
              ),
            );
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: kAccentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            margin: const EdgeInsets.all(AppTheme.spacingM),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showRoleSelectionDialog() async {
    return await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String? selectedRole;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_circle,
                      color: kPrimaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select Account Type',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Please choose how you want to use SurplusServe:',
                    style: AppTheme.bodyM.copyWith(color: kTextSecondary),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () => setState(() => selectedRole = 'NGO'),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedRole == 'NGO'
                              ? kPrimaryColor
                              : Colors.grey.shade300,
                          width: selectedRole == 'NGO' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        color: selectedRole == 'NGO'
                            ? kPrimaryColor.withValues(alpha: 0.05)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kSecondaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: kSecondaryColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NGO / Organization',
                                  style: AppTheme.bodyL.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: kTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Receive food donations',
                                  style: AppTheme.bodyS.copyWith(
                                    color: kTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selectedRole == 'NGO')
                            const Icon(
                              Icons.check_circle,
                              color: kPrimaryColor,
                              size: 28,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => setState(() => selectedRole = 'EventManager'),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedRole == 'EventManager'
                              ? kPrimaryColor
                              : Colors.grey.shade300,
                          width: selectedRole == 'EventManager' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        color: selectedRole == 'EventManager'
                            ? kPrimaryColor.withValues(alpha: 0.05)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kAccentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.event_rounded,
                              color: kAccentColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Event Manager / Donor',
                                  style: AppTheme.bodyL.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: kTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Donate surplus food',
                                  style: AppTheme.bodyS.copyWith(
                                    color: kTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selectedRole == 'EventManager')
                            const Icon(
                              Icons.check_circle,
                              color: kPrimaryColor,
                              size: 28,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: kTextSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedRole != null
                      ? () => Navigator.of(context).pop(selectedRole)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAnimatedField(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildPasswordRequirement(bool met, String text) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: met ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTheme.bodyS.copyWith(
            color: met ? Colors.green : kTextSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, color: color, size: 24),
        label: Text(
          text,
          style: AppTheme.bodyM.copyWith(
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4CAF50),
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressController.value,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  );
                },
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SlideInWidget(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.shadowLG,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXL),
                        SlideInWidget(
                          delay: 200,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                              boxShadow: AppTheme.shadowLG,
                            ),
                            padding: const EdgeInsets.all(AppTheme.spacingXL),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Create Account',
                                    style: AppTheme.headingM.copyWith(color: kPrimaryDark),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                  Text(
                                    'Join us in reducing food waste',
                                    style: AppTheme.bodyS,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppTheme.spacingXL),
                                  _buildAnimatedField(
                                    TextFormField(
                                      controller: _nameController,
                                      validator: (value) =>
                                          Validators.validateRequired(value, 'Name'),
                                      decoration: InputDecoration(
                                        labelText: 'Full Name',
                                        prefixIcon: const Icon(Icons.person_outlined),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                    ),
                                    0,
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  _buildAnimatedField(
                                    TextFormField(
                                      controller: _emailController,
                                      validator: Validators.validateEmail,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: const Icon(Icons.email_outlined),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                    ),
                                    1,
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  _buildAnimatedField(
                                    TextFormField(
                                      controller: _phoneController,
                                      validator: Validators.validatePhone,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        labelText: 'Phone Number',
                                        prefixIcon: const Icon(Icons.phone_outlined),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                    ),
                                    2,
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  _buildAnimatedField(
                                    TextFormField(
                                      controller: _addressController,
                                      validator: (value) =>
                                          Validators.validateRequired(value, 'Address'),
                                      maxLines: 2,
                                      decoration: InputDecoration(
                                        labelText: 'Address',
                                        prefixIcon: const Icon(Icons.location_on_outlined),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                    ),
                                    3,
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  _buildAnimatedField(
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                      ),
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedRole,
                                        decoration: const InputDecoration(
                                          labelText: 'Account Type',
                                          prefixIcon: Icon(Icons.account_circle_outlined),
                                          border: InputBorder.none,
                                          filled: false,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'NGO',
                                            child: Text('NGO / Organization'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'EventManager',
                                            child: Text('Event Manager / Donor'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() => _selectedRole = value);
                                          }
                                        },
                                      ),
                                    ),
                                    4,
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  _buildAnimatedField(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: _passwordController,
                                          validator: Validators.validatePassword,
                                          obscureText: _obscurePassword,
                                          decoration: InputDecoration(
                                            labelText: 'Password',
                                            prefixIcon: const Icon(Icons.lock_outlined),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_outlined
                                                    : Icons.visibility_off_outlined,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword = !_obscurePassword;
                                                });
                                              },
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                          ),
                                        ),
                                        if (_passwordController.text.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: LinearProgressIndicator(
                                                        value: _passwordStrength,
                                                        backgroundColor: Colors.grey.shade200,
                                                        valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                                                        minHeight: 6,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    _passwordStrengthText,
                                                    style: AppTheme.bodyS.copyWith(
                                                      color: _passwordStrengthColor,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              _buildPasswordRequirement(_hasMinLength, 'At least 8 characters'),
                                              const SizedBox(height: 4),
                                              _buildPasswordRequirement(_hasUppercase, 'One uppercase letter'),
                                              const SizedBox(height: 4),
                                              _buildPasswordRequirement(_hasNumber, 'One number'),
                                              const SizedBox(height: 4),
                                              _buildPasswordRequirement(_hasSymbol, 'One special character'),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    5,
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  _buildAnimatedField(
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      validator: Validators.validatePassword,
                                      obscureText: _obscureConfirmPassword,
                                      decoration: InputDecoration(
                                        labelText: 'Confirm Password',
                                        prefixIcon: const Icon(Icons.lock_outlined),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword = !_obscureConfirmPassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                    ),
                                    6,
                                  ),
                                  const SizedBox(height: AppTheme.spacingXL),
                                  AnimatedButton(
                                    text: 'Create Account',
                                    onPressed: _register,
                                    isLoading: _isLoading,
                                    icon: Icons.person_add,
                                  ),
                                  const SizedBox(height: AppTheme.spacingXL),
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'OR',
                                          style: AppTheme.bodyS.copyWith(
                                            color: kTextSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingXL),
                                  _buildSocialLoginButton(
                                    'Sign up with Google',
                                    Icons.g_mobiledata,
                                    const Color(0xFFDB4437),
                                    () => _socialRegister('google'),
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Already have an account? ',
                                          style: AppTheme.bodyM.copyWith(color: kTextSecondary),
                                        ),
                                        Text(
                                          'Sign In',
                                          style: AppTheme.bodyM.copyWith(
                                            color: kPrimaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}