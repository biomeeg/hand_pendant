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

  // --- Mau nut dang "vien thuoc" (pill), tham khao theo anh giao dien mau nguoi dung
  // gui - moi mau ung voi 1 nhom chuc nang, khong con phu thuoc icon nhu truoc. ---
  static const Color pillBlue = Color(0xFF6C82D6); // nut dieu khien thong thuong
  static const Color pillOlive = Color(0xFF56701F); // nut UP/DOWN (BACK/TABLE/LEG)
  static const Color pillRed = Color(0xFFCC2B33); // POWER, TREND
  static const Color pillGreen = Color(0xFF63B62E); // LEVEL

  /// Mau nen phu (tint) danh rieng cho nhom 4 nut LIEN QUAN nhau: LEG UP, LEG DOWN,
  /// SPLIT LEG LEFT, SPLIT LEG RIGHT. 2 nut SPLIT LEG chi co tac dung khi bam DONG THOI
  /// voi LEG UP/DOWN (xem PendantInputCoordinator) - phu 1 mang mau teal nay quanh ca 2
  /// cum nut (cot LEG trong bang BACK/TABLE/LEG, va hang SPLIT LEG rieng ben duoi) de
  /// nguoi dung nhan ra chung cung 1 nhom chuc nang, du khong nam sat nhau tren man hinh.
  static const Color linkedGroupTint = Color(0xFF2F8F8F);
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
