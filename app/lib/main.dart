import 'package:flutter/material.dart';

import 'screens/scan_screen.dart';
import 'theme/pendant_theme.dart';

void main() {
  runApp(const HandPendantApp());
}

class HandPendantApp extends StatelessWidget {
  const HandPendantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bo dieu khien ban mo (khong day)',
      debugShowCheckedModeBanner: false,
      theme: buildPendantAppTheme(),
      home: const ScanScreen(),
    );
  }
}
