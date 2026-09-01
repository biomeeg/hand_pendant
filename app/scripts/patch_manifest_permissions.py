"""Chen cac dong <uses-permission>/<uses-feature> Bluetooth vao AndroidManifest.xml
sinh ra boi `flutter create .` trong CI (xem .github/workflows/build-apk.yml).

Duoc tach thanh file rieng (thay vi nhung truc tiep trong workflow YAML bang heredoc)
de tranh loi thut le (indentation) rat de xay ra khi chinh sua truc tiep tren trinh
soan thao web cua GitHub - moi lan sua chi can dan de bai toan bo noi dung file nay,
khong con phai giu dung 2 lop thut le (YAML + Python) cung luc nhu truoc.
"""

MANIFEST_PATH = "android/app/src/main/AndroidManifest.xml"
ADDITIONS_PATH = "platform_config/AndroidManifest_additions.xml"


def main():
    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        manifest = f.read()

    with open(ADDITIONS_PATH, "r", encoding="utf-8") as f:
        additions_full = f.read()

    # Bo khoi comment huong dan o dau file additions: lay phan noi dung SAU dau
    # '-->' DAU TIEN. (Khong tim chuoi "<uses-permission" de xac dinh diem bat dau,
    # vi chinh khoi comment huong dan cung chua vi du chuoi do trong cau chu, khien
    # cach tim cu bi "danh lua" cat nham ngay giua khoi comment.)
    marker_end = additions_full.find("-->")
    if marker_end != -1:
        additions = additions_full[marker_end + 3:].strip()
    else:
        additions = additions_full.strip()

    if "BLUETOOTH_SCAN" in manifest:
        print("Manifest da co quyen Bluetooth, bo qua buoc chen.")
        return

    manifest = manifest.replace("<application", additions + "\n\n    <application", 1)
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        f.write(manifest)
    print("Da chen quyen Bluetooth vao AndroidManifest.xml")


if __name__ == "__main__":
    main()
