import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // الهوية اللونية المونوكروم: أبيض، رمادي، أسود + درجة داكنة إضافية
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF808080);
  static const Color darkSurface = Color(0xFF292d31); // الدرجة الداكنة الإضافية

  // أسماء بديلة للتوافق
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color pureBlack = Color(0xFF000000);

  // تدرجات رمادية للأسطح والحدود
  static const Color darkGrey = Color(0xFF1A1A1A);
  static const Color mediumGrey = Color(0xFF8E8E93);
  static const Color lightGrey = Color(0xFFF2F2F7);

  static const Color primary = black; // الأساسي في الثيم الفاتح

  // تدرّج محايد للشارات والأيقونات (يشتغل على الوضعين)
  static const LinearGradient neutralGradient = LinearGradient(
    colors: [Color(0xFF9E9E9E), Color(0xFF5A5A5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.pureBlack,
      colorScheme: const ColorScheme.light(
        primary: AppColors.pureBlack,
        secondary: AppColors.pureBlack,
        surface: AppColors.pureWhite,
        onPrimary: AppColors.pureWhite,
        onSurface: AppColors.pureBlack,
      ),
      scaffoldBackgroundColor: AppColors.white,
      textTheme: GoogleFonts.cairoTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pureBlack,
          foregroundColor: AppColors.pureWhite,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.pureWhite,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.pureWhite,
        secondary: AppColors.pureWhite,
        surface: AppColors.darkSurface,
        onPrimary: AppColors.pureBlack,
        onSurface: AppColors.pureWhite,
      ),
      scaffoldBackgroundColor: AppColors.darkSurface,
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pureWhite,
          foregroundColor: AppColors.pureBlack,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
      ),
    );
  }
}
