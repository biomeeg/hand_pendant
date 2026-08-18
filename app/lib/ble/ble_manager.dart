import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'pendant_protocol.dart';

/// Trang thai ket noi don gian hoa de UI su dung, tach khoi enum goc cua thu vien BLE.
enum PendantLinkState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Boc toan bo logic quet / ket noi / ghi lenh BLE toi bo dieu khien ESP32.
///
/// Day la lop duy nhat trong app duoc phep goi truc tiep API cua flutter_blue_plus,
/// de neu sau nay doi thu vien BLE khac thi chi can sua 1 file nay.
class BleManager {
  BleManager._internal();
  static final BleManager instance = BleManager._internal();

  final Guid _serviceGuid = Guid(kPendantServiceUuid);
  final Guid _characteristicGuid = Guid(kPendantCharacteristicUuid);

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  final StreamController<PendantLinkState> _stateController =
      StreamController<PendantLinkState>.broadcast();

  /// Stream trang thai ket noi de UI lang nghe va cap nhat giao dien / dung heartbeat.
  Stream<PendantLinkState> get linkState => _stateController.stream;

  PendantLinkState _lastState = PendantLinkState.disconnected;
  PendantLinkState get lastState => _lastState;

  bool get isConnected => _connectedDevice != null && _writeCharacteristic != null;

  void _emit(PendantLinkState state) {
    _lastState = state;
    _stateController.add(state);
  }

  /// Kiem tra Bluetooth adapter cua dien thoai co bat khong.
  Stream<BluetoothAdapterState> get adapterState => FlutterBluePlus.adapterState;

  /// Bat dau quet thiet bi. Loc theo Service UUID cua ESP32 khi co the; ket qua tra ve
  /// qua stream [scanResults]. Goi [stopScan] khi khong can quet nua (vi du sau khi
  /// nguoi dung chon 1 thiet bi, hoac khi roi man hinh quet).
  Future<void> startScan({Duration timeout = const Duration(seconds: 12)}) async {
    _emit(PendantLinkState.scanning);
    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [_serviceGuid],
    );
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  Future<void> stopScan() async {
    if (await FlutterBluePlus.isScanning.first) {
      await FlutterBluePlus.stopScan();
    }
  }

  /// Ket noi toi 1 thiet bi da tim thay khi quet, tim dung Service/Characteristic,
  /// va lang nghe su kien mat ket noi de bao cho UI (widgets se tu gui bt_Stop / dung
  /// heartbeat khi thay disconnected).
  Future<void> connect(BluetoothDevice device) async {
    await stopScan();
    _emit(PendantLinkState.connecting);
    try {
      await device.connect(timeout: const Duration(seconds: 10));

      _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _writeCharacteristic = null;
          _connectedDevice = null;
          _emit(PendantLinkState.disconnected);
        }
      });

      final services = await device.discoverServices();
      BluetoothCharacteristic? foundChar;
      for (final service in services) {
        if (service.uuid == _serviceGuid) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid == _characteristicGuid) {
              foundChar = characteristic;
              break;
            }
          }
        }
        if (foundChar != null) break;
      }

      if (foundChar == null) {
        await device.disconnect();
        throw Exception(
            'Khong tim thay dung Service/Characteristic BLE tren thiet bi nay. '
            'Day co phai la bo dieu khien ESP32 cua ban mo khong?');
      }

      _connectedDevice = device;
      _writeCharacteristic = foundChar;
      _emit(PendantLinkState.connected);
    } catch (e) {
      _emit(PendantLinkState.error);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _connectedDevice?.disconnect();
    } finally {
      _writeCharacteristic = null;
      _connectedDevice = null;
      _emit(PendantLinkState.disconnected);
    }
  }

  String? get connectedDeviceName =>
      _connectedDevice == null ? null : _connectedDevice!.platformName;

  String? get connectedDeviceId =>
      _connectedDevice == null ? null : _connectedDevice!.remoteId.str;

  /// Gui 1 chuoi lenh (vi du "bt_TableUp" hoac "bt_Stop") xuong ESP32.
  /// Dung withoutResponse=false (Write Request co xac nhan ACK tang tin cay), phu hop
  /// vi tan suat gui khong qua cao (heartbeat 150ms/lan).
  Future<void> sendCommand(String command) async {
    final characteristic = _writeCharacteristic;
    if (characteristic == null) {
      // Khong co ket noi -> im lang bo qua, UI da tu khoa nut khi mat ket noi.
      return;
    }
    try {
      await characteristic.write(command.codeUnits, withoutResponse: false);
    } catch (_) {
      // Loi khi ghi (vi du vua mat ket noi giua chung) - coi nhu mat ket noi,
      // firmware se tu watchdog-stop neu heartbeat tiep theo cung khong toi duoc.
      _emit(PendantLinkState.error);
    }
  }

  void dispose() {
    _connectionSub?.cancel();
    _stateController.close();
  }
}
