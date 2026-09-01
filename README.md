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
| Ten thiet bi quang ba | Mac dinh `MyESP32`, co the doi (xem muc 8) - ten hien tai luon la ten THAT ma thiet bi quang ba, ai quet Bluetooth cung thay duoc |
| Service UUID | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| Characteristic UUID (Ghi lenh + Notify phan hoi) | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| Chieu du lieu chinh | App → ESP32 (ghi text thuan, vi du `bt_TableUp`) |
| Chieu phan hoi (BLE Notify, tu ban v3) | ESP32 → App, chi dung cho ket qua lenh Auth/SetPass/SetName (vi du `AUTH_OK`) |
| Chu ky heartbeat cua app | 150ms trong luc con giu 1 nut |
| Watchdog cua ESP32 | 500ms khong nhan duoc lenh → tu mo relay |

### Lenh xac thuc / bao mat (tu ban v3)

| Lenh app gui | Y nghia | Firmware phan hoi (qua Notify) |
|---|---|---|
| `bt_Auth:<mat_khau>` | Xac thuc cho phien ket noi BLE hien tai | `AUTH_OK` hoac `AUTH_FAIL` |
| `bt_SetPass:<mat_khau_cu>:<mat_khau_moi>` | Doi mat khau ket noi (yeu cau da `AUTH_OK` truoc) | `PASS_OK` hoac `PASS_FAIL` |
| `bt_SetName:<ten_moi>` | Doi ten quang ba BLE (yeu cau da `AUTH_OK` truoc); ESP32 luu ten roi **tu khoi dong lai** de quang ba ten moi | `NAME_OK` hoac `NAME_FAIL` |

Firmware **tu dat lai trang thai "chua xac thuc" moi khi co 1 ket noi BLE moi** (kem ca sau khi doi
ten va tu khoi dong lai) - app phai gui lai `bt_Auth:` sau moi lan ket noi/ket noi lai (app da tu
dong lam viec nay bang mat khau da luu tren dien thoai). Lenh `bt_Stop` la **ngoai le duy nhat**:
luon duoc firmware chap nhan bat ke da xac thuc hay chua, vi day chi la lenh mo relay (an toan),
khong bao gio la hanh dong dieu khien nguy hiem.

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
- **Man hinh Dieu khien**: giao dien nut bam mo phong theo tay bam that (thu nho de vua 1 man hinh,
  khong can keo), tu doi bo cuc theo loai pendant da chon (D760 co hang InstaDrive; D850 co hang
  Slide + Kidney), nut **DUNG KHAN CAP** mau do luon hien co dinh va luon bam duoc ngay khi co ket
  noi (ke ca truoc khi nhap mat khau), banner mau bao trang thai ket noi o tren cung. Neu da ket
  noi BLE nhung **chua xac thuc mat khau**, man hinh hien 1 o nhap mat khau thay cho cac nut dieu
  khien (xem muc 8).
- **Man hinh Cai dat**: chon loai pendant (D760/D850, luu lai giua cac lan mo app), xem thong tin
  ket noi hien tai, **doi mat khau ket noi**, **doi ten thiet bi (rieng cho admin)**, xem thong so
  giao thuc, va huong dan thiet lap/su dung (xem muc 8).

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

---

## 8. Mat khau ket noi, doi ten thiet bi va giao dien 1 man hinh (v3)

Ban nay bo sung 3 thay doi theo yeu cau: (1) bo cac ghi chu/canh bao khong con phu hop tren man
hinh Dieu khien va Cai dat, (2) yeu cau mat khau de ket noi/dieu khien (khoa that trong firmware,
khong phai chi khoa tren app), (3) tinh nang doi ten thiet bi rieng cho admin, va (4) thu nho giao
dien Dieu khien de vua het cac nut tren 1 man hinh.

### 8.1 Mat khau ket noi (khoa o FIRMWARE, khong phai chi o app)

- Khi ESP32 khoi dong lan dau (chua tung doi mat khau), mat khau ket noi mac dinh la **`0000`**.
- Sau khi app ket noi BLE, man hinh Dieu khien se hien 1 o nhap mat khau **truoc khi** cho thao tac
  bat ky nut dieu khien nao (tru nut DUNG KHAN CAP - luon mo). App gui lenh `bt_Auth:<mat_khau>`,
  firmware kiem tra va tra loi `AUTH_OK`/`AUTH_FAIL` qua BLE Notify.
