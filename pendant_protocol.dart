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
/// Luon duoc firmware chap nhan, ke ca khi CHUA xac thuc mat khau (chi mo relay,
/// khong bao gio la hanh dong nguy hiem nen khong can khoa).
const String kCmdStop = 'bt_Stop';

/// Tien to lenh xac thuc mat khau ket noi. Gui kem mat khau: "bt_Auth:<mat_khau>".
/// PHAI gui va duoc firmware xac nhan AUTH_OK truoc khi bat ky lenh dieu khien nao
/// (ngoai bt_Stop) duoc firmware chap nhan - xem COMMAND_TABLE va bien `authenticated`
/// trong firmware.
const String kCmdAuthPrefix = 'bt_Auth:';

/// Tien to lenh doi mat khau ket noi (yeu cau da xac thuc):
/// "bt_SetPass:<mat_khau_cu>:<mat_khau_moi>".
const String kCmdSetPassPrefix = 'bt_SetPass:';

/// Tien to lenh doi ten thiet bi BLE quang ba (yeu cau da xac thuc, va o app la tinh
/// nang rieng danh cho admin - xem kAdminUnlockPassword): "bt_SetName:<ten_moi>".
/// Sau khi doi ten thanh cong, ESP32 se TU KHOI DONG LAI de quang ba ten moi.
const String kCmdSetNamePrefix = 'bt_SetName:';

/// Cac chuoi phan hoi firmware gui nguoc ve app qua BLE Notify (xem sendReply() trong
/// firmware). Dung de app biet lenh Auth/SetPass/SetName vua gui thanh cong hay that bai.
const String kReplyAuthOk = 'AUTH_OK';
const String kReplyAuthFail = 'AUTH_FAIL';
const String kReplyPassOk = 'PASS_OK';
const String kReplyPassFail = 'PASS_FAIL';
const String kReplyNameOk = 'NAME_OK';
const String kReplyNameFail = 'NAME_FAIL';

/// Do dai toi da cho ten thiet bi moi (gioi han an toan cho goi quang ba BLE - dat qua
/// dai co the lam hong quang ba). Firmware cung tu cat bot neu vuot qua do dai nay.
const int kMaxDeviceNameLength = 20;

/// Mat khau ket noi mac dinh khi firmware chua tung duoc doi mat khau lan nao (dinh
/// nghia trong firmware qua Preferences, chi hien thi lai o day de app goi y cho nguoi
/// dung trong hop thoai nhap mat khau lan dau).
const String kDefaultConnectionPasswordHint = '0000';

/// Mat khau "admin" CUNG (hardcode trong ma nguon app, KHONG lien quan gi den mat khau
/// ket noi o tren) chi de MO KHOA hien thi tinh nang doi ten thiet bi trong man hinh Cai
/// dat - muc dich la tach rieng "ai duoc phep dieu khien ban mo" (mat khau ket noi, doi
/// duoc, luu trong firmware) voi "ai duoc phep doi ten thiet bi" (chi ky thuat vien biet
/// hang so nay trong ma nguon). Day KHONG phai bien phap ma hoa/bao mat manh - bat ky ai
/// doc duoc ma nguon/file APK deu co the tim ra chuoi nay. Neu can bao mat that su, phai
/// doi hang so nay va bien dich lai app truoc khi phat hanh rong rai.
const String kAdminUnlockPassword = 'admin123';

/// Khoa luu mat khau ket noi da xac thuc thanh cong tren dien thoai (de lan sau tu dong
/// xac thuc lai, khong phai go tay moi lan mo app).
const String kPrefConnectionPassword = 'pendant_connection_password';

/// Chu ky (ms) app se gui LAI dung lenh dang giu de lam "heartbeat" cho watchdog
/// ben firmware (WATCHDOG_TIMEOUT_MS trong firmware, mac dinh 500ms). Gia tri nay
/// phai nho hon watchdog it nhat 2-3 lan de tranh bi ngat nham do do tre mang binh
/// thuong.
const Duration kHeartbeatInterval = Duration(milliseconds: 150);

/// Danh sach day du cac ma lenh (khong bao gom bt_Stop) - dung de kiem tra hop le.
///
/// LUU Y ve 4 lenh bt_SplitLeg*: day van la 4 lenh BLE THAT khong doi (dung nguyen tu
/// firmware goc). Tuy nhien tu ban co xac nhan tu nguoi dung ve cach hoat dong THAT cua
/// tay bam (chi co 2 nut vat ly SPLIT LEG LEFT/RIGHT, phai bam dong thoi voi LEG UP/
/// DOWN), giao dien app KHONG con 4 nut rieng goi thang 4 lenh nay nua - app chi hien
/// thi 2 nut "chon ben" (xem kSplitSelectorLeft/Right trong hold_command_controller.dart)
/// va PendantInputCoordinator se TU CHON dung 1 trong 4 lenh nay de gui khi ca nut chon
/// ben VA nut LEG UP/DOWN cung dang duoc giu.
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
