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

/// Man hinh dieu khien chinh, bo cuc phong theo tay bam vat ly that (thay doi theo
/// PendantType: D760 co hang InstaDrive, D850 co hang Slide + Kidney).
///
/// Cac nut CHI mo khoa khi vua co ket noi BLE ("connected") VA da xac thuc dung mat
/// khau ("authenticated" - xem PendantAuthController). Rieng nut DUNG KHAN CAP luon
/// hoat dong khi co ket noi, ke ca truoc khi xac thuc, vi lenh bt_Stop luon duoc
/// firmware chap nhan (chi mo relay, khong bao gio nguy hiem).
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
                              const SizedBox(height: 3),
                              if (_pendantType == PendantType.d760) ...[
                                _labeledSectionRow('INSTADRIVE', _instaDriveRow(unlocked)),
                                const SizedBox(height: 3),
                              ],
                              _backTableLegSection(unlocked),
                              const SizedBox(height: 3),
                              _labeledSectionRow('SPLIT LEG', _splitLegRow(unlocked)),
                              const SizedBox(height: 3),
                              _labeledSectionRow('TREND', _trendRow(unlocked)),
                              const SizedBox(height: 3),
                              if (_pendantType == PendantType.d850) ...[
                                _labeledSectionRow('SLIDE', _slideRow(unlocked)),
                                const SizedBox(height: 3),
                              ],
                              _labeledSectionRow('TILT', _tiltRow(unlocked)),
                              const SizedBox(height: 3),
                              if (_pendantType == PendantType.d850) ...[
                                _labeledSectionRow('KIDNEY', _kidneyRow(unlocked)),
                                const SizedBox(height: 3),
                              ],
                              _labeledSectionRow('PRESET', _presetRow(unlocked)),
                              const SizedBox(height: 3),
                              _levelButton(unlocked),
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

  /// Nhan ten nhom (vi du "TREND", "TILT"...) hien thi CANH TRAI, NGANG HANG voi cac
  /// nut cua nhom do - thay vi 1 dong rieng phia tren - de tiet kiem chieu cao man
  /// hinh (yeu cau: chu nhom phai ngang voi nut chuc nang tuong ung, vi du chu
  /// "INSTADRIVE" ngang voi 2 nut REV/FWD).
  Widget _sideLabel(String text) => SizedBox(
        width: 64,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );

  /// Boc 1 nhom nut (co the la 1 hoac nhieu hang nut chong len nhau, vi du SPLIT LEG)
  /// voi 1 nhan ten nhom nam ben trai, can giua theo chieu doc voi toan bo chieu cao
  /// cua nhom nut do.
  Widget _labeledSectionRow(String label, Widget content) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _sideLabel(label),
            Expanded(child: content),
          ],
        ),
      );

  Widget _row(List<Widget> children) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );

  Widget _topRow(bool unlocked) => _row([
        HoldButton(
          commandId: 'bt_Power',
          label: 'POWER',
          icon: Icons.power_settings_new,
          connected: unlocked,
        ),
        HoldButton(
          commandId: 'bt_FloorLock',
          label: 'FLOOR LOCK',
          icon: Icons.lock_outline,
          connected: unlocked,
        ),
        HoldButton(
          commandId: 'bt_RevPosition',
          label: 'REV POSITION',
          icon: Icons.change_circle_outlined,
          connected: unlocked,
        ),
      ]);

  Widget _instaDriveRow(bool unlocked) => _row([
        HoldButton(
          commandId: 'bt_InstaDriveREV',
          label: 'REV',
          icon: Icons.arrow_back,
          connected: unlocked,
        ),
        HoldButton(
          commandId: 'bt_InstaDriveFWD',
          label: 'FWD',
          icon: Icons.arrow_forward,
          connected: unlocked,
        ),
      ]);

  Widget _backTableLegSection(bool unlocked) => Column(
        children: [
          _row([
            _labeledColumn('BACK', HoldButton(
              commandId: 'bt_BackUp',
              label: 'UP',
              icon: Icons.arrow_upward,
              connected: unlocked,
            )),
            _labeledColumn('TABLE', HoldButton(
              commandId: 'bt_TableUp',
              label: 'UP',
              icon: Icons.arrow_upward,
              connected: unlocked,
            )),
            _labeledColumn('LEG', HoldButton(
              commandId: 'bt_LegUp',
              label: 'UP',
              icon: Icons.arrow_upward,
              connected: unlocked,
            )),
          ]),
          const SizedBox(height: 3),
          _row([
            HoldButton(
              commandId: 'bt_BackDown',
              label: 'DOWN',
              icon: Icons.arrow_downward,
              connected: unlocked,
            ),
            HoldButton(
              commandId: 'bt_TableDown',
              label: 'DOWN',
              icon: Icons.arrow_downward,
              connected: unlocked,
            ),
            HoldButton(
              commandId: 'bt_LegDown',
              label: 'DOWN',
              icon: Icons.arrow_downward,
              connected: unlocked,
            ),
          ]),
        ],
      );

  Widget _labeledColumn(String title, Widget button) => Column(
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          button,
        ],
      );

  Widget _splitLegRow(bool unlocked) => Column(
        children: [
          _row([
            HoldButton(
              commandId: 'bt_SplitLegLeftUp',
              label: 'LEFT UP',
              icon: Icons.north_west,
              connected: unlocked,
            ),
            HoldButton(
              commandId: 'bt_SplitLegRightUp',
              label: 'RIGHT UP',
              icon: Icons.north_east,
              connected: unlocked,
            ),
          ]),
          const SizedBox(height: 3),
          _row([
            HoldButton(
              commandId: 'bt_SplitLegLeftDown',
              label: 'LEFT DOWN',
              icon: Icons.south_west,
              connected: unlocked,
            ),
            HoldButton(
              commandId: 'bt_SplitLegRightDown',
              label: 'RIGHT DOWN',
              icon: Icons.south_east,
              connected: unlocked,
            ),
          ]),
        ],
      );

  Widget _trendRow(bool unlocked) => _row([
        HoldButton(
          commandId: 'bt_TrendTrend',
          label: 'TREND',
          icon: Icons.airline_seat_flat,
          connected: unlocked,
          accentColor: PendantColors.trendRed,
        ),
        HoldButton(
          commandId: 'bt_TrendRev',
          label: 'TREND REV',
          icon: Icons.airline_seat_flat_angled,
          connected: unlocked,
        ),
      ]);

  Widget _slideRow(bool unlocked) => _row([
        HoldButton(
          commandId: 'bt_SlideHead',
          label: 'HEAD',
          icon: Icons.arrow_back,
          connected: unlocked,
        ),
        HoldButton(
          commandId: 'bt_SlideFoot',
          label: 'FOOT',
          icon: Icons.arrow_forward,
          connected: unlocked,
        ),
      ]);

  Widget _tiltRow(bool unlocked) => _row([
        HoldButton(
          commandId: 'bt_TiltLeft',
          label: 'LEFT',
          icon: Icons.rotate_left,
          connected: unlocked,
        ),
        HoldButton(
          commandId: 'bt_TiltRight',
          label: 'RIGHT',
          icon: Icons.rotate_right,
          connected: unlocked,
        ),
      ]);

  Widget _kidneyRow(bool unlocked) => _row([
        HoldButton(
          commandId: 'bt_KidneyUp',
          label: 'UP',
          icon: Icons.keyboard_arrow_up,
          connected: unlocked,
        ),
        HoldButton(
          commandId: 'bt_KidneyDown',
          label: 'DOWN',
          icon: Icons.keyboard_arrow_down,
          connected: unlocked,
        ),
      ]);

  Widget _presetRow(bool unlocked) => _row([
        HoldButton(
          commandId: 'bt_PresetFlex',
          label: 'FLEX',
          icon: Icons.airline_seat_individual_suite,
          connected: unlocked,
        ),
        HoldButton(
          commandId: 'bt_PresetChair',
          label: 'CHAIR',
          icon: Icons.chair_alt,
          connected: unlocked,
        ),
      ]);

  Widget _levelButton(bool unlocked) => Center(
        child: SizedBox(
          width: 220,
          child: HoldButton(
            commandId: 'bt_Level',
            label: 'LEVEL',
            icon: Icons.horizontal_rule,
            connected: unlocked,
          ),
        ),
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
