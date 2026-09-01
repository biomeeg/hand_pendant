import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ble_manager.dart';
import 'pendant_protocol.dart';

/// 2 "nut ao" CHI TON TAI O APP (khong phai lenh BLE that, KHONG BAO GIO duoc gui thang
/// qua BleManager.sendCommand) - dai dien cho viec dang giu nut CHON BEN cua SPLIT LEG
/// (LEFT / RIGHT). Ly do can 2 pseudo-id nay: tren tay bam THAT, SPLIT LEG chi co dung
/// 2 nut vat ly LEFT/RIGHT - de tao chuyen dong "nang/ha 1 ben chan" phai BAM DONG THOI
/// nut LEFT (hoac RIGHT) VOI nut LEG UP (hoac LEG DOWN) dang co san trong nhom BACK/
/// TABLE/LEG, chu KHONG co 4 nut rieng "trai len/trai xuong/phai len/phai xuong" nhu
/// thiet ke truoc do. Coordinator ben duoi se tu tinh ra dung 1 trong 4 lenh BLE that
/// (bt_SplitLegLeftUp/Down, bt_SplitLegRightUp/Down) dua theo to hop dang giu, hoac gui
/// thang bt_LegUp/bt_LegDown neu khong co nut chon ben nao dang giu.
const String kSplitSelectorLeft = '_split_selector_left';
const String kSplitSelectorRight = '_split_selector_right';