- Vi kiem tra nam trong firmware (khong phai trong app), **khong the bo qua** bang cach sua/thay
  app khac - bat ky ai muon gui lenh dieu khien xuong ban mo qua thiet bi nay deu phai qua duoc
  buoc nay.
- Nen doi mat khau `0000` mac dinh ngay sau lan ket noi dau tien, tai man hinh Cai dat → "Bao mat
  ket noi" → nhap mat khau hien tai + mat khau moi → gui lenh `bt_SetPass:<cu>:<moi>`, firmware luu
  mat khau moi vao bo nho flash (NVS qua thu vien `Preferences`) nen **giu nguyen sau khi mat dien/
  khoi dong lai ESP32**.
- App tu luu mat khau da xac thuc thanh cong tren dien thoai va **tu dong xac thuc lai** moi khi
  ket noi lai (mo app lai, hoac Bluetooth vua mat roi noi lai) - khong phai nhap tay moi lan, tru
  khi vua doi mat khau hoac dang dung dien thoai/thiet bi khac ket noi lan dau.
- Firmware **luon dat lai ve trang thai chua xac thuc** moi khi co 1 ket noi BLE hoan toan moi -
  day la thiet ke co chu dich, dam bao 1 phien ket noi cu (vi du bi ngat rot) khong the "tiep tuc"
  dieu khien ma khong xac thuc lai.

### 8.2 Doi ten thiet bi (chi danh cho admin)

- Muc "Doi ten thiet bi (Admin)" trong Cai dat bi khoa sau 1 **mat khau admin rieng, co dinh trong
  ma nguon app**: `admin123`. Day la 1 lop an kin de tranh nguoi dung thong thuong vo tinh bam vao
  va doi nham ten thiet bi, **khong phai bien phap bao mat manh** - bat ky ai doc duoc ma nguon
  hoac giai nen file APK deu co the tim thay chuoi nay (xem chu thich chi tiet trong
  `app/lib/ble/pendant_protocol.dart`, hang so `kAdminUnlockPassword`). Neu can bao mat that su cho
  tinh nang nay, phai doi hang so do va bien dich/build lai APK truoc khi phat cho nguoi khac dung.
- Sau khi nhap dung mat khau admin va mat khau ket noi da duoc xac thuc (`AUTH_OK`), admin nhap ten
  moi (toi da 20 ky tu) va gui lenh `bt_SetName:<ten_moi>`. Firmware luu ten vao flash roi
  **tu khoi dong lai** de quang ba (advertise) BLE bang ten moi - day la hanh vi du kien, khong
  phai loi (thu vien BLE cua ESP32 chi doc ten quang ba on dinh tu luc khoi dong).
- Ten moi la ten quang ba BLE **that su** - bat ky thiet bi nao quet Bluetooth gan do (dien thoai
  khac, app do BLE...) deu se thay ten moi nay, giong het nhu doi ten bat ky thiet bi Bluetooth
  nao khac. Tuy nhien, **doi ten khong lam doi hay bo qua yeu cau mat khau ket noi** - ai quet thay
  ten moi va thu ket noi/dieu khien van phai nhap dung mat khau ket noi hien tai (muc 8.1).
- Sau khi doi ten, ket noi BLE hien tai se roi vao trang thai mat ket noi trong vai giay (do ESP32
  dang khoi dong lai) - app hien nut tat "Ve man hinh quet lai" de nguoi dung quet va ket noi lai
  voi thiet bi mang ten moi.

### 8.3 Giao dien Dieu khien vua 1 man hinh

Theo yeu cau, cac nut va khoang cach tren man hinh Dieu khien duoc thu nho (duong kinh nut giam,
co chu nho hon, giam khoang cach doc) de toan bo cac hang nut cua ca 2 loai pendant (D760/D850)
vua hien thi tren 1 man hinh dien thoai pho thong ma khong can keo len/xuong. Tuy nhien man hinh
van duoc boc trong `SingleChildScrollView` de du phong cho man hinh rat nho hoac nguoi dung phong
to chu he thong (accessibility) - trong dieu kien binh thuong se khong can keo.

