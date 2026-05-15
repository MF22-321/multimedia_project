#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// =======================
// WiFi
// =======================
const char* WIFI_SSID = "raiher";
const char* WIFI_PASSWORD = "Raiher22";

// =======================
// Firebase RTDB
// =======================
const char* FIREBASE_HOST = "https://smarthumidifier-9fd06-default-rtdb.asia-southeast1.firebasedatabase.app";
const char* FIREBASE_AUTH = "";

// =======================
// L298N Pin Mapping - ESP32 DevKit
// Motor 1 = Coffee, OUT1-OUT2
// Motor 2 = Lavender, OUT3-OUT4
// =======================
const int MOTOR1_ENA_PIN = 25;
const int MOTOR1_IN1_PIN = 26;
const int MOTOR1_IN2_PIN = 27;

const int MOTOR2_ENB_PIN = 33;
const int MOTOR2_IN3_PIN = 32;
const int MOTOR2_IN4_PIN = 14;

// =======================
// PWM config
// =======================
const uint32_t PWM_FREQ = 5000;
const uint8_t PWM_RES = 8;

// =======================
// Auto mode config
// ON tetap 5 detik
// OFF mengikuti autoInterval dari Firebase
// =======================
const unsigned long AUTO_ON_MS = 5000UL;

// =======================
// Firebase polling
// =======================
unsigned long lastPoll = 0;
const unsigned long pollIntervalMs = 700;

// =======================
// State from Firebase
// =======================
bool mainPower = false;
bool autoMode = false;
String autoInterval = "10s";

bool motor1Enabled = false;
int motor1SpeedLevel = 1;

bool motor2Enabled = false;
int motor2SpeedLevel = 1;

// =======================
// Applied/output helper state
// =======================
bool motor1WasRunning = false;
bool motor2WasRunning = false;

bool autoOutputState = false;

// Auto phase state
bool autoPhaseOn = true;
unsigned long autoPhaseStartMs = 0;

// =======================
// WiFi connect
// =======================
void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("WiFi connected. IP: ");
  Serial.println(WiFi.localIP());
}

// =======================
// Speed mapping
// Untuk DC motor + L298N, duty terlalu kecil sering cuma bunyi
// =======================
int speedLevelToDuty(int level) {
  switch (level) {
    case 1: return 230;
    case 2: return 245;
    case 3: return 255;
    default: return 0;
  }
}

// =======================
// Auto interval mapping
// =======================
unsigned long getAutoOffMs() {
  if (autoInterval == "10s") return 10000UL;
  if (autoInterval == "1m")  return 60000UL;
  if (autoInterval == "5m")  return 300000UL;
  return 10000UL;
}

void resetAutoPhase(bool startWithOn = true) {
  autoPhaseOn = startWithOn;
  autoPhaseStartMs = millis();
  autoOutputState = startWithOn;
}

// =======================
// Motor helpers
// =======================
void stopMotor(int in1Pin, int in2Pin, int enPin) {
  digitalWrite(in1Pin, LOW);
  digitalWrite(in2Pin, LOW);
  ledcWrite(enPin, 0);
}

void runMotorForward(int in1Pin, int in2Pin, int enPin, int duty, bool &motorWasRunning) {
  digitalWrite(in1Pin, HIGH);
  digitalWrite(in2Pin, LOW);

  // Kick-start supaya motor lebih gampang muter
  if (!motorWasRunning) {
    ledcWrite(enPin, 255);
    delay(200);
    motorWasRunning = true;
  }

  ledcWrite(enPin, duty);
}

// =======================
// Apply single motor
// =======================
void applySingleMotor(
  bool shouldRun,
  int speedLevel,
  int in1Pin,
  int in2Pin,
  int enPin,
  bool &motorWasRunning
) {
  if (!shouldRun) {
    stopMotor(in1Pin, in2Pin, enPin);
    motorWasRunning = false;
    return;
  }

  int duty = speedLevelToDuty(speedLevel);
  runMotorForward(in1Pin, in2Pin, enPin, duty, motorWasRunning);
}

// =======================
// Update auto scheduler
// =======================
void updateAutoScheduler() {
  unsigned long now = millis();
  unsigned long phaseDuration = autoPhaseOn ? AUTO_ON_MS : getAutoOffMs();

  if (now - autoPhaseStartMs >= phaseDuration) {
    autoPhaseOn = !autoPhaseOn;
    autoPhaseStartMs = now;

    if (autoPhaseOn) {
      Serial.print("AUTO ON | interval=");
      Serial.println(autoInterval);
      autoOutputState = true;
    } else {
      Serial.print("AUTO OFF | interval=");
      Serial.println(autoInterval);
      autoOutputState = false;
    }
  }
}

