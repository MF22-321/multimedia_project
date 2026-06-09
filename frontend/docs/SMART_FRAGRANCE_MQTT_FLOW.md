# Smart Fragrance MQTT Flow

Last updated: 2026-05-28

Dokumen ini menjelaskan kontrak MQTT untuk Smart Fragrance dari Flutter ke Arduino/ESP32.

## Topics

Flutter publish command ke:

```text
humidifier/control
```

Voice/AI command dari MQTTX dapat publish ke:

```text
toyota/fragrance/command
```

Device dapat publish state balik ke:

```text
humidifier/state
```

Topic `humidifier/state` sudah dipakai oleh `SmartFragrancePage` untuk sinkron state detail.

## Voice Command via MQTTX

Flutter subscribe `toyota/fragrance/command`, lalu menerjemahkan command ke
payload `humidifier/control` untuk ESP32.

### Nyalakan Semua Aroma

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m '{"action":"on","cartridge":3}'
```

### Matikan Smart Fragrance

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m '{"action":"off"}'
```

### Pilih Coffee

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m '{"action":"coffee"}'
```

### Pilih Lavender

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m '{"action":"lavender"}'
```

### Atur Kecepatan Semua Motor

Level valid: `1`, `2`, atau `3`.

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m '{"action":"speed","level":2}'
```

### Atur Kecepatan Aroma Tertentu

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m '{"action":"speed","target":"coffee","level":3}'
```

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m '{"action":"speed","target":"lavender","level":1}'
```

### Auto / Manual Mode

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m '{"action":"auto","interval":"10s"}'
```

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m '{"action":"manual"}'
```

Payload plain text juga diterima, misalnya:

```bash
mosquitto_pub -h broker.hivemq.com -p 1883 -t toyota/fragrance/command -m 'nyalakan lavender speed 2'
```

## Profile Shortcut

Bagian `ProfileSettingsPanel -> SmartFragranceSection` memakai tombol cartridge sebagai shortcut.

### Cartridge 1

Menyalakan coffee/motor1 dan mematikan lavender/motor2:

```json
{
  "selectedCartridge": 1,
  "mainPower": true,
  "autoMode": false,
  "motor1": {
    "enabled": true,
    "speedLevel": 3
  },
  "motor2": {
    "enabled": false,
    "speedLevel": 1
  }
}
```

### Cartridge 2

Menyalakan lavender/motor2 dan mematikan coffee/motor1:

```json
{
  "selectedCartridge": 2,
  "mainPower": true,
  "autoMode": false,
  "motor1": {
    "enabled": false,
    "speedLevel": 1
  },
  "motor2": {
    "enabled": true,
    "speedLevel": 3
  }
}
```

### Off

Jika user menekan cartridge yang sedang aktif, semua fragrance dimatikan:

```json
{
  "selectedCartridge": 0,
  "mainPower": false,
  "autoMode": false,
  "motor1": {
    "enabled": false,
    "speedLevel": 1
  },
  "motor2": {
    "enabled": false,
    "speedLevel": 1
  }
}
```

## Arduino Contract

Arduino/ESP32 perlu subscribe `humidifier/control`, parse JSON, lalu apply:

- `mainPower`
- `autoMode`
- `motor1.enabled`
- `motor1.speedLevel`
- `motor2.enabled`
- `motor2.speedLevel`

Jika device ingin UI detail ikut realtime, publish state terbaru ke `humidifier/state` dengan struktur yang sama.
