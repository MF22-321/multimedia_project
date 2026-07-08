import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  RouteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url =
        "https://router.project-osrm.org/route/v1/driving/"
        "${start.longitude},${start.latitude};"
        "${end.longitude},${end.latitude}"
        "?overview=full&geometries=geojson";

    final response = await _client.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception("Route request failed: ${response.statusCode}");
    }

    final data = json.decode(response.body);
    final routes = data["routes"];

    if (routes is! List || routes.isEmpty) {
      throw Exception("Route response has no routes");
    }

    final coords = routes.first["geometry"]?["coordinates"];

    if (coords is! List || coords.length < 2) {
      throw Exception("Route response has no geometry");
    }

    return coords.map<LatLng>((c) {
      return LatLng(c[1], c[0]);
    }).toList();
  }
}