// =======================
// Apply all motors
// =======================
void applyMotorState() {
  if (!mainPower) {
    stopMotor(MOTOR1_IN1_PIN, MOTOR1_IN2_PIN, MOTOR1_ENA_PIN);
    stopMotor(MOTOR2_IN3_PIN, MOTOR2_IN4_PIN, MOTOR2_ENB_PIN);

    motor1WasRunning = false;
    motor2WasRunning = false;
    autoOutputState = false;
    return;
  }

  // Manual mode
  if (!autoMode) {
    applySingleMotor(
      motor1Enabled,
      motor1SpeedLevel,
      MOTOR1_IN1_PIN,
      MOTOR1_IN2_PIN,
      MOTOR1_ENA_PIN,
      motor1WasRunning
    );

    applySingleMotor(
      motor2Enabled,
      motor2SpeedLevel,
      MOTOR2_IN3_PIN,
      MOTOR2_IN4_PIN,
      MOTOR2_ENB_PIN,
      motor2WasRunning
    );

    return;
  }

  // Auto mode
  updateAutoScheduler();

  bool pulseOn = autoPhaseOn;

  applySingleMotor(
    motor1Enabled && pulseOn,
    motor1SpeedLevel,
    MOTOR1_IN1_PIN,
    MOTOR1_IN2_PIN,
    MOTOR1_ENA_PIN,
    motor1WasRunning
  );

  applySingleMotor(
    motor2Enabled && pulseOn,
    motor2SpeedLevel,
    MOTOR2_IN3_PIN,
    MOTOR2_IN4_PIN,
    MOTOR2_ENB_PIN,
    motor2WasRunning
  );
}

// =======================
// Fetch Firebase state
// =======================
bool fetchFirebaseState() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, reconnecting...");
    connectWiFi();
  }

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient https;

  String url = String(FIREBASE_HOST) + "/device.json";
  if (strlen(FIREBASE_AUTH) > 0) {
    url += "?auth=" + String(FIREBASE_AUTH);
  }

  if (!https.begin(client, url)) {
    Serial.println("HTTPS begin failed");
    return false;
  }

  int httpCode = https.GET();

  if (httpCode <= 0) {
    Serial.print("GET failed: ");
    Serial.println(https.errorToString(httpCode));
    https.end();
    return false;
  }

  if (httpCode != HTTP_CODE_OK) {
    Serial.print("Unexpected HTTP code: ");
    Serial.println(httpCode);
    https.end();
    return false;
  }

  String payload = https.getString();
  https.end();

  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, payload);

  if (err) {
    Serial.print("JSON parse error: ");
    Serial.println(err.c_str());
    return false;
  }

  bool newMainPower = doc["mainPower"] | false;
  bool newAutoMode = doc["autoMode"] | false;
  String newAutoInterval = String((const char*)(doc["autoInterval"] | "10s"));

  bool newMotor1Enabled = doc["motor1"]["enabled"] | false;
  int newMotor1SpeedLevel = doc["motor1"]["speedLevel"] | 1;

  bool newMotor2Enabled = doc["motor2"]["enabled"] | false;
  int newMotor2SpeedLevel = doc["motor2"]["speedLevel"] | 1;

  newMotor1SpeedLevel = constrain(newMotor1SpeedLevel, 1, 3);
  newMotor2SpeedLevel = constrain(newMotor2SpeedLevel, 1, 3);

  bool autoModeChanged = (newAutoMode != autoMode);
  bool autoIntervalChanged = (newAutoInterval != autoInterval);

  mainPower = newMainPower;
  autoMode = newAutoMode;
  autoInterval = newAutoInterval;

  motor1Enabled = newMotor1Enabled;
  motor1SpeedLevel = newMotor1SpeedLevel;

  motor2Enabled = newMotor2Enabled;
  motor2SpeedLevel = newMotor2SpeedLevel;

  if (autoModeChanged || autoIntervalChanged) {
    resetAutoPhase(true);
    Serial.print("Auto config changed -> autoMode=");
    Serial.print(autoMode);
    Serial.print(", autoInterval=");
    Serial.println(autoInterval);
  }

  Serial.print("Firebase -> power=");
  Serial.print(mainPower);
  Serial.print(", auto=");
  Serial.print(autoMode);
  Serial.print(", interval=");
  Serial.print(autoInterval);
  Serial.print(", m1=");
  Serial.print(motor1Enabled);
  Serial.print("/");
  Serial.print(motor1SpeedLevel);
  Serial.print(", m2=");
  Serial.print(motor2Enabled);
  Serial.print("/");
  Serial.println(motor2SpeedLevel);

  return true;
}

// =======================
// Setup
// =======================
void setup() {
  Serial.begin(115200);

  pinMode(MOTOR1_IN1_PIN, OUTPUT);
  pinMode(MOTOR1_IN2_PIN, OUTPUT);
  pinMode(MOTOR2_IN3_PIN, OUTPUT);
  pinMode(MOTOR2_IN4_PIN, OUTPUT);

  bool ok1 = ledcAttach(MOTOR1_ENA_PIN, PWM_FREQ, PWM_RES);
  bool ok2 = ledcAttach(MOTOR2_ENB_PIN, PWM_FREQ, PWM_RES);

  if (!ok1) Serial.println("LEDC attach failed for motor1");
  if (!ok2) Serial.println("LEDC attach failed for motor2");

  stopMotor(MOTOR1_IN1_PIN, MOTOR1_IN2_PIN, MOTOR1_ENA_PIN);
  stopMotor(MOTOR2_IN3_PIN, MOTOR2_IN4_PIN, MOTOR2_ENB_PIN);

  connectWiFi();
  resetAutoPhase(true);
}

// =======================
// Loop
// =======================
void loop() {
  if (millis() - lastPoll >= pollIntervalMs) {
    lastPoll = millis();
    fetchFirebaseState();
  }

  applyMotorState();
}