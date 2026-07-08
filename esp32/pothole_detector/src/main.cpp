#include <Arduino.h>
#include <WiFi.h>
#include <DNSServer.h>
#include <WebServer.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <TinyGPS++.h>
#include <time.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include <utility/imumaths.h>

// =====================================================
// SERVER BACKEND
// =====================================================
#define SERVER_URL "http://203.100.57.59:3000/api/v1/pothole/add"

// =====================================================
// WIFI CONFIG PORTAL
// =====================================================
WebServer server(80);
DNSServer dnsServer;
Preferences preferences;

String savedSSID = "";
String savedPassword = "";

const char* AP_SSID = "Pothole-ESP32-Setup";
const char* AP_PASSWORD = "12345678";

bool configPortalActive = false;
bool configPortalOnly = false;
const byte DNS_PORT = 53;

// =====================================================
// TIME
// =====================================================
const char* NTP_SERVER = "asia.pool.ntp.org";
const long GMT_OFFSET_SEC = 7 * 3600;
const int DAYLIGHT_OFFSET_SEC = 0;

// =====================================================
// GPS
// =====================================================
HardwareSerial gpsSerial(2);

#define GPS_BAUD 9600
#define RX_PIN 16
#define TX_PIN 17

TinyGPSPlus gps;

// =====================================================
// IMU BNO055
// =====================================================
Adafruit_BNO055 bno = Adafruit_BNO055(55, 0x28);

// =====================================================
// LED
// =====================================================
#define LED_PIN 12

// =====================================================
// TIMER
// =====================================================
unsigned long lastSerialTime = 0;
unsigned long lastPostTime = 0;
unsigned long lastBlinkTime = 0;
unsigned long lastGpsInfoTime = 0;
unsigned long lastImuDebugTime = 0;
unsigned long lastWiFiCheckTime = 0;
unsigned long wifiAttemptStartedAt = 0;
unsigned long lastOfflineLogTime = 0;

const unsigned long SERIAL_INTERVAL = 100;
const unsigned long POST_INTERVAL = 500;
const unsigned long WIFI_CHECK_INTERVAL = 5000;
const unsigned long WIFI_ATTEMPT_TIMEOUT = 10000;
const unsigned long SERIAL_EVENT_HOLD_MS = 1500;

bool wifiAttemptActive = false;
bool wifiWasConnected = false;

// =====================================================
// DETECTION CONFIG
// =====================================================
const float EVENT_START_THRESHOLD = 1.5;
const float EVENT_RELEASE_THRESHOLD = 0.7;
const float POTHOLE_THRESHOLD = 4.0;
const float SEVERE_POTHOLE_THRESHOLD = 5.0;
const float BUMPER_THRESHOLD = 2.0;

const float MIN_SPEED_DETECT = 3.0;
const float POTHOLE_MIN_SPEED = 8.0;
const float BUMPER_MAX_SPEED = 25.0;

const unsigned long EVENT_RELEASE_MS = 120;
const unsigned long EVENT_MAX_MS = 700;
const unsigned long POTHOLE_MAX_DURATION_MS = 400;
const unsigned long BUMPER_MIN_DURATION_MS = 100;

bool roadEventActive = false;
float roadEventPeak = 0;
float roadEventSpeed = 0;
unsigned long roadEventStartedAt = 0;
unsigned long roadEventLastImpactAt = 0;

float lastNavigationHeading = 0;
bool hasNavigationHeading = false;

// =====================================================
// STRUCT
// =====================================================
struct DetectionResult {
  bool detected;
  String category;
  float severity;
};

DetectionResult pendingTelemetry;
DetectionResult serialTelemetry;
unsigned long serialEventUntil = 0;
float pendingAx = 0;
float pendingAy = 0;
float pendingAz = 0;

int categoryPriority(const String& category) {
  if (category == "pothole") return 2;
  if (category == "bumper") return 1;
  return 0;
}

void resetPendingTelemetry() {
  pendingTelemetry.detected = false;
  pendingTelemetry.category = "normal";
  pendingTelemetry.severity = 0;
  pendingAx = 0;
  pendingAy = 0;
  pendingAz = 0;
}

void resetSerialTelemetry() {
  serialTelemetry.detected = false;
  serialTelemetry.category = "normal";
  serialTelemetry.severity = 0;
  serialEventUntil = 0;
}

