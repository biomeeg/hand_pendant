/*===========================================================================================
  Chuong trinh dieu khien ban mo ket noi khong day thong qua Bluetooth dua tren module ESP32
  ---------------------------------------------------------------------------------------------
  Phien ban: v2 - bo sung so voi firmware goc cua nguoi dung
    1. Watchdog an toan: neu khong nhan duoc tin hieu "giu phim" (heartbeat) tu app trong
       vong WATCHDOG_TIMEOUT_MS, tu dong mo relay (CLEAR) de dung chuyen dong ban mo.
       -> Xu ly truong hop mat ket noi Bluetooth (rot song, tat app, het pin dien thoai...)
          trong luc dang giu phim di chuyen ban.
    2. Xu ly su kien BLE disconnect: mo relay ngay lap tuc + khoi dong lai advertising.
    3. Bo sung ma lenh cho model D850 (SLIDE HEAD/FOOT, KIDNEY UP/DOWN) tai dung 4 bit
       RESERVE dang co san trong ban do bit goc.
       *** QUAN TRONG: ban PHAI tu kiem tra lai xem 4 bit RESERVE nay co dung la 4 dau ra
       relay/opto con trong tren mach phu tro cua ban khong, va dau ra do co noi dung
       chan tuong ung voi chuc nang Slide Head/Foot, Kidney Up/Down tren bo dieu khien
       chinh cua ban mo hay khong. Toi khong co so do phan cung that de doi chieu, nen
       day chi la de xuat anh xa bit - can ban xac nhan truoc khi nap firmware nay vao
       thiet bi dang gan voi ban mo that. ***
    4. Sua loi SERIAL_NO dung nhay don sai cu phap (chuoi ky tu phai dung nhay kep).
    5. Gom cac ma lenh vao 1 bang tra cuu (struct) thay vi chuoi if/else lap lai, de de
       bao tri / mo rong sau nay.
=============================================================================================*/

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

//-----------------------------------------
// Chan dieu khien 74HC595 (giu nguyen nhu firmware goc)
//-----------------------------------------
#define SER_0       18
#define SHIFT_CLK   19
#define LATCH_CLK   21
#define OE_CTL      22
#define RESET_595   23

//-----------------------------------------
#define SERIAL_NO "Z10464"   // sua loi cu phap: chuoi ky tu phai dung nhay kep

//-----------------------------------------
// Thoi gian toi da cho phep khong nhan duoc heartbeat truoc khi tu dong dung (ms)
// App se gui lai dung lenh bt_XXX dinh ky (khuyen nghi 150ms/lan) trong luc con giu phim.
// Gia tri nay PHAI lon hon chu ky gui lai cua app (>= 2-3 lan) de tranh dung nham do do tre
// mang Bluetooth binh thuong, nhung cung khong duoc qua lon vi se lam giam tinh an toan.
//-----------------------------------------
#define WATCHDOG_TIMEOUT_MS  500

//===================================================================
// Ban do lenh -> trang thai relay (3 byte, dua vao 74HC595 x3, MSB first)
//===================================================================
struct PendantCommand {
  const char *name;
  byte bits[3];
};

const byte CLEAR_BITS[3] = {0x00, 0x00, 0x00};

const PendantCommand COMMAND_TABLE[] = {
  // ---- Cac lenh dung chung cho ca D760 va D850 ----
  {"bt_Power",            {0x00, 0x00, 0x01}},
  {"bt_FloorLock",        {0x00, 0x00, 0x02}},
  {"bt_RevPosition",      {0x00, 0x00, 0x04}},
  {"bt_BackUp",           {0x00, 0x00, 0x20}},
  {"bt_TableUp",          {0x00, 0x00, 0x40}},
  {"bt_LegUp",            {0x00, 0x00, 0x80}},
  {"bt_BackDown",         {0x00, 0x01, 0x00}},
  {"bt_TableDown",        {0x00, 0x02, 0x00}},
  {"bt_LegDown",          {0x00, 0x04, 0x00}},
  {"bt_SplitLegLeftUp",   {0x00, 0x08, 0x80}},
  {"bt_SplitLegLeftDown", {0x00, 0x0C, 0x00}},
  {"bt_SplitLegRightUp",  {0x00, 0x10, 0x80}},
  {"bt_SplitLegRightDown",{0x00, 0x14, 0x00}},
  {"bt_TrendTrend",       {0x00, 0x20, 0x00}},
  {"bt_TrendRev",         {0x00, 0x40, 0x00}},
  {"bt_TiltLeft",         {0x02, 0x00, 0x00}},
  {"bt_TiltRight",        {0x04, 0x00, 0x00}},
  {"bt_PresetFlex",       {0x20, 0x00, 0x00}},
  {"bt_PresetChair",      {0x40, 0x00, 0x00}},
  {"bt_Level",            {0x80, 0x00, 0x00}},

  // ---- Chi co tren D760 (InstaDrive) ----
  {"bt_InstaDriveREV",    {0x00, 0x00, 0x08}},
  {"bt_InstaDriveFWD",    {0x00, 0x00, 0x10}},

  // ---- Chi co tren D850 (Slide / Kidney) - dung lai 4 bit RESERVE1..4 cua firmware goc ----
  // *** CAN XAC NHAN PHAN CUNG - xem ghi chu dau file ***
  {"bt_SlideHead",        {0x00, 0x80, 0x00}},  // truoc la RESERVE1_ON
  {"bt_SlideFoot",        {0x01, 0x00, 0x00}},  // truoc la RESERVE2_ON
  {"bt_KidneyUp",         {0x08, 0x00, 0x00}},  // truoc la RESERVE3_ON
  {"bt_KidneyDown",       {0x10, 0x00, 0x00}},  // truoc la RESERVE4_ON
};
const int COMMAND_COUNT = sizeof(COMMAND_TABLE) / sizeof(COMMAND_TABLE[0]);

