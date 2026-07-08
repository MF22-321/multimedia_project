// Toyota trainer kit ESP32
// MQTT:
// - toyota/avatar/state    {"state":"thinking"} / {"state":"idle","closePopup":true}
// - toyota/ambient         {"command":"RGB","r":92,"g":225,"b":255,"brightness":200}
// - toyota/ambient         {"command":"AURORA"} / FIRE / RAINBOW / COMET / BREATHE / OCEAN
// - humidifier/control     {"mainPower":true,"motor1":{"enabled":true},"motor2":{"enabled":true}}

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <FastLED.h>
#include <esp_wifi.h>

const char* WIFI_SSID = "K1-TLC";
const char* WIFI_PASSWORD = "Tr@ining-K1";

const char* MQTT_BROKER = "broker.hivemq.com";
const int MQTT_PORT = 1883;

const char* AVATAR_STATE_TOPIC = "toyota/avatar/state";
const char* AMBIENT_TOPIC = "toyota/ambient";
const char* AMBIENT_STATE_TOPIC = "toyota/ambient/state";
const char* HUMIDIFIER_CONTROL_TOPIC = "humidifier/control";

WiFiClient espClient;
PubSubClient mqttClient(espClient);

#define LED_PIN1 5
#define LED_PIN2 6
#define NUM_LEDS_PER_STRIP 28
#define CHIPSET WS2812B
#define COLOR_ORDER GRB
#define DEFAULT_BRIGHTNESS 200
#define FRAMES_PER_SECOND 60
#define RELAY_PIN 18
#define SPEAKER_SWITCH_PIN 15
#define HUMIDIFIER_PIN 21

#define COOLING 55
#define SPARKING 120

CRGB leds1[NUM_LEDS_PER_STRIP];
CRGB leds2[NUM_LEDS_PER_STRIP];

enum LedMode {
  MODE_OFF,
  MODE_SOLID_COLOR,
  MODE_FIRE,
  MODE_HAPPY,
  MODE_SAD,
  MODE_AURORA,
  MODE_RAINBOW,
  MODE_COMET,
  MODE_BREATHE,
  MODE_OCEAN
};

LedMode currentMode = MODE_FIRE;
CRGB solidColor = CRGB::White;
uint8_t currentBrightness = DEFAULT_BRIGHTNESS;
bool ledsAreOn = true;
bool humidifierIsOn = false;
bool gReverseDirection = false;

unsigned long lastMqttReconnectAttempt = 0;
const unsigned long MQTT_RECONNECT_INTERVAL = 3000;

void connectWiFi();
bool reconnectMQTT();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void handleSerialCommands();

bool executeAmbientCommand(String command, JsonDocument* doc = nullptr);
void setSolidColor(CRGB color, const char* colorName);
void setMode(LedMode mode, const char* modeName);
void showSolidColorNow();
void publishAmbientState(const char* command);
void handleAvatarState(const String& message);
void handleAmbientPayload(const String& message);
void handleHumidifierPayload(const String& message);
void setHumidifier(bool turnOn);

void runSolidColorMode();
void runFireMode();
void runHappyMode();
void runSadMode();
void runAuroraMode();
void runRainbowMode();
void runCometMode();
void runBreatheMode();
void runOceanMode();

