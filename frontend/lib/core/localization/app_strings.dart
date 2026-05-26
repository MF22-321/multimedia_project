import 'package:frontend/core/navigation/app_language_control.dart';

class AppStrings {
  static bool get isEnglish => AppLanguageControl.isEnglish;

  static String choose({required String id, required String en}) {
    return isEnglish ? en : id;
  }

  static String get hello => choose(id: 'Halo', en: 'Hello');
  static String get guest => choose(id: 'Guest', en: 'Guest');
  static String get applications => choose(id: 'Aplikasi', en: 'Applications');
  static String get connectedCockpit {
    return choose(id: 'Kokpit terhubung', en: 'Connected cockpit');
  }

  static String get music => choose(id: 'Musik', en: 'Music');
  static String get videos => choose(id: 'Video', en: 'Videos');
  static String get photos => choose(id: 'Foto', en: 'Photos');
  static String get phone => choose(id: 'Telepon', en: 'Phone');
  static String get home => choose(id: 'Beranda', en: 'Home');
  static String get menu => choose(id: 'Menu', en: 'Menu');
  static String get settings => choose(id: 'Pengaturan', en: 'Settings');
  static String get navigation => choose(id: 'Navigasi', en: 'Navigation');
  static String get radio => choose(id: 'Radio', en: 'Radio');
  static String get bluetooth => choose(id: 'Bluetooth', en: 'Bluetooth');
  static String get screenCast => choose(id: 'Screen Cast', en: 'Screen Cast');
  static String get usb => choose(id: 'USB', en: 'USB');
  static String get vehicle => choose(id: 'Kendaraan', en: 'Vehicle');
  static String get carStatus => choose(id: 'Status Mobil', en: 'Car Status');
  static String get driveInfo => choose(id: 'Info Berkendara', en: 'Drive Info');
  static String get drive => choose(id: 'Berkendara', en: 'Drive');
  static String get online => choose(id: 'Online', en: 'Online');
  static String get info => choose(id: 'Info', en: 'Info');
  static String get fragrance => choose(id: 'Fragrance', en: 'Fragrance');
  static String get mToyota => 'M-Toyota';

