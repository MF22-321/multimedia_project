class MapTileConfig {
  // CartoDB Voyager — gratis, tanpa API key, tidak ada rate-limit ketat seperti OSM default.
  // {s} = subdomain (a/b/c/d) untuk distribusi request agar tidak blocked.
  static const urlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const subdomains = ['a', 'b', 'c', 'd'];
  static const userAgentPackageName = 'com.pothole.navigation.app';
  static const maxZoom = 19.0;
  static const attribution = 'CartoDB | OpenStreetMap contributors';
  static final attributionUri = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );
}
