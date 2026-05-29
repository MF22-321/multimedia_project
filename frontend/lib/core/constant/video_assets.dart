enum VehicleAction {
  openHoodEng,
  openHoodInd,
  openHoodJpn,
  openTrunkEng,
  openTrunkInd,
  openTrunkJpn,
  checkOilLevel,
  changeTire,
  useFireExtinguisher,
  helpAccident,
}

class VideoAssets {
  VideoAssets._();

  static const Map<VehicleAction, String> actionVideoMap = {
    VehicleAction.openHoodEng: 'assets/video_sdr/BukaKapMobil_eng_sdr.mp4',
    VehicleAction.openHoodInd: 'assets/video_sdr/BukaKapMobil_Indo_sdr.mp4',
    VehicleAction.openHoodJpn: 'assets/video_sdr/BukaKapMobil_jpn_sdr.mp4',
    VehicleAction.openTrunkEng:
        'assets/video_sdr/BukaTutupTangki_eng_sdr.mp4',
    VehicleAction.openTrunkInd:
        'assets/video_sdr/BukaTutupTangki_Indo_sdr.mp4',
    VehicleAction.openTrunkJpn:
        'assets/video_sdr/BukaTutupTangki_jpn_sdr.mp4',
    VehicleAction.checkOilLevel:
        'assets/video_sdr/CaraCekOilLevel_sdr.mp4',
    VehicleAction.changeTire:
        'assets/video_sdr/CaraMenggantiBan_sdr.mp4',
    VehicleAction.useFireExtinguisher:
        'assets/video_sdr/CaraMenggunakanAPAR_sdr.mp4',
    VehicleAction.helpAccident:
        'assets/video_sdr/MenolongKecelakaan_sdr.mp4',
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
      case 'CHECK_OIL_LEVEL':
        return VehicleAction.checkOilLevel;
      case 'CHANGE_TIRE':
        return VehicleAction.changeTire;
      case 'USE_FIRE_EXTINGUISHER':
        return VehicleAction.useFireExtinguisher;
      case 'HELP_ACCIDENT':
        return VehicleAction.helpAccident;
      default:
        return null;
    }
  }
}