  static String get back => choose(id: 'Kembali', en: 'Back');
  static String get profile => choose(id: 'Profil', en: 'Profile');
  static String get personalizeSettings => choose(id: 'Personalisasikan pengaturan Anda', en: 'Personalize your settings');
  static String get saveSettings => choose(id: 'Simpan Pengaturan', en: 'Save Settings');
  static String get language => choose(id: 'Bahasa', en: 'Language');
  static String get chooseLanguage => choose(id: 'Pilih bahasa sistem infotainment.', en: 'Choose the infotainment system language.');
  static String get usbConnect => choose(id: 'Sambungan USB', en: 'USB Connect');
  static String get usbAudioHub => choose(id: 'USB Audio Hub', en: 'USB Audio Hub');
  static String get bluetoothConnection => choose(id: 'Koneksi Bluetooth', en: 'Bluetooth Connection');
  static String get pairYourSmartphone => choose(id: 'Pair smartphone, headphone, atau perangkat lain.', en: 'Pair your smartphone, headphone, or other devices.');
  static String get scanningDevices => choose(id: 'Memindai perangkat...', en: 'Scanning Devices...');
  static String get bluetoothIdle => choose(id: 'Bluetooth Siap', en: 'Bluetooth Idle');
  static String get unknownDevice => choose(id: 'Perangkat Tidak Dikenal', en: 'Unknown Device');
  static String get connected => choose(id: 'Terhubung', en: 'Connected');
  static String get available => choose(id: 'Tersedia', en: 'Available');
  static String get connect => choose(id: 'Hubungkan', en: 'Connect');
  static String get disconnect => choose(id: 'Putuskan', en: 'Disconnect');
  static String get cast => choose(id: 'Cast', en: 'Cast');
  static String get noDeviceConnected => choose(id: 'Tidak ada perangkat terhubung', en: 'No Device Connected');
  static String get androidDeviceReady => choose(id: 'Perangkat Android Siap', en: 'Android Device Ready');
  static String connectedTo(String serial) {
    return choose(
      id: 'Terhubung ke $serial',
      en: 'Connected to $serial',
    );
  }
  static String get launchingScreenCast => choose(id: 'Meluncurkan Screen Cast...', en: 'Launching Screen Cast...');
  static String get screenCastingActive => choose(id: 'Screen Casting Aktif', en: 'Screen Casting Active');
  static String get androidScreenCast => choose(id: 'Android Screen Cast', en: 'Android Screen Cast');
  static String get smartphoneMirroredLive => choose(id: 'Layar smartphone Anda dicerminkan secara langsung.', en: 'Your smartphone screen is mirrored live.');
  static String get connectAndroidDevice => choose(id: 'Hubungkan perangkat Android menggunakan ADB + scrcpy.', en: 'Connect your Android device using ADB + scrcpy.');
  static String get connectionFailed => choose(id: 'Koneksi Gagal', en: 'Connection Failed');
  static String get disconnected => choose(id: 'Terputus', en: 'Disconnected');
  static String get vehicleInformation => choose(id: 'Informasi Kendaraan', en: 'Vehicle Information');
  static String get smartVehicleInsight => choose(id: 'Wawasan Kendaraan Pintar', en: 'Smart Vehicle Insight');
  static String get connectedSmartVehicle => choose(id: 'Kendaraan Pintar Terhubung', en: 'Connected Smart Vehicle');
  static String get connectedVehicle => choose(id: 'Kendaraan Terhubung', en: 'Connected Vehicle');
  static String get modernConnectedVehicle => choose(id: 'Kendaraan Modern Terhubung', en: 'Modern Connected Vehicle');
  static String get bluetoothConnected => choose(id: 'Bluetooth Terhubung', en: 'Bluetooth Connected');
  static String get gpsSynced => choose(id: 'GPS Tersinkronisasi', en: 'GPS Synced');
  static String get adbWireless => choose(id: 'ADB Wireless', en: 'ADB Wireless');
  static String get adbWirelessConnected => choose(id: 'ADB Wireless Terhubung', en: 'ADB Wireless Connected');
  static String get connectivity => choose(id: 'Konektivitas', en: 'Connectivity');
  static String get androidCastReady => choose(id: 'Android Cast Siap', en: 'Android Cast Ready');
  static String get vehicleStatus => choose(id: 'Status Kendaraan', en: 'Vehicle Status');
  static String get driveMode => choose(id: 'Mode Berkendara', en: 'Drive Mode');
  static String get comfort => choose(id: 'Nyaman', en: 'Comfort');
  static String get eco => choose(id: 'Eco', en: 'Eco');
  static String get sport => choose(id: 'Sport', en: 'Sport');
  static String get custom => choose(id: 'Kustom', en: 'Custom');
  static String get fuel => choose(id: 'Bahan Bakar', en: 'Fuel');
  static String get battery => choose(id: 'Baterai', en: 'Battery');
  static String get engine => choose(id: 'Mesin', en: 'Engine');
  static String get normal => choose(id: 'Normal', en: 'Normal');
  static String get tirePressure => choose(id: 'Tekanan Ban', en: 'Tire Pressure');
  static String get frontLeft => choose(id: 'Depan Kiri', en: 'Front Left');
  static String get frontRight => choose(id: 'Depan Kanan', en: 'Front Right');
  static String get rearLeft => choose(id: 'Belakang Kiri', en: 'Rear Left');
  static String get rearRight => choose(id: 'Belakang Kanan', en: 'Rear Right');
  static String get usbAudioConnected => choose(id: 'USB Audio Terhubung', en: 'USB Audio Connected');
  static String get adbConnected => choose(id: 'ADB Terhubung', en: 'ADB Connected');
  static String get usbAudioReady => choose(id: 'USB Audio Siap', en: 'USB Audio Ready');
  static String get smartphoneScreenMirroredLive => choose(id: 'Layar smartphone Anda tercermin secara langsung.', en: 'Your smartphone screen is mirrored live.');
  static String get connectAndroidDeviceWithAdb => choose(id: 'Hubungkan perangkat Android Anda menggunakan ADB + scrcpy.', en: 'Connect your Android device using ADB + scrcpy.');
  static String get storageInformation => choose(id: 'Informasi Penyimpanan', en: 'Storage Information');
  static String get usbConnected => choose(id: 'USB Terhubung', en: 'USB Connected');
  static String get connectionStatus => choose(id: 'Status Koneksi', en: 'Connection Status');
  static String get navigationInsight => choose(id: 'Wawasan Navigasi', en: 'Navigation Insight');
  static String get drivingAnalytics => choose(id: 'Analitik Berkendara', en: 'Driving Analytics');
  static String get drivingScore => choose(id: 'Skor Berkendara', en: 'Driving Score');
  static String get fuelEfficiency => choose(id: 'Efisiensi Bahan Bakar', en: 'Fuel Efficiency');
  static String get distanceToday => choose(id: 'Jarak Hari Ini', en: 'Distance Today');
  static String get smartDetection => choose(id: 'Deteksi Pintar', en: 'Smart Detection');
  static String get potholeDetection => choose(id: 'Deteksi Lubang', en: 'Pothole Detection');
  static String get driverMonitoring => choose(id: 'Pemantauan Pengemudi', en: 'Driver Monitoring');
  static String get fatigueRisk => choose(id: 'Risiko Kelelahan', en: 'Fatigue Risk');
  static String get systemInformation => choose(id: 'Informasi Sistem', en: 'System Information');
  static String get platform => choose(id: 'Platform', en: 'Platform');
  static String get mediaEngine => choose(id: 'Mesin Media', en: 'Media Engine');
  static String get gpuRendering => choose(id: 'Rendering GPU', en: 'GPU Rendering');
  static String get nowPlaying => choose(id: 'Sedang Diputar', en: 'Now Playing');
  static String get roadCondition => choose(id: 'Kondisi Jalan', en: 'Road Condition');
  static String get moderate => choose(id: 'Sedang', en: 'Moderate');
  static String get potholeNearby => choose(id: 'Lubang di Dekat', en: 'Pothole Nearby');
  static String get detected => choose(id: 'Terdeteksi', en: 'Detected');
  static String get eta => choose(id: 'ETA', en: 'ETA');
  static String get connectAudio => choose(id: 'Hubungkan Audio', en: 'Connect Audio');
  static String get openMusic => choose(id: 'Buka Musik', en: 'Open Music');
  static String get disconnectUsb => choose(id: 'Putuskan USB', en: 'Disconnect USB');
  static String get offline => choose(id: 'Offline', en: 'Offline');
  static String get deviceInformation => choose(id: 'Informasi Perangkat', en: 'Device Information');
  static String get codec => choose(id: 'Codec', en: 'Codec');
  static String get sampleRateLabel => choose(id: 'Sample Rate', en: 'Sample Rate');
  static String get output => choose(id: 'Output', en: 'Output');
  static String get carSpeaker => choose(id: 'Speaker Mobil', en: 'Car Speaker');
  static String get device => choose(id: 'Perangkat', en: 'Device');
  static String get version => choose(id: 'Versi', en: 'Version');
  static String get mount => choose(id: 'Mount', en: 'Mount');
  static String get usbAudio => choose(id: 'USB Audio', en: 'USB Audio');
  static String get noAndroidDeviceFound => choose(id: 'Tidak ada perangkat Android ditemukan', en: 'No Android Device Found');