void updateSerialTelemetry(const DetectionResult& detection) {
  if (detection.detected) {
    if (categoryPriority(detection.category) >=
        categoryPriority(serialTelemetry.category)) {
      serialTelemetry = detection;
    }
    serialEventUntil = millis() + SERIAL_EVENT_HOLD_MS;
    return;
  }

  if (serialEventUntil != 0 &&
      static_cast<long>(millis() - serialEventUntil) < 0) {
    return;
  }

  serialTelemetry = detection;
  serialEventUntil = 0;
}

void accumulateTelemetry(
  const DetectionResult& detection,
  float ax,
  float ay,
  float az
) {
  int currentPriority = categoryPriority(pendingTelemetry.category);
  int nextPriority = categoryPriority(detection.category);

  if (
    nextPriority > currentPriority ||
    (nextPriority == currentPriority &&
     detection.severity >= pendingTelemetry.severity)
  ) {
    pendingTelemetry = detection;
    pendingAx = ax;
    pendingAy = ay;
    pendingAz = az;
  }
}

// =====================================================
// TIME INIT
// =====================================================
void initTime() {
  configTime(
    GMT_OFFSET_SEC,
    DAYLIGHT_OFFSET_SEC,
    NTP_SERVER
  );
}

// =====================================================
// HTML SAFE
// =====================================================
String htmlEscape(String value) {
  value.replace("&", "&amp;");
  value.replace("<", "&lt;");
  value.replace(">", "&gt;");
  value.replace("\"", "&quot;");
  value.replace("'", "&#39;");
  return value;
}

// =====================================================
// WIFI SCANNER
// =====================================================
String getWiFiOptions() {
  String options = "";
  int n = WiFi.scanNetworks();

  if (n <= 0) {
    options += "<option value=''>No WiFi found</option>";
  } else {
    for (int i = 0; i < n; i++) {
      String ssid = WiFi.SSID(i);
      int rssi = WiFi.RSSI(i);

      if (ssid.length() == 0) continue;

      String safeSSID = htmlEscape(ssid);

      options += "<option value='";
      options += safeSSID;
      options += "'>";
      options += safeSSID;
      options += " (";
      options += rssi;
      options += " dBm)";
      options += "</option>";
    }
  }

  WiFi.scanDelete();
  return options;
}

// =====================================================
// WIFI CONFIG PAGE
// =====================================================
String htmlPage() {
  String page = "";

  page += "<!DOCTYPE html>";
  page += "<html>";
  page += "<head>";
  page += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
  page += "<title>ESP32 WiFi Setup</title>";

  page += "<style>";
  page += "body{font-family:Arial;background:linear-gradient(135deg,#020617,#0f172a);color:white;padding:25px;}";
  page += ".card{max-width:460px;margin:auto;background:#111827;padding:25px;border-radius:18px;box-shadow:0 10px 30px rgba(0,0,0,.45);}";
  page += "h2{color:#38bdf8;margin-bottom:5px;}";
  page += "p{color:#cbd5e1;}";
  page += "label{display:block;margin-top:14px;margin-bottom:6px;color:#cbd5e1;font-size:14px;font-weight:bold;}";
  page += "input,select{width:100%;padding:13px;margin:6px 0;border-radius:10px;border:0;font-size:16px;box-sizing:border-box;}";
  page += "button{width:100%;padding:14px;border:0;border-radius:10px;background:#38bdf8;color:#020617;font-size:16px;font-weight:bold;margin-top:12px;}";
  page += ".danger{background:#ef4444;color:white;}";
  page += ".secondary{background:#334155;color:white;}";
  page += ".info{background:#1e293b;padding:12px;border-radius:10px;margin-top:15px;font-size:14px;line-height:1.6;}";
  page += ".small{font-size:12px;color:#94a3b8;margin-top:5px;}";
  page += "</style>";

  page += "<script>";
  page += "function useSelectedWifi(){";
  page += "var select=document.getElementById('ssidSelect');";
  page += "var input=document.getElementById('ssidInput');";
  page += "if(select.value){input.value=select.value;}";
  page += "}";
  page += "function refreshPage(){location.reload();}";
  page += "</script>";

  page += "</head>";
  page += "<body>";
  page += "<div class='card'>";

  page += "<h2>Smart Pothole ESP32</h2>";
  page += "<p>Setup WiFi Connection</p>";

  page += "<form action='/save' method='POST'>";

  page += "<label>Available WiFi</label>";
  page += "<select id='ssidSelect' onchange='useSelectedWifi()'>";
  page += "<option value=''>-- Select WiFi --</option>";
  page += getWiFiOptions();
  page += "</select>";

  page += "<button class='secondary' type='button' onclick='refreshPage()'>Refresh WiFi List</button>";

  page += "<label>WiFi SSID</label>";
  page += "<input id='ssidInput' name='ssid' placeholder='Select or type WiFi SSID' required>";

  page += "<label>WiFi Password</label>";
  page += "<input name='password' placeholder='WiFi Password' type='password'>";

  page += "<button type='submit'>Save & Restart</button>";
  page += "</form>";

  page += "<form action='/reset' method='POST'>";
  page += "<button class='danger' type='submit'>Clear WiFi Config</button>";
  page += "</form>";

  page += "<div class='info'>";
  page += "AP SSID: ";
  page += AP_SSID;
  page += "<br>";
  page += "AP Password: ";
  page += AP_PASSWORD;
  page += "<br>";
  page += "AP IP: 192.168.4.1<br>";
  page += "Serial Baud: 115200<br>";
  page += "Format:<br>";
  page += "GPS,lat,lng,speed,heading,pitch,roll,ax,ay,az,category,severity,wifiConnected,gpsFix,satellites,wifiSsid";
  page += "</div>";

  page += "<div class='small'>";
  page += "Note: If your WiFi is hidden, type the SSID manually.";
  page += "</div>";

  page += "</div>";
  page += "</body>";
  page += "</html>";

  return page;
}

