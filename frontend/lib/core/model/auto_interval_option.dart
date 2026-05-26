enum AutoIntervalOption { s10, m1, m5 }

extension AutoIntervalOptionX on AutoIntervalOption {
  String get firebaseValue {
    switch (this) {
      case AutoIntervalOption.s10:
        return '10s';
      case AutoIntervalOption.m1:
        return '1m';
      case AutoIntervalOption.m5:
        return '5m';
    }
  }

  String get label {
    switch (this) {
      case AutoIntervalOption.s10:
        return '10s';
      case AutoIntervalOption.m1:
        return '1m';
      case AutoIntervalOption.m5:
        return '5m';
    }
  }

  static AutoIntervalOption fromFirebase(dynamic value) {
    switch (value) {
      case '10s':
        return AutoIntervalOption.s10;
      case '1m':
        return AutoIntervalOption.m1;
      case '5m':
        return AutoIntervalOption.m5;
      default:
        return AutoIntervalOption.s10;
    }
  }
}
