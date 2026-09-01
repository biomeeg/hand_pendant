"""Kiem tra minSdkVersion trong android/app/build.gradle(.kts) sinh ra boi
`flutter create .` trong CI (xem .github/workflows/build-apk.yml). Thu vien
flutter_blue_plus can minSdkVersion >= 21.

Tach thanh file rieng (thay vi nhung truc tiep trong workflow YAML bang heredoc)
de tranh loi thut le (indentation) khi chinh sua truc tiep tren web GitHub.
"""

import re

PRIMARY_PATH = "android/app/build.gradle"
FALLBACK_PATH = "android/app/build.gradle.kts"


def main():
    try:
        with open(PRIMARY_PATH, "r", encoding="utf-8") as f:
            content = f.read()
        path = PRIMARY_PATH
    except FileNotFoundError:
        with open(FALLBACK_PATH, "r", encoding="utf-8") as f:
            content = f.read()
        path = FALLBACK_PATH

    # Neu du an dang dung flutter.minSdkVersion (mac dinh moi cua Flutter template)
    # thi khong can sua gi - ban than gia tri do da >= 21 tu lau. Chi canh bao neu
    # thay 1 con so cu the nho hon 21 duoc ghi cung trong file.
    match = re.search(r"minSdk(Version)?\s*=?\s*(\d+)", content)
    if match and int(match.group(2)) < 21:
        print(f"CANH BAO: minSdkVersion dang la {match.group(2)}, thu vien BLE can >= 21. "
              f"Vui long tu sua file {path}.")
    else:
        print("minSdkVersion on, khong can sua.")


if __name__ == "__main__":
    main()