void handleRoot() {
  server.send(200, "text/html", htmlPage());
}

void handleSave() {
  if (!server.hasArg("ssid")) {
    server.send(400, "text/plain", "SSID missing");
    return;
  }

  String ssid = server.arg("ssid");
  String password = server.arg("password");

  ssid.trim();

  if (ssid.length() == 0) {
    server.send(400, "text/plain", "SSID empty");
    return;
  }

  preferences.begin("wifi", false);
  preferences.putString("ssid", ssid);
  preferences.putString("password", password);
  preferences.end();

  String response = "";
  response += "<html><body style='font-family:Arial;background:#0f172a;color:white;text-align:center;padding-top:40px;'>";
  response += "<h2>WiFi saved</h2>";
  response += "<p>ESP32 restarting...</p>";
  response += "</body></html>";

  server.send(200, "text/html", response);

  delay(1500);
  ESP.restart();
}

void handleReset() {
  preferences.begin("wifi", false);
  preferences.clear();
  preferences.end();

  String response = "";
  response += "<html><body style='font-family:Arial;background:#0f172a;color:white;text-align:center;padding-top:40px;'>";
  response += "<h2>WiFi config cleared</h2>";
  response += "<p>ESP32 restarting...</p>";
  response += "</body></html>";

  server.send(200, "text/html", response);

  delay(1500);
  ESP.restart();
}

void startConfigPortal(bool stationConnected) {
  if (configPortalActive) return;

  configPortalOnly = !stationConnected;

  if (configPortalOnly) {
    WiFi.disconnect(false, false);
    delay(150);
    WiFi.mode(WIFI_AP);
  } else {
    WiFi.mode(WIFI_AP_STA);
  }

  WiFi.setSleep(false);
  WiFi.softAPdisconnect(true);
  delay(100);

  IPAddress apIp(192, 168, 4, 1);
  IPAddress gateway(192, 168, 4, 1);
  IPAddress subnet(255, 255, 255, 0);
  WiFi.softAPConfig(apIp, gateway, subnet);

  bool apStarted = WiFi.softAP(AP_SSID, AP_PASSWORD, 1, false, 4);

  if (!apStarted) {
    Serial.println("DEBUG:CONFIG PORTAL AP FAILED");
    return;
  }

  configPortalActive = true;

  IPAddress ip = WiFi.softAPIP();
  dnsServer.start(DNS_PORT, "*", ip);

  Serial.println("DEBUG:CONFIG PORTAL STARTED");
  Serial.print("DEBUG:AP SSID: ");
  Serial.println(AP_SSID);
  Serial.print("DEBUG:AP PASSWORD: ");
  Serial.println(AP_PASSWORD);
  Serial.print("DEBUG:AP IP: ");
  Serial.println(ip);
  Serial.print("DEBUG:AP MODE: ");
  Serial.println(configPortalOnly ? "AP_ONLY" : "AP_STA");
  Serial.print("DEBUG:AP CHANNEL: ");
  Serial.println(WiFi.channel());
  Serial.print("DEBUG:AP MAC: ");
  Serial.println(WiFi.softAPmacAddress());

  server.on("/", HTTP_GET, handleRoot);
  server.on("/save", HTTP_POST, handleSave);
  server.on("/reset", HTTP_POST, handleReset);
  server.onNotFound([]() {
    server.sendHeader("Location", "http://192.168.4.1/", true);
    server.send(302, "text/plain", "Open WiFi setup");
  });
  server.begin();
}

