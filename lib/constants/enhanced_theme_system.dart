// lib/constants/app_theme.dart (ENHANCED WITH PROFESSIONAL DESIGN)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  // 🎨 ENHANCED COLOR PALETTE
  static const Color primaryGradientStart = Color(0xFF4CAF50);
  static const Color primaryGradientEnd = Color(0xFF2E7D32);
  static const Color secondaryGradientStart = Color(0xFF03A9F4);
  static const Color secondaryGradientEnd = Color(0xFF0288D1);
  static const Color accentGradientStart = Color(0xFFFF7043);
  static const Color accentGradientEnd = Color(0xFFFF5722);
  
  // Background gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGradientStart, primaryGradientEnd],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryGradientStart, secondaryGradientEnd],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentGradientStart, accentGradientEnd],
  );
  
  // Card gradients
  static LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white,
      Colors.grey.shade50,
    ],
  );
  
  // 📐 SPACING SYSTEM
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // 🔲 BORDER RADIUS
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusCircle = 100.0;
  
  // 🎭 SHADOWS
  static List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Colors.black.withValues(alpha:0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Colors.black.withValues(alpha:0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Colors.black.withValues(alpha:0.16),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  // Colored shadows
  static List<BoxShadow> primaryShadow = [
    BoxShadow(
      color: kPrimaryColor.withValues(alpha:0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> accentShadow = [
    BoxShadow(
      color: kAccentColor.withValues(alpha:0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  // 📝 TYPOGRAPHY SYSTEM
  static const TextStyle headingXL = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: kTextPrimary,
    height: 1.2,
  );
  
  static const TextStyle headingL = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: kTextPrimary,
    height: 1.3,
  );
  
  static const TextStyle headingM = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: kTextPrimary,
    height: 1.3,
  );
  
  static const TextStyle headingS = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: kTextPrimary,
    height: 1.4,
  );
  
  static const TextStyle bodyL = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: kTextPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyM = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: kTextPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyS = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: kTextSecondary,
    height: 1.5,
  );
  
  static const TextStyle captionL = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: kTextSecondary,
    height: 1.4,
  );
  
  static const TextStyle captionM = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: kTextSecondary,
    height: 1.4,
  );
  
  static const TextStyle captionS = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: kTextSecondary,
    height: 1.4,
  );
  
  // Button text styles
  static const TextStyle buttonL = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonM = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonS = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  // 🎨 MAIN THEME
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: kPrimaryColor,
      scaffoldBackgroundColor: kBackgroundColor,
      colorScheme: const ColorScheme.light(
        primary: kPrimaryColor,
        secondary: kSecondaryColor,
        error: kAccentColor,
        surface: kCardColor,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha:0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        color: kCardColor,
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: buttonM,
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: kPrimaryColor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: buttonM,
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: buttonM,
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: kAccentColor, width: 2),
        ),
        labelStyle: bodyM.copyWith(color: kTextSecondary),
        hintStyle: bodyM.copyWith(color: kTextSecondary.withValues(alpha:0.6)),
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: kSecondaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: kPrimaryLight.withValues(alpha:0.1),
        labelStyle: captionM.copyWith(color: kPrimaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCircle),
        ),
      ),
      
      // Divider Theme
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade300,
        thickness: 1,
        space: spacingL,
      ),
      
      // Dialog Theme
      dialogTheme: DialogThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        backgroundColor: kCardColor,
      ),
      
      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
        backgroundColor: kCardColor,
      ),
      
      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kTextPrimary,
        contentTextStyle: bodyM.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // ⏱️ ANIMATION DURATIONS
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // 📊 CURVES
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEmphasized = Curves.easeOutCubic;
  static const Curve curveDecelerate = Curves.easeOut;
  static const Curve curveAccelerate = Curves.easeIn;
  static const Curve curveElastic = Curves.elasticOut;
}

// 🎯 Helper Extensions
extension ThemeExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
