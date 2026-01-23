import 'package:flutter/material.dart';

class AppColors {
  // Primary Eatzy Orange
  static const Color primary = Color(0xFFFF9800); // Orange utama
  static const Color primaryDark = Color(0xFFF57C00); // Orange lebih gelap
  static const Color primaryLight = Color(0xFFFFE0B2); // Orange soft

  // Background
  static const Color background = Color(0xFFFFF8F0); // Cream lembut
  static const Color surface = Colors.white;

  // Text
  static const Color textDark = Color(0xFF333333);
  static const Color textGrey = Color(0xFF777777);
  static const Color textLight = Colors.white;

  // State
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);

  // Border & Divider
  static const Color border = Color(0xFFE0E0E0);

  // Card Gradients Colors
  // Orange
  static const Color cardOrange1 = Color(0xFFFF9800);
  static const Color cardOrange2 = Color(0xFFF57C00);
  
  // Blue
  static const Color cardBlue1 = Color(0xFF42A5F5);
  static const Color cardBlue2 = Color(0xFF1E88E5);
  
  // Green
  static const Color cardGreen1 = Color(0xFF66BB6A);
  static const Color cardGreen2 = Color(0xFF43A047);
  
  // Purple
  static const Color cardPurple1 = Color(0xFFAB47BC);
  static const Color cardPurple2 = Color(0xFF8E24AA);
  
  // Pink
  static const Color cardPink1 = Color(0xFFEC407A);
  static const Color cardPink2 = Color(0xFFD81B60);
  
  // Teal
  static const Color cardTeal1 = Color(0xFF26A69A);
  static const Color cardTeal2 = Color(0xFF00897B);

  // Gradient Lists for easy access
  static List<List<Color>> get cardGradients => [
    [cardOrange1, cardOrange2], // Orange
    [cardBlue1, cardBlue2],     // Blue
    [cardGreen1, cardGreen2],   // Green
    [cardPurple1, cardPurple2], // Purple
    [cardPink1, cardPink2],     // Pink
    [cardTeal1, cardTeal2],     // Teal
  ];

  // Quick Action Gradients
  static const List<Color> gradientFAQ = [cardOrange1, cardOrange2];
  static const List<Color> gradientAbout = [cardBlue1, cardBlue2];
  static const List<Color> gradientTransaction = [cardPurple1, cardPurple2];
}