bool loadWiFiConfig() {
  preferences.begin("wifi", true);
  savedSSID = preferences.getString("ssid", "");
  savedPassword = preferences.getString("password", "");
  preferences.end();

  savedSSID.trim();

  return savedSSID.length() > 0;
}

void beginWiFiAttempt() {
  if (savedSSID.length() == 0 || wifiAttemptActive) return;

  WiFi.mode(WIFI_AP_STA);
  WiFi.setSleep(false);
  WiFi.begin(savedSSID.c_str(), savedPassword.c_str());
  wifiAttemptActive = true;
  wifiAttemptStartedAt = millis();

  Serial.print("DEBUG:WIFI BACKGROUND CONNECT TO ");
  Serial.println(savedSSID);
}

void checkWiFiReconnect() {
  const bool connected = WiFi.status() == WL_CONNECTED;

  if (connected) {
    wifiAttemptActive = false;
    configPortalOnly = false;

    if (!wifiWasConnected) {
      wifiWasConnected = true;
      Serial.print("DEBUG:WIFI CONNECTED SSID:");
      Serial.print(WiFi.SSID());
      Serial.print(" IP:");
      Serial.println(WiFi.localIP());
      initTime();
    }
    return;
  }

  if (wifiWasConnected) {
    wifiWasConnected = false;
    Serial.println("DEBUG:WIFI DISCONNECTED");
  }

  if (wifiAttemptActive) {
    if (millis() - wifiAttemptStartedAt < WIFI_ATTEMPT_TIMEOUT) return;

    wifiAttemptActive = false;
    WiFi.disconnect(false, false);
    Serial.println("DEBUG:WIFI BACKGROUND ATTEMPT TIMEOUT");
  }

  if (millis() - lastWiFiCheckTime < WIFI_CHECK_INTERVAL) return;
  lastWiFiCheckTime = millis();

  if (savedSSID.length() == 0) return;
  beginWiFiAttempt();
}

// =====================================================
// GPS SMART READ
// =====================================================
void smartDelay(unsigned long ms) {
  unsigned long start = millis();

  while (millis() - start < ms) {
    while (gpsSerial.available()) {
      gps.encode(gpsSerial.read());
    }
  }
}

// =====================================================
// LED STATUS
// =====================================================
void updateLedGPS() {
  int sat = gps.satellites.value();

  if (!gps.location.isValid()) {
    digitalWrite(LED_PIN, HIGH);
    return;
  }

  if (sat < 4) {
    if (millis() - lastBlinkTime > 300) {
      lastBlinkTime = millis();
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    }
    return;
  }

  digitalWrite(LED_PIN, LOW);
}

// =====================================================
// IMU DATA
// =====================================================
float normalizeHeading(float heading) {
  while (heading < 0) heading += 360;
  while (heading >= 360) heading -= 360;
  return heading;
}

float getImuHeading() {
  imu::Vector<3> euler =
      bno.getVector(Adafruit_BNO055::VECTOR_EULER);

  return normalizeHeading(euler.x());
}

float smoothHeading(float from, float to, float factor) {
  float diff = fmod((to - from + 540.0), 360.0) - 180.0;
  return normalizeHeading(from + diff * factor);
}

float getNavigationHeading() {
  bool gpsCourseUsable =
      gps.course.isValid() &&
      gps.speed.isValid() &&
      gps.speed.kmph() >= MIN_SPEED_DETECT;

  if (gpsCourseUsable) {
    float gpsHeading = normalizeHeading(gps.course.deg());

    if (!hasNavigationHeading) {
      lastNavigationHeading = gpsHeading;
      hasNavigationHeading = true;
    } else {
      lastNavigationHeading = smoothHeading(
        lastNavigationHeading,
        gpsHeading,
        0.35
      );
    }

    return lastNavigationHeading;
  }

  if (hasNavigationHeading) return lastNavigationHeading;

  return getImuHeading();
}

