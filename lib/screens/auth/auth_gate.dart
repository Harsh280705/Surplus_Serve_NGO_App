// lib/screens/auth/auth_gate.dart (FIXED VERSION)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../dashboard/dashboard_page.dart';
import '../profile/profile_setup_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  
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
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.hasData) {
          // User is authenticated - check profile
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Setting up your account...', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                );
              }
              
              if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
                // Profile exists - get data for role (but pass UID to _isProfileComplete)
                final data = profileSnapshot.data!.data() as Map<String, dynamic>;
                
                return FutureBuilder<bool>(
                  // ✅ PASS USER ID (string), not data (map)
                  future: _isProfileComplete(snapshot.data!.uid),
                  builder: (context, completeSnapshot) {
                    if (completeSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    
                    if (completeSnapshot.data == true) {
                      // Profile is complete → go to dashboard
                      return const DashboardPage();
                    } else {
                      // Profile is incomplete → go to profile setup
                      return ProfileSetupPage(
                        userId: snapshot.data!.uid,
                        role: data['role'],
                      );
                    }
                  },
                );
              } else {
                // Profile doesn't exist at all → go to profile setup
                return ProfileSetupPage(
                  userId: snapshot.data!.uid,
                  role: null, // Role will be selected in setup
                );
              }
            },
          );
        }
        
        // No authenticated user → show login page
        return const LoginPage();
      },
    );
  }
}