void setup() {
  delay(1500);
  Serial.begin(115200);

  pinMode(SPEAKER_SWITCH_PIN, OUTPUT);
  digitalWrite(SPEAKER_SWITCH_PIN, LOW);

  pinMode(HUMIDIFIER_PIN, OUTPUT);
  setHumidifier(false);

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);

  FastLED.addLeds<CHIPSET, LED_PIN1, COLOR_ORDER>(leds1, NUM_LEDS_PER_STRIP)
      .setCorrection(TypicalLEDStrip);
  FastLED.addLeds<CHIPSET, LED_PIN2, COLOR_ORDER>(leds2, NUM_LEDS_PER_STRIP)
      .setCorrection(TypicalLEDStrip);
  FastLED.setBrightness(currentBrightness);

  Serial.println("------------------------------------");
  Serial.println("Toyota ESP32 Ambient Light Ready");
  Serial.println("MQTT topic: toyota/ambient");
  Serial.println("Payload RGB: {\"command\":\"RGB\",\"r\":92,\"g\":225,\"b\":255}");
  Serial.println("Payload preset: {\"command\":\"AURORA\"}");
  Serial.println("------------------------------------");

  connectWiFi();
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastWiFiRetry = 0;
    if (millis() - lastWiFiRetry > 5000) {
      lastWiFiRetry = millis();
      connectWiFi();
    }
  } else if (!mqttClient.connected()) {
    if (millis() - lastMqttReconnectAttempt > MQTT_RECONNECT_INTERVAL) {
      lastMqttReconnectAttempt = millis();
      reconnectMQTT();
    }
  }

  mqttClient.loop();
  handleSerialCommands();

  FastLED.setBrightness(ledsAreOn ? currentBrightness : 0);

  switch (currentMode) {
    case MODE_SOLID_COLOR: runSolidColorMode(); break;
    case MODE_FIRE: runFireMode(); break;
    case MODE_HAPPY: runHappyMode(); break;
    case MODE_SAD: runSadMode(); break;
    case MODE_AURORA: runAuroraMode(); break;
    case MODE_RAINBOW: runRainbowMode(); break;
    case MODE_COMET: runCometMode(); break;
    case MODE_BREATHE: runBreatheMode(); break;
    case MODE_OCEAN: runOceanMode(); break;
    case MODE_OFF:
    default:
      fill_solid(leds1, NUM_LEDS_PER_STRIP, CRGB::Black);
      fill_solid(leds2, NUM_LEDS_PER_STRIP, CRGB::Black);
      break;
  }

  FastLED.show();
  FastLED.delay(1000 / FRAMES_PER_SECOND);
}

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.print("Connecting WiFi: ");
  Serial.println(WIFI_SSID);

  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  esp_wifi_set_ps(WIFI_PS_NONE);
  WiFi.disconnect();
  delay(250);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long startAttempt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < 12000) {
    delay(400);
    Serial.print(".");
  }

  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi connected, IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.print("WiFi failed, status=");
    Serial.println(WiFi.status());
  }
}

bool reconnectMQTT() {
  if (WiFi.status() != WL_CONNECTED) return false;
  if (mqttClient.connected()) return true;

  String clientId = "ToyotaAmbientESP32-";
  clientId += String(random(0xffff), HEX);

  Serial.print("Connecting MQTT... ");
  if (!mqttClient.connect(clientId.c_str())) {
    Serial.print("failed rc=");
    Serial.println(mqttClient.state());
    return false;
  }

  Serial.println("connected");
  mqttClient.subscribe(AVATAR_STATE_TOPIC);
  mqttClient.subscribe(AMBIENT_TOPIC);
  mqttClient.subscribe(HUMIDIFIER_CONTROL_TOPIC);
  publishAmbientState("BOOT");
  return true;
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  message.reserve(length + 1);
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }

  Serial.println();
  Serial.print("MQTT Topic: ");
  Serial.println(topic);
  Serial.print("MQTT Payload: ");
  Serial.println(message);

  String topicString = String(topic);
  if (topicString == AVATAR_STATE_TOPIC) {
    handleAvatarState(message);
  } else if (topicString == AMBIENT_TOPIC) {
    handleAmbientPayload(message);
  } else if (topicString == HUMIDIFIER_CONTROL_TOPIC) {
    handleHumidifierPayload(message);
  }
}

void handleAvatarState(const String& message) {
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, message);
  if (error) {
    Serial.print("Avatar JSON failed: ");
    Serial.println(error.c_str());
    return;
  }

  String state = doc["state"] | "";
  bool closePopup = doc["closePopup"] | false;

  if (state == "thinking") {
    digitalWrite(SPEAKER_SWITCH_PIN, HIGH);
    Serial.println("SpeakerSwitch HIGH");
  } else if (state == "idle" && closePopup) {
    digitalWrite(SPEAKER_SWITCH_PIN, LOW);
    Serial.println("SpeakerSwitch LOW");
  }
}

void handleAmbientPayload(const String& message) {
  StaticJsonDocument<384> doc;
  DeserializationError error = deserializeJson(doc, message);
  if (error) {
    Serial.print("Ambient JSON failed: ");
    Serial.println(error.c_str());
    Serial.println("Expected: {\"command\":\"AURORA\"}");
    return;
  }

  String command = doc["command"] | "";
  if (command.length() == 0) {
    command = doc["preset"] | "";
  }
  bool ok = executeAmbientCommand(command, &doc);
  if (!ok) {
    Serial.print("Unknown ambient command: ");
    Serial.println(command);
  }
}

void handleHumidifierPayload(const String& message) {
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, message);
  if (error) {
    Serial.print("Humidifier JSON failed: ");
    Serial.println(error.c_str());
    return;
  }

  bool mainPower = doc["mainPower"] | false;
  bool motor1 = doc["motor1"]["enabled"] | false;
  bool motor2 = doc["motor2"]["enabled"] | false;
  setHumidifier(mainPower && (motor1 || motor2));
}

void setHumidifier(bool turnOn) {
  humidifierIsOn = turnOn;
  digitalWrite(HUMIDIFIER_PIN, humidifierIsOn ? HIGH : LOW);
  Serial.print("Humidifier ");
  Serial.println(humidifierIsOn ? "ON" : "OFF");
}

