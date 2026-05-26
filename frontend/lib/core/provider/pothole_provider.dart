import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/model/gps_data.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/provider/gps_provider.dart';
import 'package:frontend/core/services/pothole_service.dart';
import 'package:frontend/core/utils/pothole_detection_engine.dart';
import 'package:frontend/core/utils/app_logger.dart';

class PotholeProvider extends ChangeNotifier {
  final PotholeService _service = PotholeService();

  final List<Pothole> _backendPotholes = [];
  final List<Pothole> _livePotholes = [];

  GPSProvider? _gpsProvider;
  int _realtimeSubscribers = 0;

  bool isLoading = false;
  String? errorMessage;
  DateTime? lastUpdated;

  Timer? _refreshTimer;

  List<Pothole> get potholes {
    final merged = <Pothole>[
      ..._backendPotholes,
      ..._livePotholes,
    ];

    final deduped = <Pothole>[];
    for (final hazard in merged) {
      final existingIndex = deduped.indexWhere((item) {
        final distance = PotholeDetectionEngine.distanceKm(
          item.lat,
          item.lng,
          hazard.lat,
          hazard.lng,
        );

        return item.category == hazard.category && distance < 0.015;
      });

      if (existingIndex == -1) {
        deduped.add(hazard);
        continue;
      }

      final existing = deduped[existingIndex];
      if (hazard.severity >= existing.severity ||
          hazard.source == "esp32" && existing.source != "esp32") {
        deduped[existingIndex] = hazard;
      }
    }

    return deduped;
  }

  void bindGps(GPSProvider gpsProvider) {
    if (identical(_gpsProvider, gpsProvider)) return;

    _gpsProvider?.removeListener(_handleGpsChanged);
    _gpsProvider = gpsProvider;
    _gpsProvider?.addListener(_handleGpsChanged);
    _handleGpsChanged();
  }

  void _handleGpsChanged() {
    final gps = _gpsProvider?.current;
    _syncLiveTelemetry(gps);
  }

  Future<void> loadPotholes() async {
    if (isLoading) return;

    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final result = await _service.fetchPotholes();

      _backendPotholes
        ..clear()
        ..addAll(result);
      lastUpdated = DateTime.now();

      AppLogger.info("POTHOLE COUNT: ${potholes.length}");
    } catch (e) {
      errorMessage = e.toString();
      AppLogger.error("ERROR PROVIDER: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void attachRealtime({Duration interval = const Duration(seconds: 3)}) {
    _realtimeSubscribers++;
    if (_refreshTimer != null) return;

    loadPotholes();

    _refreshTimer = Timer.periodic(interval, (_) {
      loadPotholes();
    });
  }

  void detachRealtime() {
    if (_realtimeSubscribers > 0) {
      _realtimeSubscribers--;
    }

    if (_realtimeSubscribers > 0) return;

    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _syncLiveTelemetry(GPSData? gps) {
    final now = DateTime.now();
    var changed = false;

    final previousLength = _livePotholes.length;
    _livePotholes.removeWhere((hazard) {
      final detectedAt = hazard.detectedAt;
      return detectedAt == null ||
          now.difference(detectedAt) > const Duration(seconds: 10);
    });
    changed = changed || previousLength != _livePotholes.length;

    if (gps == null) {
      if (changed) notifyListeners();
      return;
    }

    final liveHazard = PotholeDetectionEngine.liveHazardFromTelemetry(gps);
    if (liveHazard == null) {
      if (changed) notifyListeners();
      return;
    }

    final existingIndex = _livePotholes.indexWhere((hazard) {
      final distance = PotholeDetectionEngine.distanceKm(
        hazard.lat,
        hazard.lng,
        liveHazard.lat,
        liveHazard.lng,
      );

      return distance < 0.015;
    });

    if (existingIndex == -1) {
      _livePotholes.add(liveHazard);
      changed = true;
    } else {
      final existing = _livePotholes[existingIndex];
      if (liveHazard.severity != existing.severity ||
          liveHazard.speed != existing.speed ||
          liveHazard.lat != existing.lat ||
          liveHazard.lng != existing.lng) {
        _livePotholes[existingIndex] = liveHazard;
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  List<Pothole> get activeHazards {
    return PotholeDetectionEngine.activeHazards(potholes);
  }

  int get potholeCount {
    return potholes.where((p) => p.category == "pothole").length;
  }

  int get bumperCount {
    return potholes.where((p) => p.category == "bumper").length;
  }

  @override
  void dispose() {
    _gpsProvider?.removeListener(_handleGpsChanged);
    detachRealtime();
    super.dispose();
  }
}
