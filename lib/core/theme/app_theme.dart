import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.orbBlue,
      secondary: AppColors.orbPurple,
      surface: AppColors.surface,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        height: 1.6,
      ),
      bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      labelSmall: TextStyle(
        color: AppColors.textHint,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    ),
  );

  static void setSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
}
