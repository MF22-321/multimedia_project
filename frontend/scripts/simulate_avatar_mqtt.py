import json
import time

import paho.mqtt.client as mqtt


BROKER = "broker.hivemq.com"
PORT = 1883
STATE_TOPIC = "toyota/avatar/state"
WORD_TOPIC = "toyota/avatar/word"


def publish_json(client, topic, payload):
    client.publish(topic, json.dumps(payload), qos=1)


def main():
    client = mqtt.Client(client_id=f"toyota-avatar-sim-{int(time.time())}")
    client.connect(BROKER, PORT, keepalive=20)
    client.loop_start()

    publish_json(client, STATE_TOPIC, {"state": "thinking"})
    time.sleep(2.5)

    publish_json(client, STATE_TOPIC, {"state": "answering", "resetText": True})
    time.sleep(0.4)

    words = (
        "Halo saya Toyota Assistant. Saya siap membantu perjalanan kamu "
        "dengan informasi kendaraan, navigasi, hiburan, dan rekomendasi "
        "berkendara yang lebih nyaman."
    ).split()

    for word in words:
        client.publish(WORD_TOPIC, word, qos=1)
        time.sleep(0.18)

    time.sleep(2)
    publish_json(client, STATE_TOPIC, {"state": "idle"})

    time.sleep(0.5)
    client.loop_stop()
    client.disconnect()


if __name__ == "__main__":
    main()
