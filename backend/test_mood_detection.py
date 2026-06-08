import argparse
import json
import time
import urllib.error
import urllib.request


def request_json(url, method="GET", payload=None, timeout=5):
    body = None
    headers = {}

    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        url,
        data=body,
        headers=headers,
        method=method,
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def format_number(value, digits=3):
    if value is None:
        return "-"

    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return str(value)


def main():
    parser = argparse.ArgumentParser(
        description="Test drowsiness + mood detection from the FastAPI backend."
    )
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--driver", default="Test Driver")
    parser.add_argument("--seconds", type=float, default=30.0)
    parser.add_argument("--interval", type=float, default=0.8)
    parser.add_argument(
        "--no-start",
        action="store_true",
        help="Only poll /drowsiness_status without calling /start_drowsiness.",
    )
    parser.add_argument(
        "--stop",
        action="store_true",
        help="Call /stop_drowsiness when the test finishes.",
    )
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")

    try:
        if not args.no_start:
            start = request_json(
                f"{base_url}/start_drowsiness",
                method="POST",
                payload={"driver_name": args.driver},
            )
            print("START:", start)

        print("Polling status. Smile for happy, lower mouth corners for sad.")
        print("Press Ctrl+C to stop.\n")

        end_time = time.time() + args.seconds
        while time.time() < end_time:
            status = request_json(f"{base_url}/drowsiness_status")

            print(
                "active={active} | target={target} | recognized={recognized} | "
                "match={match} | face={face} | drowsy={drowsy} | "
                "mood={mood} ({mood_conf}) | raw={raw_mood} | "
                "hold={hold}/{required}s | happy={happy} | sad={sad} | "
                "EAR={ear} | ratio={ear_ratio} | closed={closed}s | "
                "reason={reason} | MAR={mar} | score={score}".format(
                    active=status.get("active"),
                    target=status.get("driver_name"),
                    recognized=status.get("recognized_driver"),
                    match=status.get("driver_match"),
                    face=status.get("face_position"),
                    drowsy=status.get("status"),
                    mood=status.get("mood", "unknown"),
                    mood_conf=format_number(status.get("mood_confidence")),
                    raw_mood=status.get("raw_mood", "unknown"),
                    hold=format_number(status.get("mood_candidate_elapsed"), 1),
                    required=format_number(status.get("mood_required_sec"), 1),
                    happy=format_number(status.get("smile_score")),
                    sad=format_number(status.get("sadness_score")),
                    ear=format_number(status.get("ear")),
                    ear_ratio=format_number(status.get("ear_ratio")),
                    closed=format_number(status.get("eye_closed_elapsed"), 1),
                    reason=status.get("alert_reason") or "-",
                    mar=format_number(status.get("mar")),
                    score=format_number(status.get("score")),
                )
            )

            time.sleep(args.interval)

    except KeyboardInterrupt:
        print("\nStopped by user.")
    except urllib.error.URLError as e:
        print(f"Cannot connect to backend: {e}")
        print("FastAPI is not running on the same base URL.")
        print("\nStart it from the project root:")
        print("  cd /home/febrian/development/multimedia_project")
        print("  python -m uvicorn backend.fastAPI.main:app --host 127.0.0.1 --port 8000")
        print("\nThen run this test from the project root:")
        print("  python backend/test_mood_detection.py --driver Febrian")
    finally:
        if args.stop:
            try:
                stop = request_json(f"{base_url}/stop_drowsiness", method="POST")
                print("STOP:", stop)
            except Exception as e:
                print(f"Failed to stop monitoring: {e}")


if __name__ == "__main__":
    main()
