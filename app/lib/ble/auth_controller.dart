import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_manager.dart';
import 'pendant_protocol.dart';

/// Dieu phoi toan bo logic xac thuc mat khau ket noi voi firmware.
///
/// An toan la o FIRMWARE (moi lenh dieu khien, ngoai bt_Stop, bi tu choi cho den khi
/// firmware nhan dung mat khau qua bt_Auth) - lop nay chi la phia app: gui lenh xac
/// thuc, doc phan hoi qua BLE Notify, va nho mat khau da dung tren dien thoai de lan
/// sau tu dong xac thuc lai (khong phai go tay moi lan mo app).
///
/// QUAN TRONG: firmware luon dat lai trang thai "chua xac thuc" moi khi co 1 ket noi
/// BLE MOI (xem onConnect trong .ino) - vi vay o day cung phai tu dong thu xac thuc lai
/// (bang mat khau da luu) ngay sau moi lan ket noi thanh cong, chu khong duoc coi trang
/// thai xac thuc cua lan ket noi truoc la con hieu luc.
class PendantAuthController {
  PendantAuthController._internal() {
    BleManager.instance.linkState.listen((state) {
      if (state == PendantLinkState.connected) {
        // Ket noi BLE moi (hoac ket noi lai) -> firmware da tu dat lai chua xac thuc,
        // ben app cung phai dat lai tuong ung va thu tu dong xac thuc bang mat khau da luu.
        authenticated.value = false;
        lastAuthFailed.value = false;
        unawaited(_tryAutoAuth());
      } else {
        authenticated.value = false;
      }
    });
    BleManager.instance.responses.listen(_onResponse);
  }

  static final PendantAuthController instance = PendantAuthController._internal();

  /// true khi firmware da xac nhan dung mat khau cho ket noi HIEN TAI. Cac man hinh
  /// dung gia tri nay de mo/khoa nut dieu khien va cac chuc nang doi mat khau/ten.
  final ValueNotifier<bool> authenticated = ValueNotifier<bool>(false);

  /// true khi lan thu xac thuc GAN NHAT that bai (de UI hien thong bao "sai mat khau").
  final ValueNotifier<bool> lastAuthFailed = ValueNotifier<bool>(false);

  Completer<bool>? _pendingAuth;
  Completer<bool>? _pendingSetPass;
  Completer<bool>? _pendingSetName;

  void _onResponse(String resp) {
    switch (resp) {
      case kReplyAuthOk:
        authenticated.value = true;
        lastAuthFailed.value = false;
        _pendingAuth?.complete(true);
        _pendingAuth = null;
        break;
      case kReplyAuthFail:
        authenticated.value = false;
        lastAuthFailed.value = true;
        _pendingAuth?.complete(false);
        _pendingAuth = null;
        break;
      case kReplyPassOk:
        _pendingSetPass?.complete(true);
        _pendingSetPass = null;
        break;
      case kReplyPassFail:
        _pendingSetPass?.complete(false);
        _pendingSetPass = null;
        break;
      case kReplyNameOk:
        _pendingSetName?.complete(true);
        _pendingSetName = null;
        break;
      case kReplyNameFail:
        _pendingSetName?.complete(false);
        _pendingSetName = null;
        break;
    }
  }

  Future<void> _tryAutoAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kPrefConnectionPassword);
    if (saved != null && saved.isNotEmpty) {
      await authenticate(saved, remember: false);
    }
  }

  /// Gui mat khau len firmware va cho phan hoi (toi da 3 giay). Neu dung, luu lai mat
  /// khau nay tren dien thoai (mac dinh remember=true, tat khi tu dong xac thuc lai
  /// bang mat khau da luu san de khong ghi lai chinh no nhieu lan khong can thiet).
  Future<bool> authenticate(String password, {bool remember = true}) async {
    if (!BleManager.instance.isConnected) return false;
    _pendingAuth = Completer<bool>();
    await BleManager.instance.sendAuth(password);
    bool ok;
    try {
      ok = await _pendingAuth!.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      ok = false;
      _pendingAuth = null;
    }
    if (ok && remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPrefConnectionPassword, password);
    }
    return ok;
  }

  /// Doi mat khau ket noi. Yeu cau [authenticated] = true truoc khi goi. Khi thanh cong,
  /// tu dong cap nhat mat khau da luu tren dien thoai de lan sau tu xac thuc bang mat
  /// khau moi.
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (!authenticated.value) return false;
    _pendingSetPass = Completer<bool>();
    await BleManager.instance.sendSetPassword(oldPassword, newPassword);
    bool ok;
    try {
      ok = await _pendingSetPass!.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      ok = false;
      _pendingSetPass = null;
    }
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPrefConnectionPassword, newPassword);
    }
    return ok;
  }

  /// Doi ten thiet bi BLE quang ba. Yeu cau [authenticated] = true. Khi thanh cong,
  /// firmware se TU KHOI DONG LAI ngay sau do (ket noi hien tai se roi vao trang thai
  /// mat ket noi trong vai giay - day la hanh vi mong doi, khong phai loi).
  Future<bool> renameDevice(String newName) async {
    if (!authenticated.value) return false;
    _pendingSetName = Completer<bool>();
    await BleManager.instance.sendSetName(newName);
    try {
      return await _pendingSetName!.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      _pendingSetName = null;
      return false;
    }
  }
}
