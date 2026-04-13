class DriverPreference {
  final String name;
  final int fanLevel;
  final int temperature;
  final int cartridge;
  final int themeIndex;

  DriverPreference({
    required this.name,
    required this.fanLevel,
    required this.temperature,
    required this.cartridge,
    required this.themeIndex,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "fanLevel": fanLevel,
        "temperature": temperature,
        "cartridge": cartridge,
        "themeIndex": themeIndex,
      };

  factory DriverPreference.fromJson(Map<String, dynamic> json) {
    return DriverPreference(
      name: json["name"],
      fanLevel: json["fanLevel"],
      temperature: json["temperature"],
      cartridge: json["cartridge"],
      themeIndex: json["themeIndex"],
    );
  }
}