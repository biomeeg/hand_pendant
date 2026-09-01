/// Hang so giao thuc BLE giua app va bo dieu khien trung gian ESP32.
///
/// PHAI khop chinh xac (phan biet hoa/thuong) voi bang COMMAND_TABLE trong firmware
/// `firmware/esp32_pendant_controller/esp32_pendant_controller.ino`. Neu doi ten lenh o
/// mot ben, phai doi ca hai ben.
library pendant_protocol;

/// UUID quang ba/dich vu GATT cua ESP32 (dat trong firmware qua SERVICE_UUID).
const String kPendantServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

/// UUID characteristic dung de GHI lenh xuong ESP32 (CHARACTERISTIC_UUID trong firmware).
const String kPendantCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

/// Ten thiet bi BLE ma ESP32 quang ba (BLEDevice::init("MyESP32") trong firmware).
const String kPendantDeviceName = 'MyESP32';

/// Lenh dac biet: mo tat ca relay ngay lap tuc (nha phim / dung khan cap).
const String kCmdStop = 'bt_Stop';

/// Chu ky (ms) app se gui LAI dung lenh dang giu de lam "heartbeat" cho watchdog
/// ben firmware (WATCHDOG_TIMEOUT_MS trong firmware, mac dinh 500ms). Gia tri nay
/// phai nho hon watchdog it nhat 2-3 lan de tranh bi ngat nham do do tre mang binh
/// thuong.
const Duration kHeartbeatInterval = Duration(milliseconds: 150);

/// Danh sach day du cac ma lenh (khong bao gom bt_Stop) - dung de kiem tra hop le.
const List<String> kAllCommandIds = [
  'bt_Power',
  'bt_FloorLock',
  'bt_RevPosition',
  'bt_InstaDriveREV',
  'bt_InstaDriveFWD',
  'bt_BackUp',
  'bt_TableUp',
  'bt_LegUp',
  'bt_BackDown',
  'bt_TableDown',
  'bt_LegDown',
  'bt_SplitLegLeftUp',
  'bt_SplitLegLeftDown',
  'bt_SplitLegRightUp',
  'bt_SplitLegRightDown',
  'bt_TrendTrend',
  'bt_TrendRev',
  'bt_TiltLeft',
  'bt_TiltRight',
  'bt_PresetFlex',
  'bt_PresetChair',
  'bt_Level',
  'bt_SlideHead',
  'bt_SlideFoot',
  'bt_KidneyUp',
  'bt_KidneyDown',
];
