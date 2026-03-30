enum VehicleAction {
  openHoodEng,
  openHoodInd,
  openHoodJpn,
  openTrunkEng,
  openTrunkInd,
  openTrunkJpn,
}

class VideoAssets {
  VideoAssets._();

  static const Map<VehicleAction, String> actionVideoMap = {
    VehicleAction.openHoodEng: 'assets/video/BukaKapMobil_eng.mp4',
    VehicleAction.openHoodInd: 'assets/video/BukaKapMobil_Indo.mp4',
    VehicleAction.openHoodJpn: 'assets/video/BukaKapMobil_jpn.mp4',
    VehicleAction.openTrunkEng: 'assets/video/BukaTutupTangki_eng.mp4',
    VehicleAction.openTrunkInd: 'assets/video/BukaTutupTangki_Indo.mp4',
    VehicleAction.openTrunkJpn: 'assets/video/BukaTutupTangki_jpn.mp4',
  };

  static VehicleAction? fromString(String action) {
    switch (action) {
      case 'OPEN_HOOD_ENG':
        return VehicleAction.openHoodEng;
      case 'OPEN_HOOD_IND':
        return VehicleAction.openHoodInd;
      case 'OPEN_HOOD_JPN':
        return VehicleAction.openHoodJpn;
      case 'OPEN_TRUNK_ENG':
        return VehicleAction.openTrunkEng;
      case 'OPEN_TRUNK_IND':
        return VehicleAction.openTrunkInd;
      case 'OPEN_TRUNK_JPN':
        return VehicleAction.openTrunkJpn;
      default:
        return null;
    }
  }
}
