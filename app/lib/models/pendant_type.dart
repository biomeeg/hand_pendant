/// Hai bo phim vat ly tuong ung 2 model ban mo ma nguoi dung can ho tro.
///
/// D760: co hang InstaDrive (REV/FWD), KHONG co Slide / Kidney.
/// D850: co hang Slide (Head/Foot) va Kidney (Up/Down), KHONG co InstaDrive.
/// Cac nut con lai (Power, Floor Lock, Rev Position, Back/Table/Leg, Split Leg,
/// Trend, Tilt, Preset, Level) giong nhau tren ca hai model.
enum PendantType {
  d760,
  d850,
}

extension PendantTypeX on PendantType {
  String get label {
    switch (this) {
      case PendantType.d760:
        return 'D760 (co InstaDrive)';
      case PendantType.d850:
        return 'D850 (co Slide / Kidney)';
    }
  }

  String get storageValue => name;

  static PendantType fromStorage(String? value) {
    switch (value) {
      case 'd850':
        return PendantType.d850;
      case 'd760':
      default:
        return PendantType.d760;
    }
  }
}
