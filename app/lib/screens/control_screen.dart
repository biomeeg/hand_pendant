import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/auth_controller.dart';
import '../ble/ble_manager.dart';
import '../ble/hold_command_controller.dart';
import '../ble/pendant_protocol.dart';
import '../models/pendant_type.dart';
import '../theme/pendant_theme.dart';
import '../widgets/hold_button.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

const String kPrefPendantType = 'pendant_type';

/// Man hinh dieu khien chinh, bo cuc dang nut "vien thuoc" (pill) mau theo chuc nang -
/// tham khao theo mau giao dien app tuong tu nguoi dung cung cap - thay doi theo
/// PendantType: D760 co hang InstaDrive, D850 co hang Slide + Kidney.
///
/// Cac nut CHI mo khoa khi vua co ket noi BLE ("connected") VA da xac thuc dung mat
/// khau ("authenticated" - xem PendantAuthController). Rieng nut DUNG KHAN CAP luon
/// hoat dong khi co ket noi, ke ca truoc khi xac thuc, vi lenh bt_Stop luon duoc
/// firmware chap nhan (chi mo relay, khong bao gio nguy hiem).
///
/// SPLIT LEG: tren tay bam THAT chi co 2 nut vat ly LEFT/RIGHT - de nang/ha 1 ben chan
/// phai bam DONG THOI voi nut LEG UP/DOWN (o cot LEG trong bang BACK/TABLE/LEG). Vi vay
/// 2 nut LEFT/RIGHT o day la "nut chon ben", chi thuc su tao chuyen dong khi giu chung
/// voi LEG UP/DOWN - xem PendantInputCoordinator (hold_command_controller.dart) de biet
/// logic ket hop 2 nut. De the hien 4 nut LEG UP, LEG DOWN, SPLIT LEFT, SPLIT RIGHT lien
/// quan chuc nang voi nhau, ca cot LEG va hang SPLIT LEG duoc phu chung 1 mau nen teal
/// (PendantColors.linkedGroupTint).
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  PendantType _pendantType = PendantType.d760;
  final TextEditingController _passwordFieldController = TextEditingController();
  bool _submittingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadPendantType();
  }

  @override
  void dispose() {
    _passwordFieldController.dispose();
    super.dispose();
  }

  Future<void> _loadPendantType() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kPrefPendantType);
    if (!mounted) return;
    setState(() {
      _pendantType = PendantTypeX.fromStorage(stored);
    });
  }

  Future<void> _disconnect() async {
    await BleManager.instance.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
  }

  Future<void> _submitPassword() async {
    final pwd = _passwordFieldController.text;
    if (pwd.isEmpty) return;
    setState(() => _submittingPassword = true);
    await PendantAuthController.instance.authenticate(pwd);
    if (!mounted) return;
    setState(() => _submittingPassword = false);
    _passwordFieldController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PendantLinkState>(
      stream: BleManager.instance.linkState,
      initialData: BleManager.instance.lastState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? PendantLinkState.disconnected;
        final connected = state == PendantLinkState.connected;

        return ValueListenableBuilder<bool>(
          valueListenable: PendantAuthController.instance.authenticated,
          builder: (context, authenticated, __) {
            final unlocked = connected && authenticated;

            return Scaffold(
              appBar: AppBar(
                title: Text('Ban mo ${_pendantType == PendantType.d760 ? "D760" : "D850"}'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                      _loadPendantType();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.bluetooth_disabled),
                    tooltip: 'Ngat ket noi',
                    onPressed: _disconnect,
                  ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    _ConnectionBanner(state: state, authenticated: authenticated),
                    if (connected && !authenticated)
                      _passwordGate()
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                          child: Column(
                            children: [
                              _topRow(unlocked),
                              const SizedBox(height: 4),
                              if (_pendantType == PendantType.d760) ...[
                                _instaDriveRow(unlocked),
                                const SizedBox(height: 4),
                              ],
                              _backTableLegSection(unlocked),
                              const SizedBox(height: 4),
                              _splitLegRow(unlocked),
                              const SizedBox(height: 4),
                              _trendRow(unlocked),
                              const SizedBox(height: 4),
                              if (_pendantType == PendantType.d850) ...[
                                _slideRow(unlocked),
                                const SizedBox(height: 4),
                              ],
                              _tiltRow(unlocked),
                              const SizedBox(height: 4),
                              if (_pendantType == PendantType.d850) ...[
                                _kidneyRow(unlocked),
                                const SizedBox(height: 4),
                              ],
                              _presetRow(unlocked),
                              const SizedBox(height: 4),
                              SizedBox(width: double.infinity, child: _levelButton(unlocked)),
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: PendantColors.serviceRed,
                icon: const Icon(Icons.stop_circle, color: Colors.white),
                label: const Text('DUNG KHAN CAP', style: TextStyle(color: Colors.white)),
                // Luon cho phep dung khan cap khi co ket noi, ke ca truoc khi xac thuc.
                onPressed: connected
                    ? () => PendantInputCoordinator.instance.emergencyStop()
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------------------------
  // Man hinh khoa cho den khi xac thuc dung mat khau
  // ----------------------------------------------------------------------

  Widget _passwordGate() {
    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Nhap mat khau ket noi de dieu khien ban mo',
                textAlign: TextAlign.center,
                style: TextStyle(color: PendantColors.textLight, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Mat khau mac dinh khi chua tung doi la "$kDefaultConnectionPasswordHint" '
                '(nen doi ngay trong Cai dat sau khi ket noi lan dau).',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _passwordFieldController,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: PendantColors.textLight),
                  decoration: const InputDecoration(
                    labelText: 'Mat khau ket noi',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitPassword(),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: PendantAuthController.instance.lastAuthFailed,
                builder: (context, failed, __) => failed
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Sai mat khau, vui long thu lai.',
                            style: TextStyle(color: Colors.orangeAccent)),
                      )
                    : const SizedBox.shrink(),
              ),
              ElevatedButton.icon(
                onPressed: _submittingPassword ? null : _submitPassword,
                icon: _submittingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open),
                label: const Text('Xac thuc'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // Cac khoi giao dien con
  // ----------------------------------------------------------------------

  /// Hop bao quanh 1 nhom nut co PHU MAU NEN TEAL de bao hieu "cac nut nay lien quan
  /// chuc nang voi nhau" (dung cho cot LEG va hang SPLIT LEG - xem chu thich dau file).
  Widget _linkedGroupBox(Widget child) => Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: PendantColors.linkedGroupTint.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PendantColors.linkedGroupTint.withOpacity(0.6)),
        ),
        child: child,
      );

  /// Hop trong suot cung kich thuoc/padding voi [_linkedGroupBox], dung cho cac cot
  /// KHONG lien quan (BACK, TABLE) de giu thang hang voi cot LEG co vien mau.
  Widget _plainGroupBox(Widget child) => Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent),
        ),
        child: child,
      );

  /// 1 hang gom: nut trai - nhan ten nhom o giua - nut phai, chia deu 3 phan bang nhau
  /// (tham khao theo mau giao dien: INSTADRIVE, TREND, SLIDE, TILT, KIDNEY, PRESET).
  Widget _pairRow(Widget left, String label, Widget right) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: left),
          Expanded(
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(child: right),
        ],
      );

  Widget _topRow(bool unlocked) => Row(
        children: [
          Expanded(
            child: HoldButton(
              commandId: 'bt_Power',
              label: 'POWER ON/OFF',
              color: PendantColors.pillRed,
              connected: unlocked,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: HoldButton(
              commandId: 'bt_FloorLock',
              label: 'FLOOR LOCK',
              connected: unlocked,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: HoldButton(
              commandId: 'bt_RevPosition',
              label: 'REV POSITION',
              connected: unlocked,
            ),
          ),
        ],
      );

  Widget _instaDriveRow(bool unlocked) => _pairRow(
        HoldButton(commandId: 'bt_InstaDriveREV', label: 'REV', connected: unlocked),
        'INSTADRIVE',
        HoldButton(commandId: 'bt_InstaDriveFWD', label: 'FWD', connected: unlocked),
      );

  Widget _backTableLegSection(bool unlocked) {
    Widget upDownColumn(String upId, String downId, String title) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HoldButton(
              commandId: upId,
              label: 'UP',
              color: PendantColors.pillOlive,
              connected: unlocked,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PendantColors.pillRed,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            HoldButton(
              commandId: downId,
              label: 'DOWN',
              color: PendantColors.pillOlive,
              connected: unlocked,
            ),
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _plainGroupBox(upDownColumn('bt_BackUp', 'bt_BackDown', 'BACK')),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _plainGroupBox(upDownColumn('bt_TableUp', 'bt_TableDown', 'TABLE')),
        ),
        const SizedBox(width: 4),
        // Cot LEG duoc phu mau teal - lien quan chuc nang voi hang SPLIT LEG ben duoi
        // (giu/nha dong thoi voi 1 trong 2 nut LEFT/RIGHT cua SPLIT LEG).
        Expanded(
          child: _linkedGroupBox(upDownColumn('bt_LegUp', 'bt_LegDown', 'LEG')),
        ),
      ],
    );
  }

  /// Tren tay bam THAT chi co 2 nut LEFT/RIGHT (khong phai 4 nut rieng nhu truoc). Giu
  /// LEFT (hoac RIGHT) DONG THOI voi LEG UP/DOWN o tren se tao chuyen dong nang/ha 1 ben
  /// chan - xem PendantInputCoordinator. Phu cung mau teal voi cot LEG de the hien 4 nut
  /// nay (LEG UP, LEG DOWN, SPLIT LEFT, SPLIT RIGHT) lien quan chuc nang voi nhau.
  Widget _splitLegRow(bool unlocked) => _linkedGroupBox(
        _pairRow(
          HoldButton(commandId: kSplitSelectorLeft, label: 'LEFT', connected: unlocked),
          'SPLIT LEG',
          HoldButton(commandId: kSplitSelectorRight, label: 'RIGHT', connected: unlocked),
        ),
      );

  Widget _trendRow(bool unlocked) => _pairRow(
        HoldButton(
          commandId: 'bt_TrendTrend',
          label: 'TREND',
          color: PendantColors.pillRed,
          connected: unlocked,
        ),
        'TREND',
        HoldButton(commandId: 'bt_TrendRev', label: 'REV', connected: unlocked),
      );

  Widget _slideRow(bool unlocked) => _pairRow(
        HoldButton(commandId: 'bt_SlideHead', label: 'HEAD', connected: unlocked),
        'SLIDE',
        HoldButton(commandId: 'bt_SlideFoot', label: 'FOOT', connected: unlocked),
      );

  Widget _tiltRow(bool unlocked) => _pairRow(
        HoldButton(commandId: 'bt_TiltLeft', label: 'LEFT', connected: unlocked),
        'TILT',
        HoldButton(commandId: 'bt_TiltRight', label: 'RIGHT', connected: unlocked),
      );

  Widget _kidneyRow(bool unlocked) => _pairRow(
        HoldButton(commandId: 'bt_KidneyUp', label: 'UP', connected: unlocked),
        'KIDNEY',
        HoldButton(commandId: 'bt_KidneyDown', label: 'DOWN', connected: unlocked),
      );

  Widget _presetRow(bool unlocked) => _pairRow(
        HoldButton(commandId: 'bt_PresetFlex', label: 'FLEX', connected: unlocked),
        'PRESET',
        HoldButton(commandId: 'bt_PresetChair', label: 'CHAIR', connected: unlocked),
      );

  Widget _levelButton(bool unlocked) => HoldButton(
        commandId: 'bt_Level',
        label: 'LEVEL',
        color: PendantColors.pillGreen,
        connected: unlocked,
      );
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state, required this.authenticated});
  final PendantLinkState state;
  final bool authenticated;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String text;
    switch (state) {
      case PendantLinkState.connected:
        if (authenticated) {
          color = Colors.green.shade700;
          text = 'Da ket noi: ${BleManager.instance.connectedDeviceName ?? "ESP32"}';
        } else {
          color = Colors.orange.shade800;
          text = 'Da ket noi: ${BleManager.instance.connectedDeviceName ?? "ESP32"} '
              '- can xac thuc mat khau';
        }
        break;
      case PendantLinkState.connecting:
      case PendantLinkState.scanning:
        color = Colors.orange.shade800;
        text = 'Dang ket noi...';
        break;
      case PendantLinkState.error:
        color = Colors.red.shade800;
        text = 'Loi ket noi - cac nut da bi khoa';
        break;
      case PendantLinkState.disconnected:
        color = Colors.red.shade800;
        text = 'Mat ket noi Bluetooth - cac nut da bi khoa';
        break;
    }
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
