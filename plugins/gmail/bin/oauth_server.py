#!/usr/bin/env python3
"""One bounded, loopback-only OAuth/PKCE session; credentials never enter argv."""
import base64
import hashlib
import html
import http.server
import json
import secrets
import subprocess
import sys
import time
import urllib.parse
import urllib.request

import accounts_store
import gmail_config

PORT = 42069
AUTH_SECONDS = 180
SCOPES = "https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/gmail.send email profile"


def request_json(request):
    with urllib.request.urlopen(request, timeout=20) as response:
        data = response.read(1024 * 1024 + 1)
    if len(data) > 1024 * 1024:
        raise ValueError("OAuth response is too large")
    return json.loads(data)


class OAuthServer(http.server.HTTPServer):
    allow_reuse_address = True

    def __init__(self, credentials, port=PORT):
        self.client_id, self.client_secret = credentials
        self.state = secrets.token_urlsafe(32)
        self.verifier = secrets.token_urlsafe(48)
        self.result = None
        super().__init__(("127.0.0.1", port), Handler)
        self.redirect_uri = f"http://127.0.0.1:{self.server_port}/callback"

    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(5)
        return connection, address

    def authorization_url(self):
        challenge = base64.urlsafe_b64encode(
            hashlib.sha256(self.verifier.encode("ascii")).digest()
        ).decode("ascii").rstrip("=")
        return "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
            "response_type": "code",
            "scope": SCOPES,
            "access_type": "offline",
            "prompt": "consent",
            "code_challenge": challenge,
            "code_challenge_method": "S256",
            "state": self.state,
        })


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # The callback URL contains a short-lived authorization code.
        pass

    def reply(self, status, title, message):
        page = (
            "<!doctype html><html><body style='background:#111;color:#eee;"
            "font-family:sans-serif;padding:40px'><h2>" + html.escape(title) +
            "</h2><p>" + html.escape(message) + "</p></body></html>"
        ).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(page)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'")
        self.end_headers()
        self.wfile.write(page)

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path != "/callback":
            self.reply(404, "Not found", "This listener accepts only the OAuth callback.")
            return
        try:
            params = urllib.parse.parse_qs(parsed.query, max_num_fields=16, keep_blank_values=True)
        except ValueError:
            self.reply(400, "Invalid callback", "Too many callback fields.")
            return
        states = params.get("state", [])
        if len(states) != 1 or not secrets.compare_digest(states[0], self.server.state):
            self.reply(400, "Authorization rejected", "Invalid authorization state.")
            return  # An unrelated request must not cancel the real authorization.
        if "error" in params:
            self.server.result = {"error": "Authorization was declined."}
            self.reply(400, "Authorization declined", "Return to Ryoku to try again.")
            return
        codes = params.get("code", [])
        if len(codes) != 1 or not codes[0]:
            self.reply(400, "Invalid callback", "Exactly one authorization code is required.")
            return
        try:
            token_request = urllib.request.Request(
                "https://oauth2.googleapis.com/token",
                data=urllib.parse.urlencode({
                    "code": codes[0],
                    "client_id": self.server.client_id,
                    "client_secret": self.server.client_secret,
                    "redirect_uri": self.server.redirect_uri,
                    "grant_type": "authorization_code",
                    "code_verifier": self.server.verifier,
                }).encode("utf-8"),
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
            tokens = request_json(token_request)
            if not tokens.get("refresh_token") or not tokens.get("access_token"):
                raise ValueError("Google did not return the required tokens")
            profile = request_json(urllib.request.Request(
                "https://www.googleapis.com/oauth2/v2/userinfo",
                headers={"Authorization": "Bearer " + tokens["access_token"]},
            ))
            email = profile.get("email")
            if not isinstance(email, str) or not email or profile.get("verified_email") is not True:
                raise ValueError("Google did not return a verified account identity")
            accounts = accounts_store.get_accounts()
            account = {"email": email, "avatar": profile.get("picture", ""),
                       "refreshToken": tokens["refresh_token"]}
            accounts = [old for old in accounts if old.get("email") != email] + [account]
            accounts_store.save_accounts(accounts)
            self.server.result = {"success": True, "email": email, "picture": account["avatar"]}
            self.reply(200, "Authentication successful", "You can close this tab and return to Ryoku.")
        except Exception:
            # Do not reflect server responses, tokens, or credentials into HTML/logs.
            self.server.result = {"error": "Authorization could not be completed. Check credentials and connectivity, then retry."}
            self.reply(502, "Authorization failed", self.server.result["error"])


def main():
    credentials = tuple(value.strip().strip('"').strip("'") for value in gmail_config.get_credentials())
    if not all(credentials):
        print(json.dumps({"error": "Configure Google Desktop App credentials first."}), flush=True)
        return 1
    try:
        # Bind before opening a browser: a busy port must never send a code to
        # an unrelated listener, and no process is killed to reclaim the port.
        with OAuthServer(credentials) as server:
            subprocess.Popen(["xdg-open", server.authorization_url()],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            deadline = time.monotonic() + AUTH_SECONDS
            while server.result is None and time.monotonic() < deadline:
                server.timeout = min(1, max(0.01, deadline - time.monotonic()))
                server.handle_request()
            result = server.result or {"error": "Authorization timed out. Try again."}
        print(json.dumps(result), flush=True)
        return 0 if result.get("success") else 1
    except OSError:
        print(json.dumps({"error": "Cannot open the local OAuth listener or browser. Close any previous authorization attempt and retry."}), flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