//===================================================================
// Trang thai
//===================================================================
String bt_Read = "";              // du lieu moi nhat nhan tu BLE, xu ly trong loop()
String currentActiveCmd = "";     // ten lenh dang "giu" (dong relay), rong = khong co
unsigned long lastRxMillis = 0;   // thoi diem nhan tin hieu (lenh hoac heartbeat) gan nhat
bool deviceConnected = false;

BLEServer *pServer = nullptr;
BLEAdvertising *pAdvertising = nullptr;

// See the following for generating UUIDs:
// https://www.uuidgenerator.net/
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

//===================================================================
void shift_array(const byte *array) {
  digitalWrite(LATCH_CLK, LOW);
  for (byte i = 0; i <= 2; i++) {
    shiftOut(SER_0, SHIFT_CLK, MSBFIRST, array[i]);
  }
  digitalWrite(LATCH_CLK, HIGH);
  delay(1);
  digitalWrite(LATCH_CLK, LOW);
  delay(1);
}

//===================================================================
void safetyStopRelays() {
  shift_array(CLEAR_BITS);
  currentActiveCmd = "";
}

//===================================================================
// Tim lenh trong bang tra cuu theo ten, tra ve con tro bits hoac nullptr neu khong thay
//===================================================================
const byte *findCommandBits(const String &name) {
  for (int i = 0; i < COMMAND_COUNT; i++) {
    if (name.equals(COMMAND_TABLE[i].name)) {
      return COMMAND_TABLE[i].bits;
    }
  }
  return nullptr;
}

//===================================================================
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServerParam) override {
    deviceConnected = true;
    Serial.println("[BLE] Da ket noi voi app dieu khien");
  }

  void onDisconnect(BLEServer *pServerParam) override {
    deviceConnected = false;
    Serial.println("[BLE] Mat ket noi - tu dong dung moi chuyen dong (safety stop)");
    // An toan: mat ket noi giua chung khi dang giu phim -> mo relay ngay
    safetyStopRelays();
    // Khoi dong lai quang ba de app co the ket noi lai
    delay(200);
    pServerParam->getAdvertising()->start();
  }
};

//===================================================================
class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    String value = pCharacteristic->getValue();
    if (value.length() > 0) {
      bt_Read = value;
      Serial.print("[BLE] Nhan lenh: ");
      Serial.println(bt_Read);
    }
  }
};

//===========================================================
void setup() {
  //---------------------------------
  pinMode(SER_0, OUTPUT);
  pinMode(SHIFT_CLK, OUTPUT);
  pinMode(LATCH_CLK, OUTPUT);
  pinMode(OE_CTL, OUTPUT);
  pinMode(RESET_595, OUTPUT);
  digitalWrite(RESET_595, LOW); // reset 595
  digitalWrite(SER_0, LOW);
  digitalWrite(SHIFT_CLK, LOW);
  digitalWrite(LATCH_CLK, LOW);
  digitalWrite(RESET_595, HIGH);
  digitalWrite(OE_CTL, LOW);
  safetyStopRelays(); // dam bao trang thai ban dau la "khong bam phim nao"
  //---------------------------------
  Serial.begin(115200);
  Serial.print("Firmware bo dieu khien khong day - Serial: ");
  Serial.println(SERIAL_NO);
  //---------------------------------
  BLEDevice::init("MyESP32");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  BLECharacteristic *pCharacteristic =
      pService->createCharacteristic(CHARACTERISTIC_UUID,
                                      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->setValue("Hello World");
  pService->start();

  pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID); // giup app loc thiet bi theo Service UUID khi quet
  pAdvertising->start();

  lastRxMillis = millis();
}

//==================================================================
void loop() {
  //--------------------------------
  // 1) Xu ly lenh moi nhan tu BLE (neu co)
  //--------------------------------
  if (bt_Read.length() > 0) {
    String cmd = bt_Read;
    bt_Read = "";

    if (cmd == "bt_Stop") {
      safetyStopRelays();
    } else {
      const byte *bits = findCommandBits(cmd);
      if (bits != nullptr) {
        shift_array(bits);
        currentActiveCmd = cmd;
        lastRxMillis = millis(); // reset watchdog moi khi nhan lenh/heartbeat hop le
      } else {
        Serial.print("[WARN] Lenh khong xac dinh: ");
        Serial.println(cmd);
      }
    }
  }

  //--------------------------------
  // 2) Watchdog an toan: dang giu 1 lenh ma lau khong thay heartbeat -> tu dong dung
  //--------------------------------
  if (currentActiveCmd.length() > 0 && (millis() - lastRxMillis > WATCHDOG_TIMEOUT_MS)) {
    Serial.println("[SAFETY] Watchdog timeout - tu dong mo relay (khong nhan duoc heartbeat)");
    safetyStopRelays();
  }
}
//===========================================================================
//----------------------------------End--------------------------------------
//===========================================================================
