// estilo principal do app, cores, design, fonte...

import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryOrange = Color(0xFFFF7F50); 
  static const Color backgroundWhite = Color(0xFFF8F9FA); 
  static const Color textDark = Color(0xFF333333);
  static const Color textGray = Color(0xFF8E8E93);
  static const Color pureWhite = Colors.white;

  static ThemeData get theme {
    return ThemeData(
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: backgroundWhite,
      fontFamily: 'Roboto', 
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryOrange),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: pureWhite,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureWhite,
        hintStyle: const TextStyle(color: textGray),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
      ),
    );
  }
}