  static String get callsContacts {
    return choose(id: 'Panggilan & kontak', en: 'Calls & contacts');
  }

  static String get mapOverview {
    return choose(id: 'Ringkasan peta', en: 'Map overview');
  }

  static String get driveControls {
    return choose(id: 'Kontrol berkendara', en: 'Drive controls');
  }

  static String get liveStations {
    return choose(id: 'Siaran langsung', en: 'Live stations');
  }

  static String get devicePairing {
    return choose(id: 'Koneksi perangkat', en: 'Device pairing');
  }

  static String get mirrorDevice {
    return choose(id: 'Cerminkan perangkat', en: 'Mirror device');
  }

  static String get mediaSource {
    return choose(id: 'Sumber media', en: 'Media source');
  }

  static String get systemDetails {
    return choose(id: 'Detail sistem', en: 'System details');
  }

  static String get guidedHelp {
    return choose(id: 'Panduan bantuan', en: 'Guided help');
  }

  static String get cabinScent {
    return choose(id: 'Aroma kabin', en: 'Cabin scent');
  }

  static String get videoTutorial {
    return choose(id: 'Video Tutorial', en: 'Video Tutorial');
  }

  static String get tutorialDescription {
    return choose(
      id: 'Pelajari langkah penggunaan fitur kendaraan dengan mudah.',
      en: 'Learn how to use vehicle features step by step.',
    );
  }

