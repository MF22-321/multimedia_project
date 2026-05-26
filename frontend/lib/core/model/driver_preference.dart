class DriverPreference {
  final String name; // 🔑 internal key (lowercase)
  final String displayName; // 🎨 UI + backend (original)

  final int fanLevel;
  final int temperature;
  final int cartridge;
  final int themeIndex;
  final String languageCode;

  DriverPreference({
    required this.name,
    required this.displayName,
    required this.fanLevel,
    required this.temperature,
    required this.cartridge,
    required this.themeIndex,
    this.languageCode = "id",
  });

  Map<String, dynamic> toJson() => {
    "name": name,
    "displayName": displayName,
    "fanLevel": fanLevel,
    "temperature": temperature,
    "cartridge": cartridge,
    "themeIndex": themeIndex,
    "languageCode": languageCode,
  };

  factory DriverPreference.fromJson(Map<String, dynamic> json) {
    final rawLanguage = (json["languageCode"] ?? json["language"] ?? "id")
        .toString()
        .toLowerCase();

    return DriverPreference(
      name: json["name"] ?? "",
      displayName: json["displayName"] ?? json["name"] ?? "Guest",
      fanLevel: json["fanLevel"] ?? 3,
      temperature: json["temperature"] ?? 19,
      cartridge: json["cartridge"] ?? 2,
      themeIndex: json["themeIndex"] ?? 0,
      languageCode: rawLanguage == "en" ? "en" : "id",
    );
  }
}
