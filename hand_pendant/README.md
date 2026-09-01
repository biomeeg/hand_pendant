# Bo dieu khien khong day thay the tay bam ban mo Berchtold D760 / D850

Du an gom 2 phan:

```
hand_pendant_project/
├── firmware/esp32_pendant_controller/esp32_pendant_controller.ino   <- nap vao ESP32-DEVKIT
└── app/                                                              <- du an Flutter (Android + iPhone)
    ├── pubspec.yaml
    ├── lib/                          <- toan bo ma nguon Dart
    └── platform_config/              <- doan cau hinh can dan vao Android/iOS sau khi scaffold
```

Kien truc: **App dien thoai (Flutter, BLE Central)** → **bo trung gian ESP32 (BLE Peripheral +
74HC595 dieu khien relay)** → **jack cam tay dieu khien nguyen ban cua ban mo**. App khong dong
vai tro gi khac ngoai gui chuoi lenh dang text (vi du `bt_TableUp`, `bt_Stop`) - toan bo logic an
toan quyet dinh dong/mo relay nam trong firmware ESP32.

---

## 1. Nap firmware ESP32

1. Mo Arduino IDE, cai board package **ESP32 (Espressif Systems)** va thu vien BLE di kem
   (`BLEDevice.h`, `BLEServer.h`, `BLEUtils.h` - da co san khi cai board ESP32 chuan).
2. Mo file `firmware/esp32_pendant_controller/esp32_pendant_controller.ino`.
3. **Doc ky khoi comment o dau file** - co 1 gia dinh anh xa bit ban PHAI tu xac nhan truoc khi
   dung tren ban mo that (xem muc 5 ben duoi).
4. Nap vao module ESP32-DEVKIT nhu binh thuong (giu nguyen so do chan SER_0=18, SHIFT_CLK=19,
   LATCH_CLK=21, OE_CTL=22, RESET_595=23 giong firmware goc cua ban).
5. Mo Serial Monitor (115200 baud) de xem log: firmware se in ra moi lenh nhan duoc, canh bao neu
   lenh khong xac dinh, va thong bao khi watchdog/an toan tu dong dung relay.

### Nhung gi da thay doi so voi firmware goc ban gui

| # | Thay doi | Ly do |
|---|----------|-------|
| 1 | Them watchdog 500ms (`WATCHDOG_TIMEOUT_MS`) | Neu app ngung gui heartbeat (mat song Bluetooth, tat app, roi khoi pham vi...) trong luc dang giu 1 nut, firmware **tu dong mo relay** sau toi da 500ms thay vi giu nguyen trang thai mai mai. |
| 2 | Them `BLEServerCallbacks::onDisconnect` | Khi BLE ngat ket noi han (khong chi mat 1 goi tin), relay duoc mo **ngay lap tuc**, khong doi het 500ms, va tu dong quang ba (advertising) lai de app ket noi lai duoc. |
| 3 | Them 4 lenh `bt_SlideHead`, `bt_SlideFoot`, `bt_KidneyUp`, `bt_KidneyDown` cho model D850 | Tan dung 4 bit `RESERVE1..4` dang de trong trong ban do bit goc. **Can xac nhan phan cung (xem muc 5).** |
| 4 | Sua `#define SERIAL_NO 'Z10464'` → `"Z10464"` | Nhay don chi danh cho 1 ky tu, chuoi nhieu ky tu phai dung nhay kep (cu phap C/C++). Ban goc co the da bien dich duoc do trinh bien dich tu dong quy doi thanh so nguyen da ky tu, nhung gia tri do khong phai la chuoi "Z10464" nhu mong muon. |
| 5 | Gom bang lenh vao 1 struct/array (`COMMAND_TABLE`) | De bao tri, them lenh moi chi can them 1 dong thay vi 1 khoi if/else moi. |

Cac ma lenh **giu nguyen y het** firmware goc cua ban (`bt_Power`, `bt_TableUp`, `bt_BackDown`, ...)
va ban do bit cho cac lenh do **khong doi mot chut nao** - chi bo sung, khong sua gia tri cu.

---

## 2. Giao thuc BLE (app ↔ ESP32)

| Thong so | Gia tri |
|---|---|
| Ten thiet bi quang ba | `MyESP32` |
| Service UUID | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| Characteristic UUID (Read/Write) | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| Chieu du lieu | App → ESP32 (ghi text thuan, vi du `bt_TableUp`) |
| Chu ky heartbeat cua app | 150ms trong luc con giu 1 nut |
| Watchdog cua ESP32 | 500ms khong nhan duoc lenh → tu mo relay |

**Luong su kien khi nguoi dung nham giu 1 nut tren app:**