float getPitch() {
  imu::Vector<3> euler =
      bno.getVector(Adafruit_BNO055::VECTOR_EULER);

  return euler.y();
}

float getRoll() {
  imu::Vector<3> euler =
      bno.getVector(Adafruit_BNO055::VECTOR_EULER);

  return euler.z();
}

// =====================================================
// DEBUG IMU
// =====================================================
void printIMUStatus(float ax, float ay, float az) {
  if (millis() - lastImuDebugTime < 1000) return;
  lastImuDebugTime = millis();

  float magnitude = sqrt(ax * ax + ay * ay + az * az);

  uint8_t sys, gyro, accel, mag;
  bno.getCalibration(&sys, &gyro, &accel, &mag);

  Serial.print("DEBUG:IMU AX:");
  Serial.print(ax, 3);
  Serial.print(" AY:");
  Serial.print(ay, 3);
  Serial.print(" AZ:");
  Serial.print(az, 3);
  Serial.print(" MAG:");
  Serial.print(magnitude, 3);
  Serial.print(" HEAD:");
  Serial.print(getNavigationHeading(), 1);
  Serial.print(" IMU_HEAD:");
  Serial.print(getImuHeading(), 1);
  Serial.print(" PITCH:");
  Serial.print(getPitch(), 1);
  Serial.print(" ROLL:");
  Serial.print(getRoll(), 1);
  Serial.print(" CAL[");
  Serial.print(sys);
  Serial.print(",");
  Serial.print(gyro);
  Serial.print(",");
  Serial.print(accel);
  Serial.print(",");
  Serial.print(mag);
  Serial.println("]");
}

// =====================================================
// SERIAL TO FLUTTER
// FORMAT:
// GPS,lat,lng,speed,heading,pitch,roll,ax,ay,az,category,severity,
// wifiConnected,gpsFix,satellites,wifiSsid
// =====================================================
void sendSerialTelemetry(
  float ax,
  float ay,
  float az,
  const DetectionResult& detection
) {
  const int satellites = gps.satellites.isValid()
      ? gps.satellites.value()
      : 0;
  const bool gpsFix = gps.location.isValid() &&
                      gps.location.age() < 3000 &&
                      satellites >= 4;
  const bool wifiConnected = WiFi.status() == WL_CONNECTED;
  String wifiSsid = wifiConnected ? WiFi.SSID() : savedSSID;
  wifiSsid.replace(",", " ");

  Serial.print("GPS,");
  Serial.print(gpsFix ? gps.location.lat() : 0, 6);
  Serial.print(",");
  Serial.print(gpsFix ? gps.location.lng() : 0, 6);
  Serial.print(",");
  Serial.print(gps.speed.kmph(), 2);
  Serial.print(",");
  Serial.print(getNavigationHeading(), 1);
  Serial.print(",");
  Serial.print(getPitch(), 1);
  Serial.print(",");
  Serial.print(getRoll(), 1);
  Serial.print(",");
  Serial.print(ax, 2);
  Serial.print(",");
  Serial.print(ay, 2);
  Serial.print(",");
  Serial.print(az, 2);
  Serial.print(",");
  Serial.print(detection.category);
  Serial.print(",");
  Serial.print(detection.severity, 2);
  Serial.print(",");
  Serial.print(wifiConnected ? 1 : 0);
  Serial.print(",");
  Serial.print(gpsFix ? 1 : 0);
  Serial.print(",");
  Serial.print(satellites);
  Serial.print(",");
  Serial.println(wifiSsid);
}

