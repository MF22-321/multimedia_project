#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
ESP32_DIR="$PROJECT_ROOT/esp32/pothole_detector"
BUILD_DIR="/tmp/multimedia_pothole_quality"
FLUTTER_BIN="${FLUTTER_BIN:-/home/multimedia/flutter/bin/flutter}"
PIO_BIN="${PIO_BIN:-/home/multimedia/.platformio/penv/bin/pio}"
MIN_COVERAGE="${MIN_COVERAGE:-90}"

mkdir -p "$BUILD_DIR"
rm -f \
  "$BUILD_DIR/road_detection.gcda" \
  "$BUILD_DIR/road_detection.gcno" \
  "$BUILD_DIR/road_detection.o" \
  "$BUILD_DIR/test_road_detection.gcda" \
  "$BUILD_DIR/test_road_detection.gcno" \
  "$BUILD_DIR/test_road_detection.o" \
  "$BUILD_DIR/test_road_detection"

echo "[1/4] Flutter pothole, ESP32 protocol, and maps tests"
cd "$FRONTEND_DIR"
"$FLUTTER_BIN" test --no-pub --coverage \
  test/pothole_test.dart \
  test/pothole_comprehensive_test.dart \
  test/esp32_serial_protocol_test.dart \
  test/map_route_test.dart \
  test/map_navigation_engine_test.dart

echo "[2/4] Flutter target coverage gate (${MIN_COVERAGE}% minimum)"
awk -v minimum="$MIN_COVERAGE" '
  BEGIN {
    FS = ":"
    target["lib/core/model/gps_data.dart"] = 1
    target["lib/core/model/pothole.dart"] = 1
    target["lib/core/services/pothole_service.dart"] = 1
    target["lib/core/services/route_service.dart"] = 1
    target["lib/core/services/map_tile_config.dart"] = 1
    target["lib/core/services/serial_telemetry_decoder.dart"] = 1
    target["lib/core/utils/pothole_detection_engine.dart"] = 1
    target["lib/core/utils/map_navigation_engine.dart"] = 1
  }
  function report() {
    if (!(file in target)) return
    seen[file] = 1
    totalFound += linesFound
    totalHit += linesHit
    percent = linesFound ? 100 * linesHit / linesFound : 100
    printf "  %-62s %3d/%-3d %6.2f%%\n", file, linesHit, linesFound, percent
    if (percent + 0.0001 < minimum) failed = 1
  }
  /^SF:/ {
    report()
    file = substr($0, 4)
    linesFound = 0
    linesHit = 0
  }
  /^LF:/ { linesFound = $2 }
  /^LH:/ { linesHit = $2 }
  END {
    report()
    for (name in target) {
      if (!(name in seen)) {
        printf "  MISSING: %s\n", name
        failed = 1
      }
    }
    totalPercent = totalFound ? 100 * totalHit / totalFound : 0
    printf "  TOTAL %d/%d %.2f%%\n", totalHit, totalFound, totalPercent
    exit failed
  }
' coverage/lcov.info

echo "[3/4] Native ESP32 road-detection tests and coverage"
g++ -std=c++17 --coverage \
  -I"$ESP32_DIR/src" \
  -c "$ESP32_DIR/src/road_detection.cpp" \
  -o "$BUILD_DIR/road_detection.o"
g++ -std=c++17 --coverage \
  -I"$ESP32_DIR/src" \
  -c "$ESP32_DIR/test/native/test_road_detection.cpp" \
  -o "$BUILD_DIR/test_road_detection.o"
g++ --coverage \
  "$BUILD_DIR/road_detection.o" \
  "$BUILD_DIR/test_road_detection.o" \
  -o "$BUILD_DIR/test_road_detection"
"$BUILD_DIR/test_road_detection"

GCOV_OUTPUT="$(
  cd "$BUILD_DIR"
  gcov -b -c -o "$BUILD_DIR" "$ESP32_DIR/src/road_detection.cpp"
)"
printf '%s\n' "$GCOV_OUTPUT"

ESP32_COVERAGE="$(
  printf '%s\n' "$GCOV_OUTPUT" |
    awk -F'[:%]' '/^Lines executed:/ { print $2; exit }'
)"
awk -v actual="$ESP32_COVERAGE" -v minimum="$MIN_COVERAGE" '
  BEGIN {
    if (actual + 0.0001 < minimum) {
      printf "ESP32 coverage %.2f%% is below %.2f%%\n", actual, minimum
      exit 1
    }
  }
'

echo "[4/4] ESP32 production firmware build"
cd "$ESP32_DIR"
"$PIO_BIN" run

echo "Pothole quality gate passed."
