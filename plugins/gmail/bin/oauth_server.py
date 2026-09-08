#!/usr/bin/env python3
import http.server
import urllib.parse
import urllib.request
import urllib.error
import subprocess
import json
import secrets
import hashlib
import base64
import os
import sys
import time
import gmail_config
import accounts_store

PORT = 42069

# 1. Automatically kill any leftover process holding the port
try:
    subprocess.run(f"lsof -ti :{PORT} | xargs -r kill -9", shell=True, capture_output=True)
    time.sleep(0.3)
except Exception:
    pass

CLIENT_ID, CLIENT_SECRET = gmail_config.get_credentials()
CLIENT_ID = (CLIENT_ID or "").strip().strip('"').strip("'").strip()
CLIENT_SECRET = (CLIENT_SECRET or "").strip().strip('"').strip("'").strip()

if not CLIENT_ID or not CLIENT_SECRET:
    print(json.dumps({"error": "Missing GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET in gmail.env"}), flush=True)
    sys.exit(1)

REDIRECT_URI  = f"http://localhost:{PORT}/callback"
SCOPES        = "https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/gmail.send email profile"

# RFC 7636 compliant PKCE
code_verifier  = secrets.token_urlsafe(48)
code_challenge = base64.urlsafe_b64encode(
    hashlib.sha256(code_verifier.encode("ascii")).digest()
).decode("ascii").rstrip("=")

auth_url = (
    "https://accounts.google.com/o/oauth2/v2/auth?"
    + urllib.parse.urlencode({
        "client_id":             CLIENT_ID,
        "redirect_uri":          REDIRECT_URI,
        "response_type":         "code",
        "scope":                 SCOPES,
        "access_type":           "offline",
        "prompt":                "consent",
        "code_challenge":        code_challenge,
        "code_challenge_method": "S256",
    })
)

print(f"Opening browser for authorization: {auth_url}", flush=True)
subprocess.Popen(["xdg-open", auth_url])

result = {"done": False, "refresh": None, "email": None, "picture": None}

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # quiet

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        params = dict(urllib.parse.parse_qsl(parsed_url.query))

        if "error" in params:
            err_msg = params.get("error_description", params.get("error", "Authorization denied"))
            self.send_response(400)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(f"<html><body style=\"background:#111;color:#ff5252;font-family:sans-serif;padding:40px;\"><h2>Google Auth Error</h2><p>{err_msg}</p></body></html>".encode("utf-8"))
            result["done"] = True
            return

        if "code" not in params:
            self.send_response(400)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(b"<html><body style=\"background:#111;color:#ff5252;font-family:sans-serif;padding:40px;\"><h2>Error</h2><p>No authorization code returned in callback.</p></body></html>")
            result["done"] = True
            return

        # Exchange code for tokens
        token_data = urllib.parse.urlencode({
            "code":          params["code"],
            "client_id":     CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "redirect_uri":  REDIRECT_URI,
            "grant_type":    "authorization_code",
            "code_verifier": code_verifier,
        }).encode("utf-8")

        req = urllib.request.Request(
            "https://oauth2.googleapis.com/token",
            data=token_data,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )

        try:
            with urllib.request.urlopen(req) as resp:
                tokens = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            raw_err = e.read().decode("utf-8", errors="replace")
            print(f"[OAuth Server Error] HTTP {e.code}: {raw_err}", file=sys.stderr, flush=True)
            try:
                err_obj = json.loads(raw_err)
                err_code = err_obj.get("error", f"HTTP {e.code}")
                err_desc = err_obj.get("error_description", raw_err)
            except Exception:
                err_code = f"HTTP {e.code}"
                err_desc = raw_err

            self.send_response(400)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            err_html = f"""<!DOCTYPE html>
<html>
<body style="font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #111; color: #fff;">
  <div style="text-align: center; border: 1px solid #ff5252; padding: 40px; border-radius: 12px; background: #1a1a1a; max-width: 540px;">
    <h2 style="color: #ff5252; margin-top: 0;">Token Exchange Failed</h2>
    <p>Google returned <b>{err_code}</b></p>
    <p style="color: #ffb4a9; background: #3b0808; padding: 14px; border-radius: 8px; font-family: monospace; font-size: 13px; text-align: left; word-break: break-all;">{err_desc}</p>
    <p style="color: #aaa; font-size: 13px; margin-top: 20px;">If this is <code>redirect_uri_mismatch</code>, ensure your Google Cloud credentials were created as a <b>Desktop App</b> with Redirect URI: <code>{REDIRECT_URI}</code>.</p>
  </div>
</body>
</html>"""
            self.wfile.write(err_html.encode("utf-8"))
            result["done"] = True
            return
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(f"<html><body style=\"background:#111;color:#ff5252;padding:40px;\"><h2>Token Exchange Error</h2><p>{e}</p></body></html>".encode("utf-8"))
            result["done"] = True
            return

        refresh_token = tokens.get("refresh_token")
        access_token  = tokens.get("access_token")

        if not refresh_token:
            self.send_response(500)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(b"<html><body style=\"background:#111;color:#ff5252;padding:40px;\"><h2>Missing Refresh Token</h2><p>Google did not return a refresh token. Did you set prompt=consent?</p></body></html>")
            result["done"] = True
            return

        # Fetch user info
        userinfo_req = urllib.request.Request(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {access_token}"}
        )
        try:
            with urllib.request.urlopen(userinfo_req) as resp:
                userinfo = json.loads(resp.read().decode("utf-8"))
        except Exception as e:
            userinfo = {}

        email   = userinfo.get("email", "unknown")
        picture = userinfo.get("picture", "")

        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        html = f"""<!DOCTYPE html>
<html>
<body style="font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #111; color: #fff;">
  <div style="text-align: center; border: 1px solid #333; padding: 40px; border-radius: 12px; background: #1a1a1a;">
    <h2 style="color: #4ade80; margin-top: 0;">Authentication Successful!</h2>
    <p>Logged in as <b>{email}</b></p>
    <p style="color: #888;">You can close this tab and return to Ryoku.</p>
  </div>
</body>
</html>"""
        self.wfile.write(html.encode("utf-8"))

        result["refresh"] = refresh_token
        result["email"]   = email
        result["picture"] = picture
        result["done"]    = True

http.server.HTTPServer.allow_reuse_address = True
httpd = http.server.HTTPServer(("", PORT), Handler)
httpd.timeout = 180  # 3 minute timeout
while not result["done"]:
    httpd.handle_request()

httpd.server_close()

if result["done"] and result["refresh"]:
    # 1. Update accounts storage
    existing = accounts_store.get_accounts()
    updated = []
    found = False
    for acc in existing:
        if acc.get("email") == result["email"]:
            acc["refreshToken"] = result["refresh"]
            acc["avatar"] = result["picture"] or ""
            found = True
        updated.append(acc)
    if not found:
        updated.append({
            "email": result["email"],
            "avatar": result["picture"] or "",
            "refreshToken": result["refresh"]
        })
    accounts_store.save_accounts(updated)

    # 2. Output json on stdout
    print(json.dumps({
        "success": True,
        "refresh": result["refresh"],
        "email": result["email"],
        "picture": result["picture"]
    }), flush=True)

    # 3. Notify quickshell via IPC if available
    for cmd in [
        ["qs", "-c", "shell", "ipc", "call", "gmail", "onAuthComplete", result["refresh"], result["email"], result["picture"]],
        ["qs", "ipc", "call", "gmail", "onAuthComplete", result["refresh"], result["email"], result["picture"]]
    ]:
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
            if res.returncode == 0:
                break
        except Exception:
            pass
