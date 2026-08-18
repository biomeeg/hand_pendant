import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ble_manager.dart';
import 'pendant_protocol.dart';

/// Dieu phoi toan bo thao tac "nham giu phim" trong app, mo phong CHINH XAC hanh vi
/// mot cong tac vat ly tren tay bam that:
///   - Nham xuong  -> dong relay tuong ung (gui lenh bt_XXX ngay lap tuc)
///   - Con giu     -> gui lai dung lenh do dinh ky (heartbeat) de nuoi watchdog ben ESP32
///   - Nha tay ra  -> mo relay (gui bt_Stop)
///   - Mat ket noi giua chung -> tu dong huy heartbeat, khong con gi de gui (ESP32 se tu
///     watchdog-stop, va rieng khi disconnect han thi firmware da mo relay ngay lap tuc)
///
/// Chi cho phep 1 nut duoc giu tai 1 thoi diem (giong nhu phan cung 74HC595 chi luu duoc
/// DUY NHAT 1 trang thai 24-bit tai 1 thoi diem - firmware goc cung khong cong don nhieu
/// lenh cung luc). Neu nguoi dung nham nut khac trong khi dang giu 1 nut, thao tac do se
/// bi bo qua cho den khi nha nut dang giu.
class PendantInputCoordinator {
  PendantInputCoordinator._internal() {
    _linkSub = BleManager.instance.linkState.listen((state) {
      if (state != PendantLinkState.connected) {
        // Mat ket noi giua chung khi dang giu phim: dung heartbeat local ngay, khong
        // co gi de gui nua. Firmware ben ESP32 se tu lo phan an toan cua no (watchdog /
        // xu ly onDisconnect).
        _forceRelease();
      }
    });
  }

  static final PendantInputCoordinator instance = PendantInputCoordinator._internal();

  late final StreamSubscription<PendantLinkState> _linkSub;

  Timer? _heartbeatTimer;
  String? _activeCommandId;

  /// Cho UI biet lenh nao dang duoc giu (null = khong co nut nao dang nham), de cac nut
  /// khac tu "mo" (disable) trong luc nay.
  final ValueNotifier<String?> activeCommand = ValueNotifier<String?>(null);

  bool get isAnyCommandActive => _activeCommandId != null;

  /// Goi khi nguoi dung nham xuong 1 nut. Tra ve false neu bi tu choi (dang co nut khac
  /// duoc giu, hoac khong co ket noi) - widget nen bo qua khong xu ly gesture do.
  bool press(String commandId) {
    if (_activeCommandId != null) return false; // da co nut khac dang giu
    if (!BleManager.instance.isConnected) return false;

    _activeCommandId = commandId;
    activeCommand.value = commandId;

    // Gui ngay lap tuc lan dau, khong doi den tick heartbeat dau tien.
    unawaited(BleManager.instance.sendCommand(commandId));

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(kHeartbeatInterval, (_) {
      if (_activeCommandId == commandId) {
        unawaited(BleManager.instance.sendCommand(commandId));
      }
    });
    return true;
  }

  /// Goi khi nguoi dung nha tay (hoac gesture bi huy, vi du keo ngon tay ra khoi nut).
  void release(String commandId) {
    if (_activeCommandId != commandId) return; // khong phai nut dang active, bo qua
    _stopHeartbeatAndClear();
    unawaited(BleManager.instance.sendCommand(kCmdStop));
  }

  /// Dung khan cap: nut STOP rieng tren UI, hoac khi phat hien mat ket noi.
  void emergencyStop() {
    _forceRelease();
    unawaited(BleManager.instance.sendCommand(kCmdStop));
  }

  void _forceRelease() {
    if (_activeCommandId == null) return;
    _stopHeartbeatAndClear();
  }

  void _stopHeartbeatAndClear() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _activeCommandId = null;
    activeCommand.value = null;
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _linkSub.cancel();
    activeCommand.dispose();
  }
}
