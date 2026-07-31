enum AutoInterval {
  seconds10('10 sec', '10s'),
  minute1('1 min', '1m'),
  minutes5('5 min', '5m');

  const AutoInterval(this.label, this.mqttValue);

  final String label;
  final String mqttValue;

  static AutoInterval fromMqtt(Object? value) {
    return AutoInterval.values.firstWhere(
      (interval) => interval.mqttValue == value,
      orElse: () => AutoInterval.seconds10,
    );
  }
}

class FragranceState {
  const FragranceState({
    this.mainPower = false,
    this.autoMode = false,
    this.coffeeEnabled = false,
    this.lavenderEnabled = false,
    this.coffeeSpeed = 2,
    this.lavenderSpeed = 1,
    this.autoInterval = AutoInterval.seconds10,
    this.hasPendingChanges = false,
  });

  final bool mainPower;
  final bool autoMode;
  final bool coffeeEnabled;
  final bool lavenderEnabled;
  final int coffeeSpeed;
  final int lavenderSpeed;
  final AutoInterval autoInterval;
  final bool hasPendingChanges;

  factory FragranceState.fromMqtt(
    Map<String, dynamic> data, {
    FragranceState fallback = const FragranceState(),
  }) {
    final motor1 = data['motor1'];
    final motor2 = data['motor2'];

    return FragranceState(
      mainPower: data['mainPower'] is bool
          ? data['mainPower'] as bool
          : fallback.mainPower,
      autoMode: data['autoMode'] is bool
          ? data['autoMode'] as bool
          : fallback.autoMode,
      coffeeEnabled: motor1 is Map && motor1['enabled'] is bool
          ? motor1['enabled'] as bool
          : fallback.coffeeEnabled,
      lavenderEnabled: motor2 is Map && motor2['enabled'] is bool
          ? motor2['enabled'] as bool
          : fallback.lavenderEnabled,
      coffeeSpeed: _readSpeed(motor1, fallback.coffeeSpeed),
      lavenderSpeed: _readSpeed(motor2, fallback.lavenderSpeed),
      autoInterval: data['autoInterval'] == null
          ? fallback.autoInterval
          : AutoInterval.fromMqtt(data['autoInterval']),
      hasPendingChanges: false,
    );
  }

  FragranceState copyWith({
    bool? mainPower,
    bool? autoMode,
    bool? coffeeEnabled,
    bool? lavenderEnabled,
    int? coffeeSpeed,
    int? lavenderSpeed,
    AutoInterval? autoInterval,
    bool? hasPendingChanges,
  }) {
    return FragranceState(
      mainPower: mainPower ?? this.mainPower,
      autoMode: autoMode ?? this.autoMode,
      coffeeEnabled: coffeeEnabled ?? this.coffeeEnabled,
      lavenderEnabled: lavenderEnabled ?? this.lavenderEnabled,
      coffeeSpeed: coffeeSpeed ?? this.coffeeSpeed,
      lavenderSpeed: lavenderSpeed ?? this.lavenderSpeed,
      autoInterval: autoInterval ?? this.autoInterval,
      hasPendingChanges: hasPendingChanges ?? this.hasPendingChanges,
    );
  }

  Map<String, dynamic> toMqtt() {
    return {
      'selectedCartridge': selectedCartridge,
      'mainPower': mainPower,
      'autoMode': autoMode,
      'autoInterval': autoInterval.mqttValue,
      'motor1': {
        'enabled': coffeeEnabled,
        'speedLevel': coffeeSpeed,
      },
      'motor2': {
        'enabled': lavenderEnabled,
        'speedLevel': lavenderSpeed,
      },
    };
  }

  int get selectedCartridge {
    if (coffeeEnabled && lavenderEnabled) return 3;
    if (coffeeEnabled) return 1;
    if (lavenderEnabled) return 2;
    return 0;
  }

  static int _readSpeed(Object? motor, int fallback) {
    if (motor is! Map || motor['speedLevel'] is! num) return fallback;
    return (motor['speedLevel'] as num).toInt().clamp(1, 3);
  }
}
