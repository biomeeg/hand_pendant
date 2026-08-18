import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/ble_manager.dart';
import '../ble/hold_command_controller.dart';
import '../models/pendant_type.dart';
import '../theme/pendant_theme.dart';
import '../widgets/hold_button.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

const String kPrefPendantType = 'pendant_type';

/// Man hinh dieu khien chinh, bo cuc phong theo tay bam vat ly that (thay doi theo
/// PendantType: D760 co hang InstaDrive, D850 co hang Slide + Kidney).
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  PendantType _pendantType = PendantType.d760;

  @override
  void initState() {
    super.initState();
    _loadPendantType();
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PendantLinkState>(
      stream: BleManager.instance.linkState,
      initialData: BleManager.instance.lastState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? PendantLinkState.disconnected;
        final connected = state == PendantLinkState.connected;

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
                _ConnectionBanner(state: state),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Column(
                      children: [
                        _topRow(connected),
                        const SizedBox(height: 8),
                        _batteryNotice(),
                        const SizedBox(height: 16),
                        if (_pendantType == PendantType.d760) ...[
                          _sectionLabel('INSTADRIVE'),
                          _instaDriveRow(connected),
                          const SizedBox(height: 16),
                        ],
                        _sectionLabel('BACK / TABLE / LEG'),
                        _backTableLegSection(connected),
                        const SizedBox(height: 16),
                        _sectionLabel('SPLIT LEG'),
                        _splitLegRow(connected),
                        const SizedBox(height: 16),
                        _trendRow(connected),
                        const SizedBox(height: 16),
                        if (_pendantType == PendantType.d850) ...[
                          _sectionLabel('SLIDE'),
                          _slideRow(connected),
                          const SizedBox(height: 16),
                        ],
                        _sectionLabel('TILT'),
                        _tiltRow(connected),
                        const SizedBox(height: 16),
                        if (_pendantType == PendantType.d850) ...[
                          _sectionLabel('KIDNEY'),
                          _kidneyRow(connected),
                          const SizedBox(height: 16),
                        ],
                        _sectionLabel('PRESET'),
                        _presetRow(connected),
                        const SizedBox(height: 16),
                        _levelButton(connected),
                        const SizedBox(height: 16),
                        _statusIndicatorsNotice(),
                        const SizedBox(height: 90),
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
            onPressed: () => PendantInputCoordinator.instance.emergencyStop(),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------------------
  // Cac khoi giao dien con
  // ----------------------------------------------------------------------

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _row(List<Widget> children) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );

  Widget _topRow(bool connected) => _row([
        HoldButton(
          commandId: 'bt_Power',
          label: 'POWER',
          icon: Icons.power_settings_new,
          connected: connected,
        ),
        HoldButton(
          commandId: 'bt_FloorLock',
          label: 'FLOOR LOCK',
          icon: Icons.lock_outline,
          connected: connected,
        ),
        HoldButton(
          commandId: 'bt_RevPosition',
          label: 'REV POSITION',
          icon: Icons.change_circle_outlined,
          connected: connected,
        ),
      ]);

  Widget _batteryNotice() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Luu y: firmware hien tai chi GUI lenh xuong ban mo (khong doc du lieu tra ve), '
          'nen app khong the hien thi that muc pin / trang thai LED tren tay bam goc.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );

  Widget _instaDriveRow(bool connected) => _row([
        HoldButton(
          commandId: 'bt_InstaDriveREV',
          label: 'REV',
          icon: Icons.arrow_back,
          connected: connected,
        ),
        HoldButton(
          commandId: 'bt_InstaDriveFWD',
          label: 'FWD',
          icon: Icons.arrow_forward,
          connected: connected,
        ),
      ]);

  Widget _backTableLegSection(bool connected) => Column(
        children: [
          _row([
            _labeledColumn('BACK', HoldButton(
              commandId: 'bt_BackUp',
              label: 'UP',
              icon: Icons.arrow_upward,
              connected: connected,
            )),
            _labeledColumn('TABLE', HoldButton(
              commandId: 'bt_TableUp',
              label: 'UP',
              icon: Icons.arrow_upward,
              connected: connected,
            )),
            _labeledColumn('LEG', HoldButton(
              commandId: 'bt_LegUp',
              label: 'UP',
              icon: Icons.arrow_upward,
              connected: connected,
            )),
          ]),
          const SizedBox(height: 8),
          _row([
            HoldButton(
              commandId: 'bt_BackDown',
              label: 'DOWN',
              icon: Icons.arrow_downward,
              connected: connected,
            ),
            HoldButton(
              commandId: 'bt_TableDown',
              label: 'DOWN',
              icon: Icons.arrow_downward,
              connected: connected,
            ),
            HoldButton(
              commandId: 'bt_LegDown',
              label: 'DOWN',
              icon: Icons.arrow_downward,
              connected: connected,
            ),
          ]),
        ],
      );

  Widget _labeledColumn(String title, Widget button) => Column(
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          button,
        ],
      );

  Widget _splitLegRow(bool connected) => Column(
        children: [
          _row([
            HoldButton(
              commandId: 'bt_SplitLegLeftUp',
              label: 'LEFT UP',
              icon: Icons.north_west,
              connected: connected,
            ),
            HoldButton(
              commandId: 'bt_SplitLegRightUp',
              label: 'RIGHT UP',
              icon: Icons.north_east,
              connected: connected,
            ),
          ]),
          const SizedBox(height: 8),
          _row([
            HoldButton(
              commandId: 'bt_SplitLegLeftDown',
              label: 'LEFT DOWN',
              icon: Icons.south_west,
              connected: connected,
            ),
            HoldButton(
              commandId: 'bt_SplitLegRightDown',
              label: 'RIGHT DOWN',
              icon: Icons.south_east,
              connected: connected,
            ),
          ]),
        ],
      );

  Widget _trendRow(bool connected) => _row([
        HoldButton(
          commandId: 'bt_TrendTrend',
          label: 'TREND',
          icon: Icons.airline_seat_flat,
          connected: connected,
          accentColor: PendantColors.trendRed,
        ),
        HoldButton(
          commandId: 'bt_TrendRev',
          label: 'TREND REV',
          icon: Icons.airline_seat_flat_angled,
          connected: connected,
        ),
      ]);

  Widget _slideRow(bool connected) => _row([
        HoldButton(
          commandId: 'bt_SlideHead',
          label: 'HEAD',
          icon: Icons.arrow_back,
          connected: connected,
        ),
        HoldButton(
          commandId: 'bt_SlideFoot',
          label: 'FOOT',
          icon: Icons.arrow_forward,
          connected: connected,
        ),
      ]);

  Widget _tiltRow(bool connected) => _row([
        HoldButton(
          commandId: 'bt_TiltLeft',
          label: 'LEFT',
          icon: Icons.rotate_left,
          connected: connected,
        ),
        HoldButton(
          commandId: 'bt_TiltRight',
          label: 'RIGHT',
          icon: Icons.rotate_right,
          connected: connected,
        ),
      ]);

  Widget _kidneyRow(bool connected) => _row([
        HoldButton(
          commandId: 'bt_KidneyUp',
          label: 'UP',
          icon: Icons.keyboard_arrow_up,
          connected: connected,
        ),
        HoldButton(
          commandId: 'bt_KidneyDown',
          label: 'DOWN',
          icon: Icons.keyboard_arrow_down,
          connected: connected,
        ),
      ]);

  Widget _presetRow(bool connected) => _row([
        HoldButton(
          commandId: 'bt_PresetFlex',
          label: 'FLEX',
          icon: Icons.airline_seat_individual_suite,
          connected: connected,
        ),
        HoldButton(
          commandId: 'bt_PresetChair',
          label: 'CHAIR',
          icon: Icons.chair_alt,
          connected: connected,
        ),
      ]);

  Widget _levelButton(bool connected) => Center(
        child: SizedBox(
          width: 220,
          child: HoldButton(
            commandId: 'bt_Level',
            label: 'LEVEL',
            icon: Icons.horizontal_rule,
            connected: connected,
            diameter: 56,
          ),
        ),
      );

  Widget _statusIndicatorsNotice() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'AUX PENDANT / TABLE LIMIT / SERVICE: den bao nay tren tay bam goc khong the '
          'mo phong duoc vi firmware hien tai la mach mot chieu (chi ghi lenh, khong doc '
          'trang thai). Neu can, phai bo sung duong tin hieu doc + notify BLE rieng.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state});
  final PendantLinkState state;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String text;
    switch (state) {
      case PendantLinkState.connected:
        color = Colors.green.shade700;
        text = 'Da ket noi: ${BleManager.instance.connectedDeviceName ?? "ESP32"}';
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
