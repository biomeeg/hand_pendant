import 'package:flutter/material.dart';

/// Bang mau lay theo anh chup tay dieu khien Berchtold that (xanh navy dam + panel xam).
class PendantColors {
  PendantColors._();

  static const Color navyCase = Color(0xFF1E2A52); // vo ngoai xanh navy
  static const Color navyCaseDark = Color(0xFF141C3A);
  static const Color panelGray = Color(0xFF6E7480); // nen panel xam giua
  static const Color buttonFace = Color(0xFFEDEDED); // nut bam mau trang nga
  static const Color buttonFacePressed = Color(0xFFBFD4FF);
  static const Color trendRed = Color(0xFFC0242C);
  static const Color warningYellow = Color(0xFFF2C230);
  static const Color serviceRed = Color(0xFFD1394A);
  static const Color textLight = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF20242C);
  static const Color disabledOverlay = Color(0x66000000);
}

ThemeData buildPendantAppTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: PendantColors.navyCaseDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PendantColors.navyCase,
      brightness: Brightness.dark,
    ),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: PendantColors.navyCase,
      foregroundColor: PendantColors.textLight,
      centerTitle: true,
    ),
  );
}
