class DriverPreference {
  final String name;        // 🔑 internal key (lowercase)
  final String displayName; // 🎨 UI + backend (original)

  final int fanLevel;
  final int temperature;
  final int cartridge;
  final int themeIndex;

  DriverPreference({
    required this.name,
    required this.displayName,
    required this.fanLevel,
    required this.temperature,
    required this.cartridge,
    required this.themeIndex,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "displayName": displayName,
        "fanLevel": fanLevel,
        "temperature": temperature,
        "cartridge": cartridge,
        "themeIndex": themeIndex,
      };

  factory DriverPreference.fromJson(Map<String, dynamic> json) {
    return DriverPreference(
      name: json["name"],
      displayName: json["displayName"] ?? json["name"],
      fanLevel: json["fanLevel"],
      temperature: json["temperature"],
      cartridge: json["cartridge"],
      themeIndex: json["themeIndex"],
    );
  }
}