  static String get openHood => choose(id: 'Buka Kap Mobil', en: 'Open Hood');
  static String get openFuelCap {
    return choose(id: 'Buka Tutup Tangki', en: 'Open Fuel Cap');
  }

  static String get pairBluetooth {
    return choose(id: 'Pair Bluetooth', en: 'Pair Bluetooth');
  }

  static String get voiceAssistant {
    return choose(id: 'Voice Assistant', en: 'Voice Assistant');
  }

  static String get moodPlaylist => choose(id: 'Playlist Mood', en: 'Mood Playlist');

  static String get positiveMoodDetected {
    return choose(id: 'Mood Positif Terdeteksi', en: 'Positive Mood Detected');
  }

  static String get tiredMoodDetected {
    return choose(id: 'Mood Lelah Terdeteksi', en: 'Tired Mood Detected');
  }

  static String get happyMoodSubtitle {
    return choose(
      id: 'Sepertinya perjalanan kamu sedang menyenangkan.',
      en: 'It looks like your drive is going well.',
    );
  }

  static String get calmMoodSubtitle {
    return choose(
      id: 'Kami merekomendasikan musik santai agar perjalanan lebih nyaman.',
      en: 'We recommend calm music to keep the drive comfortable.',
    );
  }

  static String get playHappyMusic {
    return choose(id: 'Putar Musik Bahagia', en: 'Play Happy Music');
  }

  static String get playCalmMusic {
    return choose(id: 'Putar Musik Santai', en: 'Play Calm Music');
  }

  static String get later => choose(id: 'Nanti', en: 'Later');
  static String get drowsyWarning {
    return choose(
      id: 'Hati-hati Anda sedang mengantuk!',
      en: 'Careful, you look drowsy!',
    );
  }

  static String get smartFragranceQuestion {
    return choose(
      id: 'Mau mengaktifkan Smart Fragrance untuk mengurangi kantuk Anda?',
      en: 'Turn on Smart Fragrance to help reduce drowsiness?',
    );
  }

  static String get yes => choose(id: 'YA', en: 'YES');
  static String get no => choose(id: 'TIDAK', en: 'NO');
  static String get disableDrowsiness {
    return choose(
      id: 'Nonaktifkan Drowsiness Detection',
      en: 'Disable Drowsiness Detection',
    );
  }

  static String get active => choose(id: 'Aktif', en: 'Active');
  static String get inactive => choose(id: 'Nonaktif', en: 'Inactive');
  static String get low => choose(id: 'Rendah', en: 'Low');
  static String safeDriveGreeting(String driverName) {
    return choose(
      id: 'Selamat berkendara, $driverName',
      en: 'Drive safely, $driverName',
    );
  }

  static String startDrowsinessFailed(Object error) {
    return choose(
      id: 'Gagal memulai drowsiness detection: $error',
      en: 'Failed to start drowsiness detection: $error',
    );
  }