**Luu y:** cac thay doi trong muc 8 nay (auth firmware, doi ten, giao dien) **chua duoc build/nap
thu thuc te trong phien lam viec nay** (khong co trinh bien dich Dart/Arduino trong moi truong
sandbox) - da ra soat ky tung dong ma nguon thu cong nhung ban can: (1) nap lai firmware `.ino`
moi vao ESP32 bang Arduino IDE, (2) push code app moi len GitHub va cho Actions build lai APK
(Cach A, muc 3), (3) **kiem thu ky luong Auth/doi mat khau/doi ten tren ban khong co benh nhan**
truoc khi tin tuong dua vao su dung thuc te, dung tinh than muc 5 va 7 o tren.

---

## 7. Nhat ky sua loi

| Ngay | Loi | Nguyen nhan | Cach sua |
|---|---|---|---|
| 2026-08-19 | GitHub Actions bao do `Build APK (debug)`: `Error parsing LocalFile: ... AndroidManifest.xml ... Please ensure that the android manifest is a valid XML document` | Buoc "Chen quyen Bluetooth vao AndroidManifest.xml" trong `.github/workflows/build-apk.yml` dung `additions_full.find("<uses-permission")` de tim diem bat dau noi dung can chen. Nhung chinh khoi comment huong dan o dau file `platform_config/AndroidManifest_additions.xml` co cau vi du chua dung chuoi `<uses-permission ...>`, nen `.find()` bi "danh lua", cat nham ngay giua khoi comment huong dan - lam manifest sinh ra bi hong cu phap XML (comment khong dong dung). | Doi cach xac dinh diem bat dau: lay noi dung SAU dau `-->` DAU TIEN cua file additions (thay vi tim chuoi `<uses-permission`), dam bao luon bo qua trom ven khoi comment huong dan o dau file. |
| 2026-09-01 | Sau khi tu sua truc tiep tren web GitHub, buoc "Chen quyen Bluetooth vao AndroidManifest.xml" bao `IndentationError: unexpected indent` tai dong `marker_end = additions_full.find("-->")`, that bai ngay lap tuc (0s). | Doan code sua o tren duoc nhung truc tiep trong YAML bang `python3 - <<'PYEOF' ... PYEOF` (heredoc), nen phai giu dung 2 lop thut le cung luc: thut le cua khoi `run: \|` trong YAML VA thut le cua chinh cau lenh Python. Khi dan de chinh sua tay tren trinh soan thao web cua GitHub, chi can lech 1 khoang trang la Python bao loi ngay. | Tach hoan toan 2 doan Python nhung trong workflow ra thanh 2 file rieng: `app/scripts/patch_manifest_permissions.py` va `app/scripts/check_min_sdk.py` (thut le binh thuong, khong con heredoc). File `.github/workflows/build-apk.yml` gio chi goi `python3 scripts/patch_manifest_permissions.py` va `python3 scripts/check_min_sdk.py` - moi lan can sua chi phai dan de toan bo 1 file `.py` doc lap, khong con phai giu dung 2 lop thut le long nhau nhu truoc. |
| 2026-09-01 | Sau khi qua duoc 2 buoc chen quyen/check minSdk, buoc `Build APK (debug)` bao `FAILURE: Build completed with 2 failures`: `Could not get unknown property 'flutter' for extension 'android' of type com.android.build.gradle.LibraryExtension` va `compileSdkVersion is not specified. Please add it to build.gradle`, loi tai file cua thu vien `flutter_blue_plus_android-7.0.4` trong `.pub-cache`. | Workflow ghim cung `flutter-version: '3.24.5'`. Cac thu vien nhu `flutter_blue_plus_android` da cap nhat theo co che nap Flutter Gradle plugin kieu moi (chi ho tro tu Flutter 3.27 tro len). Dung Flutter 3.24.5 (cu hon) khien `flutter create` sinh ra project Android theo dinh dang Gradle cu, khong tuong thich - day la loi da duoc xac nhan tren chinh kho GitHub cua Flutter (xem `flutter/flutter#164362`, `fluttercommunity/plus_plugins#3742`). | Bo han dong ghim `flutter-version: '3.24.5'` trong buoc "Cai dat Flutter SDK", chi giu `channel: 'stable'` de CI luon dung ban Flutter stable moi nhat (tinh den 09/2026 la ban 3.47.x, da qua moc 3.27 can thiet). |
