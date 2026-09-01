import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/ble_manager.dart';
import '../ble/pendant_protocol.dart';
import '../models/pendant_type.dart';
import '../theme/pendant_theme.dart';
import 'control_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PendantType _pendantType = PendantType.d760;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kPrefPendantType);
    setState(() {
      _pendantType = PendantTypeX.fromStorage(stored);
      _loading = false;
    });
  }

  Future<void> _setPendantType(PendantType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefPendantType, type.storageValue);
    setState(() => _pendantType = type);
  }

  @override
  Widget build(BuildContext context) {
    final connected = BleManager.instance.isConnected;
    return Scaffold(
      appBar: AppBar(title: const Text('Cai dat')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Loai tay dieu khien (bo cuc phim)',
                  style: TextStyle(
                      color: PendantColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 8),
                RadioListTile<PendantType>(
                  title: Text(PendantType.d760.label,
                      style: const TextStyle(color: PendantColors.textLight)),
                  subtitle: const Text('Co hang InstaDrive REV/FWD',
                      style: TextStyle(color: Colors.white54)),
                  value: PendantType.d760,
                  groupValue: _pendantType,
                  onChanged: (v) => _setPendantType(v!),
                ),
                RadioListTile<PendantType>(
                  title: Text(PendantType.d850.label,
                      style: const TextStyle(color: PendantColors.textLight)),
                  subtitle: const Text('Co hang Slide (Head/Foot) va Kidney (Up/Down)',
                      style: TextStyle(color: Colors.white54)),
                  value: PendantType.d850,
                  groupValue: _pendantType,
                  onChanged: (v) => _setPendantType(v!),
                ),
                const Divider(height: 32, color: Colors.white24),
                const Text(
                  'Ket noi hien tai',
                  style: TextStyle(
                      color: PendantColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(
                    connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: connected ? Colors.greenAccent : Colors.white38,
                  ),
                  title: Text(
                    connected
                        ? (BleManager.instance.connectedDeviceName ?? 'Thiet bi ESP32')
                        : 'Chua ket noi',
                    style: const TextStyle(color: PendantColors.textLight),
                  ),
                  subtitle: connected
                      ? Text(BleManager.instance.connectedDeviceId ?? '',
                          style: const TextStyle(color: Colors.white54))
                      : null,
                ),
                if (connected)
                  TextButton.icon(
                    onPressed: () async {
                      await BleManager.instance.disconnect();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text('Ngat ket noi'),
                  ),
                const Divider(height: 32, color: Colors.white24),
                const Text(
                  'Thong so giao thuc (chi de tham khao / go loi)',
                  style: TextStyle(
                      color: PendantColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 8),
                const _InfoRow(label: 'Ten thiet bi BLE', value: kPendantDeviceName),
                const _InfoRow(label: 'Service UUID', value: kPendantServiceUuid),
                const _InfoRow(label: 'Characteristic UUID', value: kPendantCharacteristicUuid),
                _InfoRow(
                    label: 'Chu ky heartbeat',
                    value: '${kHeartbeatInterval.inMilliseconds} ms'),
                const _InfoRow(label: 'Watchdog o firmware', value: '500 ms (dinh nghia trong .ino)'),
                const Divider(height: 32, color: Colors.white24),
                const Text(
                  'Luu y an toan',
                  style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 8),
                const Text(
                  '- Cac nut Slide/Kidney cua model D850 dung lai 4 bit RESERVE con trong '
                  'trong ban do bit goc. Ban PHAI tu doi chieu voi so do mach phu tro thuc '
                  'te truoc khi su dung tren ban mo that.\n'
                  '- Neu Bluetooth mat ket noi trong luc dang giu 1 nut, firmware se tu mo '
                  'relay sau toi da 500ms (watchdog) hoac ngay lap tuc khi phat hien disconnect.\n'
                  '- Nen kiem thu ky tren ban mo KHONG co benh nhan truoc khi dua vao su dung '
                  'thuc te, dung theo dung quy trinh quan ly rui ro thiet bi y te noi bo.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: PendantColors.textLight,
                    fontSize: 12,
                    fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