// =====================================================
// DETECTION LOGIC
// =====================================================
DetectionResult detectRoadEvent(float ax, float ay, float az) {
  DetectionResult result = {false, "normal", 0};

  const unsigned long now = millis();
  const float speed = gps.speed.kmph();
  const float magnitude = sqrt(ax * ax + ay * ay + az * az);

  if (!roadEventActive) {
    result.severity = magnitude;

    if (speed >= MIN_SPEED_DETECT && magnitude >= EVENT_START_THRESHOLD) {
      roadEventActive = true;
      roadEventPeak = magnitude;
      roadEventSpeed = speed;
      roadEventStartedAt = now;
      roadEventLastImpactAt = now;
    }
    return result;
  }

  if (magnitude > roadEventPeak) {
    roadEventPeak = magnitude;
  }

  if (magnitude >= EVENT_RELEASE_THRESHOLD) {
    roadEventLastImpactAt = now;
  }

  const unsigned long duration = now - roadEventStartedAt;
  const bool released = now - roadEventLastImpactAt >= EVENT_RELEASE_MS;
  const bool timedOut = duration >= EVENT_MAX_MS;

  result.severity = roadEventPeak;

  if (!released && !timedOut) {
    return result;
  }

  const float peak = roadEventPeak;
  const float eventSpeed = roadEventSpeed;
  roadEventActive = false;
  roadEventPeak = 0;

  result.severity = peak;

  const bool sharpPothole = duration <= POTHOLE_MAX_DURATION_MS &&
                            peak >= POTHOLE_THRESHOLD;
  const bool severePothole = peak >= SEVERE_POTHOLE_THRESHOLD;

  if (eventSpeed >= POTHOLE_MIN_SPEED && (sharpPothole || severePothole)) {
    result.detected = true;
    result.category = "pothole";
    return result;
  }

  if (eventSpeed <= BUMPER_MAX_SPEED &&
      duration >= BUMPER_MIN_DURATION_MS &&
      peak >= BUMPER_THRESHOLD) {
    result.detected = true;
    result.category = "bumper";
  }

  return result;
}

// =====================================================
// SEND TO BACKEND
// =====================================================
void sendRoadTelemetry(
  String category,
  float severity,
  float ax,
  float ay,
  float az
) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("DEBUG:POST SKIPPED WIFI DISCONNECTED");
    return;
  }

  if (!gps.location.isValid()) {
    Serial.println("DEBUG:POST SKIPPED GPS INVALID");
    return;
  }

  if (gps.satellites.value() < 4) {
    Serial.println("DEBUG:POST SKIPPED GPS WEAK");
    return;
  }

  HTTPClient http;

  JsonDocument doc;

  doc["device_id"] = "Veloz_Hybrid_001";
  doc["category"] = category;
  doc["severity"] = severity;

  struct tm timeinfo;

  if (getLocalTime(&timeinfo)) {
    char buf[32];

    strftime(
      buf,
      sizeof(buf),
      "%Y-%m-%d %H:%M:%S",
      &timeinfo
    );

    doc["timestamp"] = buf;
  }

  JsonObject gpsObj = doc["gps"].to<JsonObject>();
  gpsObj["lat"] = gps.location.lat();
  gpsObj["lng"] = gps.location.lng();
  gpsObj["speed_kmh"] = gps.speed.kmph();
  gpsObj["satellites"] = gps.satellites.value();
  gpsObj["heading"] = getNavigationHeading();
  gpsObj["course_source"] =
      gps.course.isValid() && gps.speed.kmph() >= MIN_SPEED_DETECT
      ? "gps"
      : "imu_fallback";

  JsonObject orientation = doc["orientation"].to<JsonObject>();
  orientation["heading"] = getNavigationHeading();
  orientation["imu_heading"] = getImuHeading();
  orientation["pitch"] = getPitch();
  orientation["roll"] = getRoll();

  imu::Vector<3> gravity =
      bno.getVector(Adafruit_BNO055::VECTOR_GRAVITY);

  imu::Vector<3> gyro =
      bno.getVector(Adafruit_BNO055::VECTOR_GYROSCOPE);

  imu::Vector<3> magneto =
      bno.getVector(Adafruit_BNO055::VECTOR_MAGNETOMETER);

  imu::Vector<3> accelRaw =
      bno.getVector(Adafruit_BNO055::VECTOR_ACCELEROMETER);

  JsonObject sensor = doc["sensor"].to<JsonObject>();

  JsonObject linearAccel = sensor["linear_accel"].to<JsonObject>();
  linearAccel["x"] = ax;
  linearAccel["y"] = ay;
  linearAccel["z"] = az;

  JsonObject accel = sensor["accel_raw"].to<JsonObject>();
  accel["x"] = accelRaw.x();
  accel["y"] = accelRaw.y();
  accel["z"] = accelRaw.z();

  JsonObject gravityObj = sensor["gravity"].to<JsonObject>();
  gravityObj["x"] = gravity.x();
  gravityObj["y"] = gravity.y();
  gravityObj["z"] = gravity.z();

  JsonObject gyroObj = sensor["gyro"].to<JsonObject>();
  gyroObj["x"] = gyro.x();
  gyroObj["y"] = gyro.y();
  gyroObj["z"] = gyro.z();

  JsonObject magnetoObj = sensor["magneto"].to<JsonObject>();
  magnetoObj["x"] = magneto.x();
  magnetoObj["y"] = magneto.y();
  magnetoObj["z"] = magneto.z();

  sensor["temp_c"] = bno.getTemp();

  String payload;
  serializeJson(doc, payload);

  http.begin(SERVER_URL);
  http.setConnectTimeout(800);
  http.setTimeout(1200);
  http.addHeader("Content-Type", "application/json");

  int code = http.POST(payload);

  Serial.print("DEBUG:POST ");
  Serial.print(code);
  Serial.print(" CATEGORY:");
  Serial.print(category);
  Serial.print(" SEVERITY:");
  Serial.println(severity, 2);

  http.end();
}

