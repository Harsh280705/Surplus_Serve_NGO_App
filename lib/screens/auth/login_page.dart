// lib/screens/auth/login_page.dart (FULLY FIXED VERSION)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/validators.dart';
import '../../widgets/animated_widgets.dart';
import '../auth/register_page.dart';
import '../auth/forgot_password_page.dart';
import '../profile/profile_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberDevice = false;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
    _loadRememberedDevice();
  }

  Future<void> _loadRememberedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedEmail = prefs.getString('remembered_email');
    if (rememberedEmail != null) {
      setState(() {
        _emailController.text = rememberedEmail;
        _rememberDevice = true;
      });
    }
  }

  Future<void> _saveDevicePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberDevice) {
      await prefs.setString('remembered_email', _emailController.text.trim());
      await prefs.setBool('remember_device', true);
    } else {
      await prefs.remove('remembered_email');
      await prefs.setBool('remember_device', false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // Check if user profile is complete
Future<bool> _isProfileComplete(String userId) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!userDoc.exists) return false;
    
    final data = userDoc.data()!;
    
    // Check required fields
    final hasName = data['name'] != null && (data['name'] as String).isNotEmpty;
    final hasEmail = data['email'] != null && (data['email'] as String).isNotEmpty;
    final hasPhone = data['phone'] != null && (data['phone'] as String).isNotEmpty;
    final hasAddress = data['address'] != null && (data['address'] as String).isNotEmpty;
    final hasRole = data['role'] != null && (data['role'] as String).isNotEmpty;
    
    // ⚠️ alternatePhone is OPTIONAL - don't check it for completion
    
    // For NGO users, also check for NGO name
    if (data['role'] == 'NGO') {
      final hasNgoName = data['ngoName'] != null && (data['ngoName'] as String).isNotEmpty;
      return hasName && hasEmail && hasPhone && hasAddress && hasRole && hasNgoName;
    }
    
    return hasName && hasEmail && hasPhone && hasAddress && hasRole;
  } catch (e) {
    print('Error checking profile completion: $e');
    return false;
  }
}

  // Navigate user based on profile completion
  Future<void> _navigateAfterLogin(String userId) async {
    final isComplete = await _isProfileComplete(userId);
    
    if (mounted) {
      if (isComplete) {
        // Profile is complete, go to home/dashboard
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Profile is incomplete, go to profile setup
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        final role = userDoc.data()?['role'];
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileSetupPage(
              userId: userId,
              role: role,
            ),
          ),
        );
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward().then((_) => _shakeController.reverse());
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final userCredential = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      await _saveDevicePreference();
      
      // Check profile completion and navigate accordingly
      await _navigateAfterLogin(userCredential.user!.uid);
      
    } catch (e) {
      if (mounted) {
        _shakeController.forward().then((_) => _shakeController.reverse());
        
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

  Future<void> _socialLogin(String provider) async {
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
        
        // Check if user profile exists in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        // New user - doesn't exist in Firestore
        if (!userDoc.exists) {
          if (mounted) {
            final selectedRole = await _showRoleSelectionDialog();
            
            if (selectedRole == null) {
              // User cancelled, sign them out
              await _authService.signOut();
              setState(() => _isLoading = false);
              return;
            }
            
            // Create basic user profile with selected role
            final firestoreService = FirestoreService();
            
            try {
              await firestoreService.createUserProfile(userId, {
                'name': userCredential.user!.displayName ?? 'Google User',
                'email': userCredential.user!.email ?? '',
                'phone': '', // Empty - will be filled in profile setup
                'address': '', // Empty - will be filled in profile setup
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
                
                // Navigate to profile setup page
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
            } catch (e) {
              // If profile creation fails, sign out the user
              await _authService.signOut();
              throw Exception('Failed to create profile: $e');
            }
          }
        } else {
          // Existing user - check if profile is complete
          final isComplete = await _isProfileComplete(userId);
          
          if (mounted) {
            if (isComplete) {
              // Profile complete, go to dashboard
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Logged in with $provider successfully!')),
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
            } else {
              // Profile incomplete, go to profile setup
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Please complete your profile to continue.')),
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
              
              final role = userDoc.data()?['role'];
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileSetupPage(
                    userId: userId,
                    role: role,
                  ),
                ),
              );
            }
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
    return showDialog<String>(
      context: context,
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
                      color: kPrimaryColor.withValues(alpha:0.1),
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
                  
                  // NGO Option
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
                            ? kPrimaryColor.withValues(alpha:0.05)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kSecondaryColor.withValues(alpha:0.1),
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
                  
                  // Event Manager Option
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
                            ? kPrimaryColor.withValues(alpha:0.05)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kAccentColor.withValues(alpha:0.1),
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
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SlideInWidget(
                    delay: 0,
                    child: ScaleAnimation(
                      child: Container(
                        width: 120,
                        height: 120,
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
                  ),
                  
                  const SizedBox(height: AppTheme.spacingXL),
                  
                  FadeInWidget(
                    delay: 200,
                    child: const Text(
                      'SurplusServe',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingS),
                  
                  FadeInWidget(
                    delay: 300,
                    child: Text(
                      'Fighting Food Waste, Together',
                      style: AppTheme.bodyM.copyWith(
                        color: Colors.white.withValues(alpha:0.9),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingXXL),
                  
                  SlideInWidget(
                    delay: 400,
                    child: AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
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
                                'Welcome Back!',
                                style: AppTheme.headingM.copyWith(
                                  color: kPrimaryDark,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: AppTheme.spacingS),
                              
                              Text(
                                'Sign in to continue',
                                style: AppTheme.bodyS,
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: AppTheme.spacingXL),
                              
                              TweenAnimationBuilder<double>(
                                duration: AppTheme.animationNormal,
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
                                child: TextFormField(
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
                              ),
                              
                              const SizedBox(height: AppTheme.spacingM),
                              
                              TweenAnimationBuilder<double>(
                                duration: AppTheme.animationNormal,
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
                                child: TextFormField(
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
                              ),
                              
                              const SizedBox(height: AppTheme.spacingM),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _rememberDevice,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberDevice = value ?? false;
                                            });
                                          },
                                          activeColor: kPrimaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Remember me',
                                        style: AppTheme.bodyS.copyWith(
                                          color: kTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ForgotPasswordPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: AppTheme.bodyS.copyWith(
                                        color: kPrimaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: AppTheme.spacingXL),
                              
                              AnimatedButton(
                                text: 'Sign In',
                                onPressed: _login,
                                isLoading: _isLoading,
                                icon: Icons.login,
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
                                'Continue with Google',
                                Icons.g_mobiledata,
                                const Color(0xFFDB4437),
                                () => _socialLogin('google'),
                              ),
                              
                              const SizedBox(height: AppTheme.spacingM),
                              
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          const RegisterPage(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;
                                        
                                        var tween = Tween(begin: begin, end: end)
                                            .chain(CurveTween(curve: curve));
                                        var offsetAnimation = animation.drive(tween);
                                        
                                        return SlideTransition(
                                          position: offsetAnimation,
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: AppTheme.bodyM.copyWith(color: kTextSecondary),
                                    ),
                                    Text(
                                      'Sign Up',
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
                  ),
                  
                  const SizedBox(height: AppTheme.spacingXL),
                  
                  FadeInWidget(
                    delay: 600,
                    child: Text(
                      '© 2025 SurplusServe • Reduce Food Waste',
                      style: AppTheme.captionM.copyWith(
                        color: Colors.white.withValues(alpha:0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
  }