  static String stopDrowsinessFailed(Object error) {
    return choose(
      id: 'Gagal menghentikan drowsiness detection: $error',
      en: 'Failed to stop drowsiness detection: $error',
    );
  }
  static String get smartNavigation => choose(id: 'Navigasi Pintar', en: 'Smart Navigation');
static String get gpsLocked => choose(id: 'GPS terkunci', en: 'GPS locked');
static String get searchingGps => choose(id: 'Mencari GPS', en: 'Searching GPS');
static String get adaptiveRoute => choose(id: 'Rute Adaptif', en: 'Adaptive route');
static String get roadGuard => choose(id: 'Penjaga Jalan', en: 'Road guard');
static String get searchDestination => choose(id: 'Cari tujuan', en: 'Search destination');
static String get destination => choose(id: 'Tujuan', en: 'Destination');
static String get searchADestination => choose(id: 'Cari tujuan perjalanan', en: 'Search a destination');
static String get calculatingRoute => choose(id: 'Menghitung rute...', en: 'Calculating route...');
static String get readyForNavigation => choose(id: 'Siap untuk navigasi', en: 'Ready for navigation');
static String routeLoaded(double km) => choose(
  id: '${km.toStringAsFixed(1)} km rute dimuat',
  en: '${km.toStringAsFixed(1)} km route loaded',
);
static String get destinationSearchUnavailable => choose(
  id: 'Pencarian tujuan tidak tersedia',
  en: 'Destination search unavailable',
);
static String get routeCouldNotBeLoaded => choose(
  id: 'Rute tidak dapat dimuat',
  en: 'Route could not be loaded',
);
static String get clearRoad => choose(id: 'Jalan aman', en: 'Clear road');
static String get potholeAhead => choose(id: 'Lubang di depan', en: 'Pothole ahead');
static String get pothole => choose(id: 'Lubang', en: 'Pothole');
static String get speedBump => choose(id: 'Polisi Tidur', en: 'Speed Bump');
static String get speedBumpAhead => choose(id: 'Polisi tidur di depan', en: 'Speed bump ahead');
static String get noHazardNearby => choose(id: 'Tidak ada bahaya dekat', en: 'No hazard nearby');
static String get speed => choose(id: 'Kecepatan', en: 'Speed');
static String get heading => choose(id: 'Arah', en: 'Heading');
static String get continueAhead => choose(id: 'Lanjut lurus', en: 'Continue ahead');
static String get keepCurrentLane => choose(id: 'Tetap di jalur saat ini', en: 'Keep current lane');
static String get waitingGpsFix => choose(id: 'Menunggu sinyal GPS', en: 'Waiting for GPS fix');
static String get nextManeuver => choose(id: 'Manuver berikutnya', en: 'Next maneuver');
static String get routeGuidanceStandby => choose(id: 'Panduan rute siaga', en: 'Route guidance standby');
static String get navigationSurface => choose(id: 'Permukaan navigasi', en: 'Navigation surface');
static String get roadAlerts => choose(id: 'Peringatan Jalan', en: 'Road Alerts');
static String get noActiveHazard => choose(id: 'Tidak ada bahaya aktif', en: 'No active hazard');
static String get severity => choose(id: 'Tingkat', en: 'Severity');
static String get mapZoom => choose(id: 'Zoom Peta', en: 'Map Zoom');
static String get hazards => choose(id: 'Bahaya', en: 'Hazards');
static String get alerts => choose(id: 'Peringatan', en: 'Alerts');
static String get armed => choose(id: 'Aktif', en: 'Armed');
static String get muted => choose(id: 'Senyap', en: 'Muted');
static String get profileSettings => choose(id: 'Pengaturan Profil', en: 'Profile Settings');
static String get smartFragranceControl => choose(id: 'Kontrol Smart Fragrance', en: 'Smart Fragrance Control');
static String get selectCartridge => choose(id: 'Pilih\nCartridge', en: 'Select\nCartridge');
static String get customSettings => choose(id: 'Pengaturan Kustom', en: 'Custom Settings');
static String get fanTemperatureControl => choose(id: 'Kontrol Kipas & Suhu', en: 'Fan & Temperature Control');
static String get multimediaThemeSettings => choose(id: 'Pengaturan Tema Multimedia', en: 'Multimedia Theme Settings');
static String get customTheme => choose(id: 'Tema Kustom', en: 'Custom Theme');
static String get deleteAccount => choose(id: 'Hapus Akun', en: 'Delete Account');
static String get deleteDriverAccount => choose(id: 'Hapus Akun Driver', en: 'Delete Driver Account');
static String deleteDriverPrompt(String driver) => choose(
  id: 'Verifikasi wajah $driver untuk menghapus akun ini.',
  en: 'Verify $driver face to delete this account.',
);
static String get verifyingFace => choose(id: 'Memverifikasi wajah...', en: 'Verifying face...');
static String get faceVerified => choose(id: 'Wajah terverifikasi', en: 'Face verified');
static String get deletingAccount => choose(id: 'Menghapus akun...', en: 'Deleting account...');
static String get cancel => choose(id: 'Batal', en: 'Cancel');
static String get deleteNow => choose(id: 'Hapus Sekarang', en: 'Delete Now');
static String get faceNotMatched => choose(id: 'Wajah belum cocok dengan driver aktif', en: 'Face does not match the active driver yet');
static String get accountDeleted => choose(id: 'Akun driver berhasil dihapus', en: 'Driver account deleted');
static String deleteAccountFailed(Object error) => choose(
  id: 'Gagal menghapus akun: $error',
  en: 'Failed to delete account: $error',
);
static String get searchDestinationToStart => choose(id: 'Cari tujuan untuk mulai', en: 'Search destination to start');
static String get preparingNavigation => choose(id: 'Menyiapkan navigasi', en: 'Preparing navigation');
static String get continueStraight => choose(id: 'Lanjut lurus', en: 'Continue straight');
static String kmRemaining(double km) => choose(
  id: '${km.toStringAsFixed(1)} km tersisa',
  en: '${km.toStringAsFixed(1)} km remaining',
);
static String metersRemaining(int meters) => choose(
  id: '$meters m tersisa',
  en: '$meters m remaining',
);
static String get routeUnavailable => choose(id: 'Rute tidak tersedia', en: 'Route unavailable');
static String get pleaseTryAnotherDestination => choose(id: 'Coba tujuan lain', en: 'Please try another destination');
static String get destinationReached => choose(id: 'Tujuan tercapai', en: 'Destination reached');
static String get youHaveArrived => choose(id: 'Anda sudah tiba', en: 'You have arrived');
static String get arrivingSoon => choose(id: 'Sebentar lagi tiba', en: 'Arriving soon');
static String get slightRightAhead => choose(id: 'Sedikit kanan di depan', en: 'Slight right ahead');
static String get slightLeftAhead => choose(id: 'Sedikit kiri di depan', en: 'Slight left ahead');
static String get turnRightAhead => choose(id: 'Belok kanan di depan', en: 'Turn right ahead');
static String get turnLeftAhead => choose(id: 'Belok kiri di depan', en: 'Turn left ahead');
static String get makeUTurn => choose(id: 'Putar balik', en: 'Make a U-turn');
static String get realignToRoute => choose(id: 'Sesuaikan kembali ke rute', en: 'Re-align to route');
static String get routeClear => choose(id: 'Rute aman', en: 'Route clear');
static String get noHazardInFront => choose(id: 'Tidak ada bahaya di depan', en: 'No hazard in front');
static String metersAhead(int meters) => choose(id: '$meters m di depan', en: '$meters m ahead');
static String get routeTracking => choose(id: 'Pelacakan rute', en: 'Route tracking');
static String get noActiveRoute => choose(id: 'Tidak ada rute aktif', en: 'No active route');
static String get followVehicle => choose(id: 'Ikuti kendaraan', en: 'Follow vehicle');
static String get toggleAlerts => choose(id: 'Alihkan peringatan', en: 'Toggle alerts');
static String get toggleHazardLayer => choose(id: 'Alihkan layer bahaya', en: 'Toggle hazard layer');
static String get zoomIn => choose(id: 'Perbesar', en: 'Zoom in');
static String get zoomOut => choose(id: 'Perkecil', en: 'Zoom out');
static String get remaining => choose(id: 'Sisa', en: 'Remaining');
static String get ahead => choose(id: 'Depan', en: 'Ahead');
static String get clear => choose(id: 'Aman', en: 'Clear');
static String get smartPotholeNavigation => choose(id: 'Navigasi Lubang Pintar', en: 'Smart Pothole Navigation');
static String severityValue(double value) => choose(
  id: 'Tingkat ${value.toStringAsFixed(1)}',
  en: 'Severity ${value.toStringAsFixed(1)}',
);
static String get toyotaConnectivity => choose(
  id: 'Konektivitas Dalam Mobil Toyota',
  en: 'Toyota In Car Connectivity',
);
}
