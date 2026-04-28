import 'package:flutter/material.dart';

// Primary Colors
const Color kPrimaryColor = Color(0xFF2E7D32);
const Color kPrimaryLight = Color(0xFF4CAF50);
const Color kPrimaryDark = Color(0xFF1B5E20);

// Accent Colors
const Color kAccentColor = Color(0xFFFF6B6B);
const Color kSecondaryColor = Color(0xFF0288D1);

// Background Colors
const Color kBackgroundColor = Color(0xFFF5F5F5);
const Color kCardColor = Colors.white;

// Text Colors
const Color kTextPrimary = Color(0xFF212121);
const Color kTextSecondary = Color(0xFF757575);

// Status Colors
const Color kSuccessColor = Color(0xFF4CAF50);
const Color kWarningColor = Color(0xFFFFA726);
const Color kErrorColor = Color(0xFFEF5350);
const Color kInfoColor = Color(0xFF42A5F5);

// Gradients
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [kPrimaryLight, kPrimaryDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kAccentGradient = LinearGradient(
  colors: [Color(0xFFFF8A80), kAccentColor],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kSecondaryGradient = LinearGradient(
  colors: [Color(0xFF4FC3F7), kSecondaryColor],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);