bool executeAmbientCommand(String command, JsonDocument* doc) {
  command.trim();
  command.toUpperCase();
  if (command.length() == 0 && doc != nullptr && (*doc)["power"].is<bool>()) {
    command = ((*doc)["power"].as<bool>()) ? "ON" : "OFF";
  }

  if (doc != nullptr && (*doc)["brightness"].is<int>()) {
    currentBrightness = constrain((*doc)["brightness"].as<int>(), 1, 255);
    FastLED.setBrightness(currentBrightness);
  }

  bool recognized = true;

  if (command == "ON") {
    ledsAreOn = true;
    if (currentMode == MODE_OFF) currentMode = MODE_AURORA;
  } else if (command == "OFF") {
    ledsAreOn = false;
    currentMode = MODE_OFF;
  } else if (command == "RGB") {
    int r = doc == nullptr ? 255 : constrain((*doc)["r"] | 255, 0, 255);
    int g = doc == nullptr ? 255 : constrain((*doc)["g"] | 255, 0, 255);
    int b = doc == nullptr ? 255 : constrain((*doc)["b"] | 255, 0, 255);
    setSolidColor(CRGB(r, g, b), "RGB");
  } else if (command == "RED") {
    setSolidColor(CRGB::Red, "RED");
  } else if (command == "GREEN") {
    setSolidColor(CRGB::Green, "GREEN");
  } else if (command == "BLUE") {
    setSolidColor(CRGB::Blue, "BLUE");
  } else if (command == "LAVENDER") {
    setSolidColor(CRGB::Lavender, "LAVENDER");
  } else if (command == "MAGENTA") {
    setSolidColor(CRGB::Magenta, "MAGENTA");
  } else if (command == "PINK") {
    setSolidColor(CRGB::DeepPink, "PINK");
  } else if (command == "VIOLET") {
    setSolidColor(CRGB::Violet, "VIOLET");
  } else if (command == "AQUA") {
    setSolidColor(CRGB::Aqua, "AQUA");
  } else if (command == "YELLOW") {
    setSolidColor(CRGB::Yellow, "YELLOW");
  } else if (command == "GOLD") {
    setSolidColor(CRGB::Gold, "GOLD");
  } else if (command == "GRAY") {
    setSolidColor(CRGB::Gray, "GRAY");
  } else if (command == "WHITE") {
    setSolidColor(CRGB::White, "WHITE");
  } else if (command == "CYAN") {
    setSolidColor(CRGB::Cyan, "CYAN");
  } else if (command == "ORANGE") {
    setSolidColor(CRGB::Orange, "ORANGE");
  } else if (command == "FIRE") {
    setMode(MODE_FIRE, "FIRE");
  } else if (command == "HAPPY") {
    setMode(MODE_HAPPY, "HAPPY");
  } else if (command == "SAD") {
    setMode(MODE_SAD, "SAD");
  } else if (command == "AURORA") {
    setMode(MODE_AURORA, "AURORA");
  } else if (command == "RAINBOW") {
    setMode(MODE_RAINBOW, "RAINBOW");
  } else if (command == "COMET") {
    setMode(MODE_COMET, "COMET");
  } else if (command == "BREATHE") {
    setMode(MODE_BREATHE, "BREATHE");
  } else if (command == "OCEAN") {
    setMode(MODE_OCEAN, "OCEAN");
  } else {
    recognized = false;
  }

  if (recognized) {
    ledsAreOn = true;
    if (command == "OFF") ledsAreOn = false;
    publishAmbientState(command.c_str());
  }

  return recognized;
}

void setSolidColor(CRGB color, const char* colorName) {
  ledsAreOn = true;
  currentMode = MODE_SOLID_COLOR;
  solidColor = color;
  showSolidColorNow();
  Serial.print("Solid color: ");
  Serial.println(colorName);
}

void setMode(LedMode mode, const char* modeName) {
  ledsAreOn = true;
  currentMode = mode;
  Serial.print("Mode: ");
  Serial.println(modeName);
}

void showSolidColorNow() {
  FastLED.setBrightness(currentBrightness);
  fill_solid(leds1, NUM_LEDS_PER_STRIP, solidColor);
  fill_solid(leds2, NUM_LEDS_PER_STRIP, solidColor);
  FastLED.show();
}

void publishAmbientState(const char* command) {
  if (!mqttClient.connected()) return;

  StaticJsonDocument<192> doc;
  doc["power"] = ledsAreOn;
  doc["command"] = command;
  doc["brightness"] = currentBrightness;
  doc["r"] = solidColor.r;
  doc["g"] = solidColor.g;
  doc["b"] = solidColor.b;

  char buffer[192];
  size_t size = serializeJson(doc, buffer);

  mqttClient.publish(
    AMBIENT_STATE_TOPIC,
    (const uint8_t*)buffer,
    size,
    true
  );
}

