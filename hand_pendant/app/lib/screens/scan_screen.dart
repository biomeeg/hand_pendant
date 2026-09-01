import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ble/ble_manager.dart';
import '../ble/pendant_protocol.dart';
import '../theme/pendant_theme.dart';
import 'control_screen.dart';
import 'settings_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  final List<ScanResult> _results = [];
  bool _scanning = false;
  bool _connecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scanSub?.cancel();
    BleManager.instance.stopScan();
    super.dispose();
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? true;
    final connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
    // locationWhenInUse chi thuc su bat buoc tren Android < 12; tren cac nen tang khac
    // permission_handler co the tra ve mot trang thai khong lien quan, nen khong ep buoc.
    return scanOk && connectOk;
  }

  Future<void> _startScan() async {
    setState(() {
      _errorMessage = null;
      _results.clear();
    });

    final granted = await _ensurePermissions();
    if (!granted) {
      setState(() {
        _errorMessage = 'Ung dung can quyen Bluetooth de tim thiet bi. '
            'Vui long cap quyen trong Cai dat cua dien thoai.';
      });
      return;
    }

    setState(() => _scanning = true);
    _scanSub?.cancel();
    _scanSub = BleManager.instance.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(results);
      });
    });

    try {
      await BleManager.instance.startScan();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Khong the bat dau quet: $e');
    }

    // startScan() se tu dung sau khoang thoi gian timeout da khai bao trong BleManager.
    await Future.delayed(const Duration(seconds: 12));
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connect(ScanResult result) async {
    setState(() => _connecting = true);
    try {
      await BleManager.instance.connect(result.device);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Ket noi that bai: $e';
      });
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  String _displayName(ScanResult r) {
    final name = r.device.platformName;
    if (name.isNotEmpty) return name;
    final advName = r.advertisementData.advName;
    if (advName.isNotEmpty) return advName;
    return '(Khong ro ten)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ket noi bo dieu khien ban mo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Tim thiet bi "$kPendantDeviceName" (bo trung gian ESP32 gan vao jack '
              'tay dieu khien nguyen ban cua ban mo).',
              style: const TextStyle(color: PendantColors.textLight),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_scanning ? 'Dang quet...' : 'Bat dau quet'),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _scanning
                          ? 'Dang tim kiem...'
                          : 'Chua co thiet bi nao. Nhan "Bat dau quet".',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      return ListTile(
                        leading: const Icon(Icons.memory, color: Colors.white70),
                        title: Text(
                          _displayName(r),
                          style: const TextStyle(color: PendantColors.textLight),
                        ),
                        subtitle: Text(
                          '${r.device.remoteId.str}  ·  RSSI ${r.rssi}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: _connecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right, color: Colors.white54),
                        onTap: _connecting ? null : () => _connect(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