```
Nham xuong  → app gui "bt_TableUp" ngay          → ESP32 dong relay tuong ung
Con giu     → app gui lai "bt_TableUp" moi 150ms  → ESP32 lam moi bo dem watchdog
Nha tay ra  → app gui "bt_Stop"                    → ESP32 mo tat ca relay
(nếu mất BLE giữa chừng) → ESP32 không nhận thêm gì → watchdog hết hạn sau ≤500ms → tự mở relay
```

App chi cho phep **1 nut duoc giu tai 1 thoi diem** (cac nut khac tu mo/vo hieu hoa) vi ban than
mach 74HC595 chi luu duoc 1 trang thai 24-bit tai 1 thoi diem - dung y firmware goc cua ban.

---

## 3. Build app Flutter (lay file .apk de cai thu tren dien thoai)

Moi truong lam viec cua toi (phien lam viec dam may) da bi chan mang toi `pub.dev` va
`storage.googleapis.com` (noi luu Flutter/Dart SDK va thu vien) - da kiem tra truc tiep va xac
nhan khong ket noi duoc, nen **toi khong the tu bien dich ra file .apk trong phien nay**. Co 2
cach de ban tu lay duoc file .apk, chon 1 trong 2:

### Cach A - Dung GitHub Actions (khong can cai gi tren may, chi can tai khoan GitHub)

File `​.github/workflows/build-apk.yml` da co san trong goi ma nguon, se tu dong build APK tren
may chu cua GitHub (noi co day du mang toi pub.dev).

1. Tao 1 repository moi tren GitHub (public hay private deu duoc).
2. Push toan bo thu muc `hand_pendant_project/` (giu nguyen cau truc, bao gom ca thu muc
   `.github/`) len repo do. Vi du:
   ```bash
   cd hand_pendant_project
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin <URL_repo_cua_ban>
   git push -u origin main
   ```
3. Vao tab **Actions** tren trang GitHub cua repo → workflow "Build Android APK
   (hand_pendant_app)" se tu chay (mat khoang 5-8 phut). Neu khong thay tu chay, bam
   **Run workflow** thu cong.
4. Sau khi chay xong (dau tich xanh), mo lan chay do, keo xuong muc **Artifacts**, tai file
   `hand-pendant-app-debug-apk` ve - giai nen ra se thay file `app-debug.apk`.
5. Chep file `.apk` do vao dien thoai Android, bat "Cho phep cai dat tu nguon khong xac dinh"
   (Settings → Apps → tuy dien thoai) va cai nhu 1 app binh thuong. Day la ban **debug** (chua
   ky release) - chi de cai thu nghiem tren dien thoai ca nhan, khong dung de phat hanh chinh thuc.

Neu buoc "Tai thu vien" trong Actions bi loi (vi du khong tim thay dung phien ban
`flutter_blue_plus`), mo file log loi trong Actions, sua lai dong `flutter_blue_plus` trong
`app/pubspec.yaml` theo huong dan trong file do, roi push lai - workflow se tu chay lai.

### Cach B - Build tren may tinh ca nhan cua ban