void handleSerialCommands() {
  if (!Serial.available()) return;

  String command = Serial.readStringUntil('\n');
  command.trim();
  command.toUpperCase();
  if (command.length() == 0) return;

  if (command == "FRESH AIR" || command == "HUMIDIFIER ON") {
    setHumidifier(true);
  } else if (command == "STOP FRESH AIR" || command == "HUMIDIFIER OFF") {
    setHumidifier(false);
  } else if (command == "AC ON") {
    digitalWrite(RELAY_PIN, HIGH);
  } else if (command == "AC OFF") {
    digitalWrite(RELAY_PIN, LOW);
  } else if (command == "SPEAKER ON") {
    digitalWrite(SPEAKER_SWITCH_PIN, HIGH);
  } else if (command == "SPEAKER OFF") {
    digitalWrite(SPEAKER_SWITCH_PIN, LOW);
  } else {
    executeAmbientCommand(command);
  }
}

void runSolidColorMode() {
  fill_solid(leds1, NUM_LEDS_PER_STRIP, solidColor);
  fill_solid(leds2, NUM_LEDS_PER_STRIP, solidColor);
}

void runFireMode() {
  static uint8_t heat[NUM_LEDS_PER_STRIP];
  for (int i = 0; i < NUM_LEDS_PER_STRIP; i++) {
    heat[i] = qsub8(heat[i], random8(0, ((COOLING * 10) / NUM_LEDS_PER_STRIP) + 2));
  }
  for (int k = NUM_LEDS_PER_STRIP - 1; k >= 2; k--) {
    heat[k] = (heat[k - 1] + heat[k - 2] + heat[k - 2]) / 3;
  }
  if (random8() < SPARKING) {
    int y = random8(7);
    heat[y] = qadd8(heat[y], random8(160, 255));
  }
  for (int j = 0; j < NUM_LEDS_PER_STRIP; j++) {
    int pixel = gReverseDirection ? (NUM_LEDS_PER_STRIP - 1) - j : j;
    CRGB color = HeatColor(heat[j]);
    leds1[pixel] = color;
    leds2[pixel] = color;
  }
}

void runHappyMode() {
  static uint8_t hue = 0;
  fill_rainbow(leds1, NUM_LEDS_PER_STRIP, hue, 7);
  fill_rainbow(leds2, NUM_LEDS_PER_STRIP, hue, 7);
  hue++;
}

void runSadMode() {
  uint8_t value = beatsin8(10, 30, 120);
  fill_solid(leds1, NUM_LEDS_PER_STRIP, CHSV(HUE_BLUE, 255, value));
  fill_solid(leds2, NUM_LEDS_PER_STRIP, CHSV(HUE_BLUE, 255, value));
}

void runAuroraMode() {
  uint16_t beat = beatsin16(8, 0, 65535);
  for (int i = 0; i < NUM_LEDS_PER_STRIP; i++) {
    uint8_t hue = 96 + sin8(i * 12 + beat / 256) / 3;
    CRGB color = CHSV(hue, 190, 220);
    leds1[i] = color;
    leds2[NUM_LEDS_PER_STRIP - 1 - i] = color;
  }
}

void runRainbowMode() {
  static uint8_t hue = 0;
  fill_rainbow(leds1, NUM_LEDS_PER_STRIP, hue, 5);
  fill_rainbow(leds2, NUM_LEDS_PER_STRIP, hue + 40, 5);
  hue += 2;
}

void runCometMode() {
  fadeToBlackBy(leds1, NUM_LEDS_PER_STRIP, 36);
  fadeToBlackBy(leds2, NUM_LEDS_PER_STRIP, 36);
  uint8_t pos = beatsin8(20, 0, NUM_LEDS_PER_STRIP - 1);
  leds1[pos] += solidColor;
  leds2[NUM_LEDS_PER_STRIP - 1 - pos] += solidColor;
}

void runBreatheMode() {
  uint8_t value = beatsin8(12, 35, 230);
  CRGB color = solidColor;
  color.nscale8_video(value);
  fill_solid(leds1, NUM_LEDS_PER_STRIP, color);
  fill_solid(leds2, NUM_LEDS_PER_STRIP, color);
}

void runOceanMode() {
  static uint8_t offset = 0;
  for (int i = 0; i < NUM_LEDS_PER_STRIP; i++) {
    uint8_t wave = sin8(i * 18 + offset);
    CRGB color = blend(CRGB(0, 40, 120), CRGB(0, 220, 255), wave);
    leds1[i] = color;
    leds2[i] = color;
  }
  offset += 3;
}
