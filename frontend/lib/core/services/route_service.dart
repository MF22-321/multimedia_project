import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url =
        "https://router.project-osrm.org/route/v1/driving/"
        "${start.longitude},${start.latitude};"
        "${end.longitude},${end.latitude}"
        "?overview=full&geometries=geojson";

    final response = await http.get(Uri.parse(url));

    final data = json.decode(response.body);

    final coords = data["routes"][0]["geometry"]["coordinates"];

    return coords.map<LatLng>((c) {
      return LatLng(c[1], c[0]);
    }).toList();
  }
}
