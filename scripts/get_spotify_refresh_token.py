#!/usr/bin/env python3
import base64
import json
import os
import secrets
import stat
import sys
import threading
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


CLIENT_ID = "790dba056ed74025adbf60b5a0bcf45d"
CLIENT_SECRET = "943045b5faea4c60a1a7e1100a232780"
REDIRECT_URI = os.environ.get(
    "SPOTIFY_REDIRECT_URI",
    "http://127.0.0.1:8888/callback",
)
SCOPES = "user-modify-playback-state user-read-playback-state"
TOKEN_PATH = Path(
    os.environ.get(
        "SPOTIFY_REFRESH_TOKEN_FILE",
        str(Path.home() / ".config/multimedia_project/spotify_token.json"),
    )
)


def main() -> int:
    callback = CallbackServer(REDIRECT_URI)
    callback.start()
    state = secrets.token_urlsafe(16)

    auth_url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode(
        {
            "client_id": CLIENT_ID,
            "response_type": "code",
            "redirect_uri": REDIRECT_URI,
            "scope": SCOPES,
            "state": state,
        }
    )

    print("Open this URL in a browser, login Spotify, then paste the redirected URL.")
    print("This script is listening locally, so the callback page should say success.")
    print()
    print(auth_url)
    print()
    print("Redirect URI must be registered in the Spotify app dashboard:")
    print(f"  {REDIRECT_URI}")
    print()

    try:
        code = callback.wait_for_code()
    finally:
        callback.stop()

    if not code:
        print("No code received from Spotify callback.", file=sys.stderr)
        return 1

    token = exchange_code(code)
    refresh_token = token.get("refresh_token")
    if not refresh_token:
        print("Spotify response has no refresh_token.", file=sys.stderr)
        return 1

    TOKEN_PATH.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_PATH.write_text(
        json.dumps({"refresh_token": refresh_token}, indent=2) + "\n",
        encoding="utf-8",
    )
    TOKEN_PATH.chmod(stat.S_IRUSR | stat.S_IWUSR)

    print()
    print(f"Saved refresh token to: {TOKEN_PATH}")
    print("Restart the Flutter app from the same user account.")
    return 0


class CallbackServer:
    def __init__(self, redirect_uri: str) -> None:
        parsed = urllib.parse.urlparse(redirect_uri)
        self.host = parsed.hostname or "127.0.0.1"
        self.port = parsed.port or 8888
        self.path = parsed.path or "/callback"
        self.code = ""
        self.error = ""
        self.error_description = ""
        self._event = threading.Event()
        self._server = HTTPServer((self.host, self.port), self._handler())
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)

    def start(self) -> None:
        self._thread.start()

    def wait_for_code(self) -> str:
        print("Waiting for Spotify callback...")
        self._event.wait()
        if self.error:
            print(
                f"Spotify callback error: {self.error} {self.error_description}",
                file=sys.stderr,
            )
        return self.code

    def stop(self) -> None:
        self._server.shutdown()
        self._server.server_close()

    def _handler(self):
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self) -> None:
                parsed = urllib.parse.urlparse(self.path)
                params = urllib.parse.parse_qs(parsed.query)
                owner.code = (params.get("code") or [""])[0]
                owner.error = (params.get("error") or [""])[0]
                owner.error_description = (
                    params.get("error_description") or [""]
                )[0]

                ok = bool(owner.code)
                if not ok and not owner.error:
                    self.send_response(200)
                    self.send_header("Content-Type", "text/plain; charset=utf-8")
                    self.end_headers()
                    self.wfile.write(
                        (
                            "Callback server is running, but this URL has no "
                            "Spotify code yet.\nOpen the Spotify authorize URL "
                            "from the terminal and finish login.\n"
                        ).encode("utf-8")
                    )
                    print(f"Ignored empty callback: {self.path}", file=sys.stderr)
                    return

                body = (
                    "Spotify authorization received. You can close this tab."
                    if ok
                    else (
                        "Spotify authorization failed. Check the terminal.\n"
                        f"Error: {owner.error}\n"
                        f"{owner.error_description}\n"
                    )
                )
                self.send_response(200 if ok else 400)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.end_headers()
                self.wfile.write(body.encode("utf-8"))
                owner._event.set()

            def log_message(self, format: str, *args) -> None:
                return

        return Handler


def exchange_code(code: str) -> dict:
    credentials = base64.b64encode(
        f"{CLIENT_ID}:{CLIENT_SECRET}".encode("utf-8")
    ).decode("ascii")
    body = urllib.parse.urlencode(
        {
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": REDIRECT_URI,
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=body,
        headers={
            "Authorization": f"Basic {credentials}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"Spotify token exchange failed: {error.code} {detail}"
        ) from error


if __name__ == "__main__":
    raise SystemExit(main())
