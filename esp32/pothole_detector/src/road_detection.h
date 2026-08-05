#pragma once

namespace pothole {

enum class RoadCategory {
  normal,
  bumper,
  pothole,
};

struct DetectionResult {
  bool detected;
  RoadCategory category;
  float severity;
};

struct DetectionConfig {
  float eventStartThreshold = 1.5F;
  float eventReleaseThreshold = 0.7F;
  float potholeThreshold = 4.0F;
  float severePotholeThreshold = 5.0F;
  float bumperThreshold = 2.0F;
  float minSpeedDetect = 3.0F;
  float potholeMinSpeed = 8.0F;
  float bumperMaxSpeed = 25.0F;
  unsigned long eventReleaseMs = 120;
  unsigned long eventMaxMs = 700;
  unsigned long potholeMaxDurationMs = 400;
  unsigned long bumperMinDurationMs = 100;
};

int categoryPriority(RoadCategory category);
const char* categoryName(RoadCategory category);
float normalizeHeading(float heading);
float smoothHeading(float from, float to, float factor);

class RoadEventDetector {
 public:
  explicit RoadEventDetector(DetectionConfig config = DetectionConfig());

  DetectionResult update(
    float ax,
    float ay,
    float az,
    float speed,
    unsigned long now
  );
  void reset();

 private:
  DetectionConfig config_;
  bool active_ = false;
  float peak_ = 0;
  float speed_ = 0;
  unsigned long startedAt_ = 0;
  unsigned long lastImpactAt_ = 0;
};

}  // namespace pothole
