#include "road_detection.h"

#include <cmath>

namespace pothole {

int categoryPriority(RoadCategory category) {
  if (category == RoadCategory::pothole) return 2;
  if (category == RoadCategory::bumper) return 1;
  return 0;
}

const char* categoryName(RoadCategory category) {
  if (category == RoadCategory::pothole) return "pothole";
  if (category == RoadCategory::bumper) return "bumper";
  return "normal";
}

float normalizeHeading(float heading) {
  while (heading < 0) heading += 360;
  while (heading >= 360) heading -= 360;
  return heading;
}

float smoothHeading(float from, float to, float factor) {
  const float diff = std::fmod(to - from + 540.0F, 360.0F) - 180.0F;
  return normalizeHeading(from + diff * factor);
}

RoadEventDetector::RoadEventDetector(DetectionConfig config) : config_(config) {}

void RoadEventDetector::reset() {
  active_ = false;
  peak_ = 0;
  speed_ = 0;
  startedAt_ = 0;
  lastImpactAt_ = 0;
}

DetectionResult RoadEventDetector::update(
  float ax,
  float ay,
  float az,
  float speed,
  unsigned long now
) {
  DetectionResult result = {false, RoadCategory::normal, 0};
  const float magnitude = std::sqrt(ax * ax + ay * ay + az * az);

  if (!active_) {
    result.severity = magnitude;
    if (speed >= config_.minSpeedDetect &&
        magnitude >= config_.eventStartThreshold) {
      active_ = true;
      peak_ = magnitude;
      speed_ = speed;
      startedAt_ = now;
      lastImpactAt_ = now;
    }
    return result;
  }

  if (magnitude > peak_) peak_ = magnitude;
  if (magnitude >= config_.eventReleaseThreshold) lastImpactAt_ = now;

  const unsigned long duration = now - startedAt_;
  const bool released = now - lastImpactAt_ >= config_.eventReleaseMs;
  const bool timedOut = duration >= config_.eventMaxMs;
  result.severity = peak_;

  if (!released && !timedOut) return result;

  const float peak = peak_;
  const float eventSpeed = speed_;
  reset();
  result.severity = peak;

  const bool sharpPothole =
      duration <= config_.potholeMaxDurationMs &&
      peak >= config_.potholeThreshold;
  const bool severePothole = peak >= config_.severePotholeThreshold;

  if (eventSpeed >= config_.potholeMinSpeed &&
      (sharpPothole || severePothole)) {
    result.detected = true;
    result.category = RoadCategory::pothole;
    return result;
  }

  if (eventSpeed <= config_.bumperMaxSpeed &&
      duration >= config_.bumperMinDurationMs &&
      peak >= config_.bumperThreshold) {
    result.detected = true;
    result.category = RoadCategory::bumper;
  }

  return result;
}

}  // namespace pothole
