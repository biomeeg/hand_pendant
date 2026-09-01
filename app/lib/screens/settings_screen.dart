import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/auth_controller.dart';
import '../ble/ble_manager.dart';
import '../ble/pendant_protocol.dart';
import '../models/pendant_type.dart';
import '../theme/pendant_theme.dart';
import 'control_screen.dart';
import 'scan_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PendantType _pendantType = PendantType.d760;
  bool _loading = true;

  // --- Doi mat khau ket noi ---
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  bool _changingPassword = false;
  String? _passwordResultMessage;

  // --- Doi ten thiet bi (chi admin) ---
  bool _adminUnlocked = false;
  final _adminPasswordController = TextEditingController();
  final _newNameController = TextEditingController();
  bool _changingName = false;
  String? _nameResultMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _adminPasswordController.dispose();
    _newNameController.dispose();
    super.dispose();
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

  Future<void> _submitChangePassword() async {
    final oldPass = _oldPassController.text;
    final newPass = _newPassController.text;
    if (oldPass.isEmpty || newPass.isEmpty) return;
    setState(() {
      _changingPassword = true;
      _passwordResultMessage = null;
    });
    final ok = await PendantAuthController.instance.changePassword(oldPass, newPass);
    if (!mounted) return;
    setState(() {
      _changingPassword = false;
      _passwordResultMessage = ok
          ? 'Da doi mat khau ket noi thanh cong.'
          : 'That bai - kiem tra lai mat khau cu, hoac thiet bi chua ket noi/xac thuc.';
    });
    if (ok) {
      _oldPassController.clear();
      _newPassController.clear();
    }
  }

  void _tryUnlockAdmin() {
    if (_adminPasswordController.text == kAdminUnlockPassword) {
      setState(() {
        _adminUnlocked = true;
        _adminPasswordController.clear();
        _newNameController.text =
            BleManager.instance.connectedDeviceName ?? kPendantDeviceName;
      });
    } else {
      setState(() => _nameResultMessage = 'Sai mat khau admin.');
    }
  }

  Future<void> _submitRename() async {
    var newName = _newNameController.text.trim();
    if (newName.isEmpty) return;
    if (newName.length > kMaxDeviceNameLength) {
      newName = newName.substring(0, kMaxDeviceNameLength);
    }
    setState(() {
      _changingName = true;
      _nameResultMessage = null;
    });
    final ok = await PendantAuthController.instance.renameDevice(newName);
    if (!mounted) return;
    setState(() {
      _changingName = false;
      _nameResultMessage = ok
          ? 'Da gui lenh doi ten. Thiet bi se tu khoi dong lai trong vai giay - '
              'quay lai man hinh quet de ket noi lai voi ten moi.'
          : 'That bai - kiem tra lai ket noi/xac thuc, hoac thu lai.';
    });
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
                _buildChangePasswordSection(connected),
                const Divider(height: 32, color: Colors.white24),
                _buildAdminRenameSection(connected),
                const Divider(height: 32, color: Colors.white24),
                const Text(
                  'Thong so giao thuc (chi de tham khao / go loi)',
                  style: TextStyle(
                      color: PendantColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 8),
                const _InfoRow(label: 'Service UUID', value: kPendantServiceUuid),
                const _InfoRow(label: 'Characteristic UUID', value: kPendantCharacteristicUuid),
                _InfoRow(
                    label: 'Chu ky heartbeat',
                    value: '${kHeartbeatInterval.inMilliseconds} ms'),
                const _InfoRow(label: 'Watchdog o firmware', value: '500 ms (dinh nghia trong .ino)'),
                const Divider(height: 32, color: Colors.white24),
                _buildSetupGuideSection(),
              ],
            ),
    );
  }

  Widget _buildChangePasswordSection(bool connected) {
    final authenticated = PendantAuthController.instance.authenticated.value;
    final canChange = connected && authenticated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bao mat ket noi',
          style: TextStyle(
              color: PendantColors.textLight, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Doi mat khau ma bat ky ai muon dieu khien ban mo qua thiet bi nay deu phai '
          'nhap dung (kiem tra ngay trong firmware ESP32, khong the bo qua tu ben ngoai).',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (!canChange)
          const Text(
            'Can ket noi va xac thuc mat khau hien tai truoc khi doi duoc mat khau moi.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
          )
        else ...[
          TextField(
            controller: _oldPassController,
            obscureText: true,
            style: const TextStyle(color: PendantColors.textLight),
            decoration: const InputDecoration(labelText: 'Mat khau hien tai'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newPassController,
            obscureText: true,
            style: const TextStyle(color: PendantColors.textLight),
            decoration: const InputDecoration(labelText: 'Mat khau moi'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _changingPassword ? null : _submitChangePassword,
            icon: _changingPassword
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.password),
            label: const Text('Doi mat khau ket noi'),
          ),
        ],
        if (_passwordResultMessage != null) ...[
          const SizedBox(height: 6),
          Text(_passwordResultMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildAdminRenameSection(bool connected) {
    final authenticated = PendantAuthController.instance.authenticated.value;
    final canRename = connected && authenticated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Doi ten thiet bi (Admin)',
          style: TextStyle(
              color: PendantColors.textLight, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Chi danh cho ky thuat vien. Ten moi se la ten thiet bi quang ba Bluetooth that '
          'su - bat ky ai quet Bluetooth gan do cung se thay ten nay, nhung van phai nhap '
          'dung mat khau ket noi o tren moi dieu khien duoc.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (!_adminUnlocked) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _adminPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: PendantColors.textLight),
                  decoration: const InputDecoration(labelText: 'Mat khau admin'),
                  onSubmitted: (_) => _tryUnlockAdmin(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _tryUnlockAdmin,
                child: const Text('Mo khoa'),
              ),
            ],
          ),
        ] else if (!canRename) ...[
          const Text(
            'Can ket noi va xac thuc mat khau ket noi truoc khi doi ten duoc.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
          ),
        ] else ...[
          TextField(
            controller: _newNameController,
            maxLength: kMaxDeviceNameLength,
            style: const TextStyle(color: PendantColors.textLight),
            decoration: const InputDecoration(labelText: 'Ten thiet bi moi'),
          ),
          ElevatedButton.icon(
            onPressed: _changingName ? null : _submitRename,
            icon: _changingName
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.edit),
            label: const Text('Luu ten moi'),
          ),
        ],
        if (_nameResultMessage != null) ...[
          const SizedBox(height: 6),
          Text(_nameResultMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (_nameResultMessage!.startsWith('Da gui lenh doi ten'))
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Ve man hinh quet lai'),
            ),
        ],
      ],
    );
  }

  Widget _buildSetupGuideSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Huong dan thiet lap & su dung',
          style: TextStyle(
              color: PendantColors.textLight, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        SizedBox(height: 8),
        Text(
          '1. Lan dau ket noi: quet va chon dung thiet bi ESP32 gan vao tay dieu khien '
          'nguyen ban cua ban mo, sau do nhap mat khau ket noi (mac dinh la '
          '"$kDefaultConnectionPasswordHint" neu chua tung doi).\n'
          '2. Nen doi mat khau ket noi ngay sau lan dau (muc "Bao mat ket noi" o tren) de '
          'tranh nguoi khac vo tinh hoac co y dieu khien nham ban mo.\n'
          '3. Moi lan ket noi lai (mo app lai, hoac Bluetooth vua mat roi noi lai), app se '
          'tu dong xac thuc lai bang mat khau da luu - chi can nhap tay neu doi mat khau '
          'hoac dang ket noi tren dien thoai/thiet bi khac lan dau.\n'
          '4. Nut DUNG KHAN CAP mau do luon hoat dong ngay khi co ket noi, ke ca truoc khi '
          'nhap mat khau.\n'
          '5. Chi 1 nut duoc giu tai 1 thoi diem - giong het tay bam vat ly goc. Neu mat '
          'ket noi Bluetooth giua chung, firmware tu dong dung chuyen dong trong toi da '
          '500ms.\n'
          '6. Cac nut Slide/Kidney cua model D850 dung lai 4 chan tin hieu con trong tren '
          'mach phu tro - PHAI duoc ky thuat vien tu doi chieu voi so do mach that truoc '
          'khi dua vao su dung tren ban mo that.\n'
          '7. Luon kiem thu ky tren ban mo KHONG co benh nhan truoc khi dua vao su dung '
          'thuc te, dung theo dung quy trinh quan ly rui ro thiet bi y te noi bo.',
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
        ),
      ],
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