### Chuan bi (lam 1 lan)
- Cai [Flutter SDK](https://docs.flutter.dev/get-started/install) (kenh stable), chay `flutter doctor`
  de kiem tra du dieu kien cho Android (Android Studio + SDK) va/hoac iOS (Xcode, chi tren macOS).

### Cac buoc build
```bash
cd app
flutter create .          # sinh thu muc android/ va ios/ chuan theo may ban
flutter pub get           # tai cac thu vien trong pubspec.yaml
```

Sau khi `flutter create .` chay xong:

1. **Android**: mo `android/app/src/main/AndroidManifest.xml`, dan noi dung trong
   `platform_config/AndroidManifest_additions.xml` vao ngay truoc the `<application ...>`.
   Mo `android/app/build.gradle`, dam bao `minSdkVersion` ≥ 21.
   Build APK test: `flutter build apk --debug` (file ra o
   `build/app/outputs/flutter-apk/app-debug.apk`, cai truc tiep vao dien thoai Android).

2. **iOS** (chi lam duoc tren macOS + Xcode): mo `ios/Runner/Info.plist`, dan noi dung trong
   `platform_config/Info_plist_additions.xml` vao truoc the `</dict>` cuoi cung. Mo
   `ios/Runner.xcworkspace` bang Xcode, chon Team ky (Signing & Capabilities), cam iPhone that
   qua cap va nhan Run (Bluetooth khong hoat dong duoc tren iOS Simulator, bat buoc phai dung
   may that).

### Chay thu khi dang phat trien
```bash
flutter run     # tu dong phat hien thiet bi/may ao dang cam, chi Android/desktop test duoc BLE that tren may that
```

### Neu gap loi bien dich lien quan goi `flutter_blue_plus`
`pubspec.yaml` dang khai bao `flutter_blue_plus: ^1.32.12` (chap nhan ban 1.x tu 1.32.12 tro len).
`lib/ble/ble_manager.dart` duoc viet theo API on dinh cua thu vien nay quanh phien ban do. Vi phien
lam viec cua toi khong co mang toi pub.dev nen khong tai/bien dich thu duoc - neu `flutter pub get`
chon phai 1 ban qua moi gay loi kieu "method/getter khong ton tai" (hoac loi tu GitHub Actions o
Cach A ben tren), cac ten hay bi doi giua cac phien ban cua thu vien nay la:
- `device.platformName` (co ban co the la `device.name` o ban rat cu)
- `advertisementData.advName` (co ban co the la `.localName` o ban rat cu)
- `BluetoothConnectionState` (enum trang thai ket noi)

Cach an toan nhat: giu nguyen phien ban da ghim (`1.32.12`) tru khi co ly do cu the de nang cap.

---

## 4. Cau truc man hinh app

- **Man hinh Quet/Ket noi**: xin quyen Bluetooth, quet thiet bi ten `MyESP32`, nham de ket noi.
- **Man hinh Dieu khien**: giao dien nut bam mo phong theo tay bam that, tu doi bo cuc theo loai
  pendant da chon (D760 co hang InstaDrive; D850 co hang Slide + Kidney), nut **DUNG KHAN CAP**
  mau do luon hien co dinh, banner mau bao trang thai ket noi o tren cung.
- **Man hinh Cai dat**: chon loai pendant (D760/D850, luu lai giua cac lan mo app), xem thong tin
  ket noi hien tai, xem thong so giao thuc, va ghi chu an toan.

---

## 5. GIOI HAN VA GIA DINH CAN BAN TU XAC NHAN (quan trong)

1. **4 nut moi cua D850** (`bt_SlideHead`, `bt_SlideFoot`, `bt_KidneyUp`, `bt_KidneyDown`) duoc
   toi gan tam vao 4 bit `RESERVE1..4` co san trong firmware goc cua ban (vi day la 4 bit duy
   nhat con trong trong ban do 24-bit). **Toi khong co so do mach phu tro that de doi chieu**, nen
   day chi la de xuat hop ly ve mat ky thuat, khong phai xac nhan da kiem tra phan cung. Truoc khi
   dung 4 nut nay tren ban mo D850 that, ban can tu kiem tra dung dau ra relay/opto nao dang noi
   voi 3 bit do tren mach cua ban, va dau ra do co that su di den dung chan tin hieu Slide/Kidney
   tren bo dieu khien chinh cua ban mo hay khong.
2. **Khong co duong doc trang thai nguoc ve app**: firmware hien tai la mach 1 chieu (chi ghi lenh
   xuong ban mo). Cac den bao AUX PENDANT / TABLE LIMIT / SERVICE va % pin tren tay bam that
   **khong the** hien thi tren app trong pham vi de xuat nay. Neu can, phai thiet ke them duong tin
   hieu doc (vi du doc chan LED qua opto-isolator) va dung BLE Notify de gui nguoc ve app - day la
   mot hang muc phat trien rieng, chua nam trong pham vi code nay.
3. **Khong ho tro nham dong thoi nhieu nut**: giong nhu gioi han cua firmware goc (chi luu 1 trang
   thai 24-bit tai 1 thoi diem qua 74HC595), app cung chi cho giu 1 nut tai 1 thoi diem.
4. **Watchdog 500ms** la gia tri de xuat ban dau, can dieu chinh dua tren do tre Bluetooth thuc te
   do duoc khi thu nghiem (do tre qua thap se gay dung nham giua chung khi dang di chuyen ban binh
   thuong; qua cao se lam giam hieu qua an toan khi that su mat ket noi).
5. **Bat buoc kiem thu ky truoc khi dua vao su dung lam sang**, tuan theo quy trinh quan ly rui ro
   / kiem dinh thiet bi y te noi bo cua don vi ban (day la thiet bi tac dong truc tiep den chuyen
   dong ban mo phau thuat).

---

## 6. Cac buoc de xuat tiep theo

- Han cheu Slide/Kidney: do dac/xac nhan so do bit thuc te tren mach phu tro, cap nhat lai bang
  `COMMAND_TABLE` trong firmware neu can.
- Thu nghiem do tre Bluetooth thuc te (dien thoai ↔ ESP32) o khoang cach su dung thuc te trong
  phong mo, dieu chinh `kHeartbeatInterval` (app) va `WATCHDOG_TIMEOUT_MS` (firmware) cho phu hop.
- Neu muon co canh bao pin yeu / trang thai loi tren app, can thiet ke them mach doc tin hieu va bo
  sung BLE Notify (hang muc phat trien them, chua co trong ban nay).
