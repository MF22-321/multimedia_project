#include <cassert>
#include <cmath>
#include <cstring>
#include <iostream>

#include "road_detection.h"

using pothole::DetectionResult;
using pothole::DetectionConfig;
using pothole::RoadCategory;
using pothole::RoadEventDetector;

namespace {

bool closeTo(float actual, float expected) {
  return std::fabs(actual - expected) < 0.001F;
}

DetectionResult release(
  RoadEventDetector& detector,
  float peak,
  float speed,
  unsigned long duration = 120
) {
  detector.update(peak, 0, 0, speed, 0);
  return detector.update(0, 0, 0, speed, duration);
}

void testCategoryHelpers() {
  assert(pothole::categoryPriority(RoadCategory::normal) == 0);
  assert(pothole::categoryPriority(RoadCategory::bumper) == 1);
  assert(pothole::categoryPriority(RoadCategory::pothole) == 2);
  assert(std::strcmp(pothole::categoryName(RoadCategory::normal), "normal") == 0);
  assert(std::strcmp(pothole::categoryName(RoadCategory::bumper), "bumper") == 0);
  assert(std::strcmp(pothole::categoryName(RoadCategory::pothole), "pothole") == 0);
}

void testHeadingHelpers() {
  assert(closeTo(pothole::normalizeHeading(-10), 350));
  assert(closeTo(pothole::normalizeHeading(370), 10));
  assert(closeTo(pothole::normalizeHeading(90), 90));
  assert(closeTo(pothole::smoothHeading(350, 10, 0.5F), 0));
}

void testIdleAndReset() {
  RoadEventDetector detector;
  auto idle = detector.update(1, 0, 0, 2, 0);
  assert(!idle.detected);
  assert(idle.category == RoadCategory::normal);
  assert(closeTo(idle.severity, 1));

  detector.update(4, 0, 0, 10, 10);
  detector.reset();
  auto afterReset = detector.update(0, 0, 0, 10, 200);
  assert(closeTo(afterReset.severity, 0));
}

void testPotholeAndPendingEvent() {
  RoadEventDetector detector;
  auto started = detector.update(4, 0, 0, 10, 0);
  assert(!started.detected);
  auto pending = detector.update(5, 0, 0, 10, 50);
  assert(!pending.detected);
  assert(closeTo(pending.severity, 5));
  auto pothole = detector.update(0, 0, 0, 10, 200);
  assert(pothole.detected);
  assert(pothole.category == RoadCategory::pothole);
  assert(closeTo(pothole.severity, 5));
}

void testSevereLongPothole() {
  RoadEventDetector detector;
  detector.update(2, 0, 0, 10, 0);
  detector.update(5.5F, 0, 0, 10, 500);
  auto severe = detector.update(0, 0, 0, 10, 700);
  assert(severe.detected);
  assert(severe.category == RoadCategory::pothole);
}

void testBumperAndNormalEvent() {
  RoadEventDetector detector;
  const auto bumper = release(detector, 2.5F, 10);
  assert(bumper.detected);
  assert(bumper.category == RoadCategory::bumper);

  const auto normal = release(detector, 1.5F, 10);
  assert(!normal.detected);
  assert(normal.category == RoadCategory::normal);
}

void testTimeoutWithoutRelease() {
  RoadEventDetector detector;
  detector.update(1.5F, 0, 0, 10, 0);
  const auto timedOut = detector.update(1, 0, 0, 10, 700);
  assert(!timedOut.detected);
  assert(closeTo(timedOut.severity, 1.5F));
}

void testDecisionShortCircuits() {
  RoadEventDetector slowVehicle;
  const auto slowImpact = release(slowVehicle, 4, 5);
  assert(slowImpact.category == RoadCategory::bumper);

  RoadEventDetector fastVehicle;
  const auto fastImpact = release(fastVehicle, 2.5F, 30);
  assert(!fastImpact.detected);

  DetectionConfig config;
  config.eventReleaseMs = 10;
  RoadEventDetector shortEvent(config);
  const auto tooShort = release(shortEvent, 2.5F, 10, 50);
  assert(!tooShort.detected);
}

}  // namespace

int main() {
  testCategoryHelpers();
  testHeadingHelpers();
  testIdleAndReset();
  testPotholeAndPendingEvent();
  testSevereLongPothole();
  testBumperAndNormalEvent();
  testTimeoutWithoutRelease();
  testDecisionShortCircuits();
  std::cout << "ESP32 road detection: all tests passed\n";
  return 0;
}