// =====================================================
// GPS DEBUG
// =====================================================
void printGpsStatus() {
  if (millis() - lastGpsInfoTime < 1500) return;
  lastGpsInfoTime = millis();

  int sat = gps.satellites.value();

  Serial.print("DEBUG:GPS SAT:");
  Serial.print(sat);
  Serial.print(" | ");

  if (!gps.location.isValid()) {
    Serial.println("NO FIX");
    return;
  }

  if (sat <= 3) {
    Serial.println("WEAK SIGNAL");
  } else if (sat <= 5) {
    Serial.println("GOOD FIX");
  } else if (sat <= 8) {
    Serial.println("STRONG FIX");
  } else {
    Serial.println("EXCELLENT");
  }
}

// =====================================================
// SETUP
// =====================================================
void setup() {
  Serial.begin(115200);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  gpsSerial.begin(
    GPS_BAUD,
    SERIAL_8N1,
    RX_PIN,
    TX_PIN
  );

  Wire.begin();

  if (!bno.begin()) {
    Serial.println("DEBUG:BNO055 FAIL");
    while (1);
  }

  Serial.println("DEBUG:BNO055 OK");

  bno.setExtCrystalUse(true);
  resetPendingTelemetry();
  resetSerialTelemetry();

  const bool hasWiFiConfig = loadWiFiConfig();
  startConfigPortal(false);

  if (hasWiFiConfig) {
    beginWiFiAttempt();
  } else {
    Serial.println("DEBUG:NO WIFI CONFIG, AP READY FOR SETUP");
  }
}

// =====================================================
// LOOP
// =====================================================
void loop() {
  if (configPortalActive) {
    dnsServer.processNextRequest();
    server.handleClient();
  }

  checkWiFiReconnect();

  smartDelay(20);

  updateLedGPS();
  printGpsStatus();

  imu::Vector<3> linear =
      bno.getVector(
        Adafruit_BNO055::VECTOR_LINEARACCEL
      );

  float ax = linear.x();
  float ay = linear.y();
  float az = linear.z();

  printIMUStatus(ax, ay, az);

  DetectionResult detection = detectRoadEvent(ax, ay, az);
  accumulateTelemetry(detection, ax, ay, az);
  updateSerialTelemetry(detection);

  if (millis() - lastSerialTime >= SERIAL_INTERVAL) {
    sendSerialTelemetry(ax, ay, az, serialTelemetry);
    lastSerialTime = millis();
  }

  if (millis() - lastPostTime >= POST_INTERVAL) {
    Serial.print("DEBUG:TELEMETRY ");
    Serial.print(pendingTelemetry.category);
    Serial.print(" ");
    Serial.println(pendingTelemetry.severity, 2);

    const bool canPost = WiFi.status() == WL_CONNECTED &&
                         gps.location.isValid() &&
                         gps.location.age() < 3000 &&
                         gps.satellites.value() >= 4;

    if (canPost) {
      sendRoadTelemetry(
        pendingTelemetry.category,
        pendingTelemetry.severity,
        pendingAx,
        pendingAy,
        pendingAz
      );
    } else if (millis() - lastOfflineLogTime >= 5000) {
      lastOfflineLogTime = millis();
      Serial.print("DEBUG:SERVER WAIT WIFI:");
      Serial.print(WiFi.status() == WL_CONNECTED ? "OK" : "OFFLINE");
      Serial.print(" GPS:");
      Serial.println(gps.location.isValid() ? "NO_FIX" : "NO_DATA");
    }

    resetPendingTelemetry();
    lastPostTime = millis();
  }
}
