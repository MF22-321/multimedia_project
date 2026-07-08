class FragranceControlPayload {
  static Map<String, dynamic> forCartridge(int cartridge) {
    switch (cartridge) {
      case 3:
        return _payload(cartridge: 3, coffee: true, lavender: true);
      case 1:
        return _payload(cartridge: 1, coffee: true, lavender: false);
      case 2:
        return _payload(cartridge: 2, coffee: false, lavender: true);
      default:
        return _payload(cartridge: 0, coffee: false, lavender: false);
    }
  }

  static Map<String, dynamic> _payload({
    required int cartridge,
    required bool coffee,
    required bool lavender,
  }) {
    return {
      'selectedCartridge': cartridge,
      'mainPower': coffee || lavender,
      'autoMode': false,
      'motor1': {'enabled': coffee, 'speedLevel': coffee ? 3 : 1},
      'motor2': {'enabled': lavender, 'speedLevel': lavender ? 3 : 1},
    };
  }
}