/// Dieu phoi toan bo thao tac "nham giu phim" trong app, mo phong CHINH XAC hanh vi
/// mot cong tac vat ly tren tay bam that:
///   - Nham xuong  -> dong relay tuong ung (gui lenh bt_XXX ngay lap tuc)
///   - Con giu     -> gui lai dung lenh do dinh ky (heartbeat) de nuoi watchdog ben ESP32
///   - Nha tay ra  -> mo relay (gui bt_Stop)
///   - Mat ket noi giua chung -> tu dong huy heartbeat, khong con gi de gui (ESP32 se tu
///     watchdog-stop, va rieng khi disconnect han thi firmware da mo relay ngay lap tuc)
///
/// QUY TAC GIU NUT:
///   - Mac dinh CHI cho phep 1 nut duoc giu tai 1 thoi diem (giong nhu tay bam vat ly
///     goc). Neu nguoi dung nham nut khac trong khi dang giu 1 nut, thao tac do bi bo qua.
///   - NGOAI LE DUY NHAT: nut LEG UP hoac LEG DOWN duoc phep giu DONG THOI voi 1 trong 2
///     nut chon ben SPLIT LEG ([kSplitSelectorLeft]/[kSplitSelectorRight]) - dung mo
///     phong dung cach thao tac tren tay bam that (xem chu thich o tren). Khi ca 2 cung
///     duoc giu, lenh BLE THAT su duoc gui la 1 trong 4 lenh composite co san
///     (bt_SplitLegLeftUp/Down, bt_SplitLegRightUp/Down) - firmware KHONG doi gi ca, van
///     dung nguyen 4 lenh nay tu firmware goc cua ban.
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

  /// Nut "chuyen dong" dang giu: hoac la 1 nut binh thuong bat ky (BACK UP, TREND...),
  /// hoac la bt_LegUp/bt_LegDown. Chi 1 gia tri tai 1 thoi diem.
  String? _movementId;

  /// Nut CHON BEN cua SPLIT LEG dang giu: null, [kSplitSelectorLeft] hoac
  /// [kSplitSelectorRight]. Chi co y nghia khi ket hop voi [_movementId] la LEG UP/DOWN.
  String? _splitSelector;

  /// Lenh BLE THAT gan nhat da gui (dung de biet co can gui bt_Stop khi ve trang thai
  /// "khong con gi active" hay khong - tranh spam bt_Stop khi chi nham/nha nut chon ben
  /// SPLIT LEG ma chua he co chuyen dong nao duoc kich hoat).
  String? _lastSentEffective;

  /// Cho UI biet nut "chuyen dong" nao dang duoc giu (null = khong co), de cac nut binh
  /// thuong khac tu "mo" (disable) trong luc nay.
  final ValueNotifier<String?> activeCommand = ValueNotifier<String?>(null);

  /// Cho UI biet nut CHON BEN SPLIT LEG nao (neu co) dang duoc giu.
  final ValueNotifier<String?> activeSplitSelector = ValueNotifier<String?>(null);

  bool get isAnyCommandActive => _movementId != null || _splitSelector != null;

  bool _isLegMovement(String id) => id == 'bt_LegUp' || id == 'bt_LegDown';

  bool _isSplitSelector(String id) => id == kSplitSelectorLeft || id == kSplitSelectorRight;

  /// Tra ve true neu [commandId] dang bi khoa (khong duoc phep bam luc nay) do co 1 nut
  /// khac KHONG tuong thich dang duoc giu. Dung boi HoldButton de quyet dinh enable/
  /// disable - thay vi chi so sanh voi 1 "activeCommand" duy nhat nhu truoc, vi gio day
  /// LEG UP/DOWN duoc phep hoat dong DONG THOI voi 1 trong 2 nut chon ben SPLIT LEG.
  bool isBlocked(String commandId) {
    if (_isSplitSelector(commandId)) {
      if (_splitSelector != null && _splitSelector != commandId) return true;
      if (_movementId != null && !_isLegMovement(_movementId!)) return true;
      return false;
    }
    if (_isLegMovement(commandId)) {
      if (_movementId != null && _movementId != commandId) return true;
      return false; // KHONG bi khoa boi activeSplitSelector - duoc phep ket hop.
    }
    // Nut binh thuong (khong lien quan SPLIT LEG).
    if (_movementId != null && _movementId != commandId) return true;
    if (_splitSelector != null) return true;
    return false;
  }

  /// Goi khi nguoi dung nham xuong 1 nut. Tra ve false neu bi tu choi (dang co nut khac
  /// khong tuong thich dang giu, hoac khong co ket noi) - widget nen bo qua gesture do.
  bool press(String commandId) {
    if (!BleManager.instance.isConnected) return false;
    if (isBlocked(commandId)) return false;

    if (_isSplitSelector(commandId)) {
      _splitSelector = commandId;
      activeSplitSelector.value = commandId;
    } else {
      // Nut "chuyen dong" (binh thuong hoac LEG UP/DOWN).
      if (_movementId != null) return false; // an toan: khong ghi de 1 chuyen dong khac
      _movementId = commandId;
      activeCommand.value = commandId;
    }

    _restartHeartbeatForCurrentState();
    return true;
  }

  /// Goi khi nguoi dung nha tay (hoac gesture bi huy, vi du keo ngon tay ra khoi nut).
  void release(String commandId) {
    if (_isSplitSelector(commandId)) {
      if (_splitSelector != commandId) return;
      _splitSelector = null;
      activeSplitSelector.value = null;
    } else {
      if (_movementId != commandId) return;
      _movementId = null;
      activeCommand.value = null;
    }
    _restartHeartbeatForCurrentState();
  }

  /// Dung khan cap: nut STOP rieng tren UI, hoac khi phat hien mat ket noi.
  void emergencyStop() {
    _forceRelease();
    unawaited(BleManager.instance.sendCommand(kCmdStop));
    _lastSentEffective = null;
  }

  void _forceRelease() {
    if (_movementId == null && _splitSelector == null) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _movementId = null;
    _splitSelector = null;
    _lastSentEffective = null;
    activeCommand.value = null;
    activeSplitSelector.value = null;
  }

  /// Tinh ra dung 1 lenh BLE THAT can gui dua theo to hop dang giu hien tai, hoac null
  /// neu chua co "chuyen dong" nao duoc giu (vi du moi chi giu 1 nut chon ben SPLIT LEG,
  /// chua giu them LEG UP/DOWN - luc nay chua can gui gi ca).
  String? _computeEffectiveCommand() {
    final movement = _movementId;
    if (movement == null) return null;
    if (_isLegMovement(movement)) {
      if (_splitSelector == kSplitSelectorLeft) {
        return movement == 'bt_LegUp' ? 'bt_SplitLegLeftUp' : 'bt_SplitLegLeftDown';
      }
      if (_splitSelector == kSplitSelectorRight) {
        return movement == 'bt_LegUp' ? 'bt_SplitLegRightUp' : 'bt_SplitLegRightDown';
      }
    }
    return movement;
  }

  void _restartHeartbeatForCurrentState() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final effective = _computeEffectiveCommand();
    if (effective == null) {
      // Vi du: nguoi dung moi giu 1 nut chon ben SPLIT LEG, chua giu LEG UP/DOWN - chua
      // tung gui lenh dieu khien nao nen KHONG can gui bt_Stop (tranh spam vo ich).
      if (_lastSentEffective != null) {
        unawaited(BleManager.instance.sendCommand(kCmdStop));
      }
      _lastSentEffective = null;
      return;
    }

    _lastSentEffective = effective;
    unawaited(BleManager.instance.sendCommand(effective));
    _heartbeatTimer = Timer.periodic(kHeartbeatInterval, (_) {
      final current = _computeEffectiveCommand();
      if (current == null) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
        return;
      }
      unawaited(BleManager.instance.sendCommand(current));
    });
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _linkSub.cancel();
    activeCommand.dispose();
    activeSplitSelector.dispose();
  }
}
