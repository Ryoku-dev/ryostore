#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.parse
import urllib.error

def get_env_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    plugin_dir = os.path.dirname(script_dir)
    return [
        os.path.expanduser("~/.config/ryoku/gmail.env"),
        os.path.join(plugin_dir, ".env"),
        os.path.expanduser("~/.config/ryoku/.env")
    ]

def _load_env():
    env = {}
    for p in get_env_paths():
        if os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('#') and '=' in line:
                            k, v = line.split('=', 1)
                            key = k.strip()
                            val = v.strip().strip('"').strip("'")
                            if key not in env and val:
                                env[key] = val
            except Exception:
                pass
    return env

_file_env = _load_env()

CLIENT_ID = (
    os.environ.get("GOOGLE_CLIENT_ID")
    or os.environ.get("GMAIL_CLIENT_ID")
    or _file_env.get("GOOGLE_CLIENT_ID")
    or _file_env.get("GMAIL_CLIENT_ID")
    or ""
)

CLIENT_SECRET = (
    os.environ.get("GOOGLE_CLIENT_SECRET")
    or os.environ.get("GMAIL_CLIENT_SECRET")
    or _file_env.get("GOOGLE_CLIENT_SECRET")
    or _file_env.get("GMAIL_CLIENT_SECRET")
    or ""
)

def reload_credentials():
    global CLIENT_ID, CLIENT_SECRET
    env = _load_env()
    CLIENT_ID = (
        os.environ.get("GOOGLE_CLIENT_ID")
        or os.environ.get("GMAIL_CLIENT_ID")
        or env.get("GOOGLE_CLIENT_ID")
        or env.get("GMAIL_CLIENT_ID")
        or ""
    )
    CLIENT_SECRET = (
        os.environ.get("GOOGLE_CLIENT_SECRET")
        or os.environ.get("GMAIL_CLIENT_SECRET")
        or env.get("GOOGLE_CLIENT_SECRET")
        or env.get("GMAIL_CLIENT_SECRET")
        or ""
    )
    return CLIENT_ID, CLIENT_SECRET

def get_credentials():
    if not CLIENT_ID or not CLIENT_SECRET:
        reload_credentials()
    return CLIENT_ID, CLIENT_SECRET

def has_credentials():
    cid, sec = get_credentials()
    return bool(cid and sec)

def refresh_token_exchange(refresh_token):
    cid, sec = get_credentials()
    if not cid or not sec:
        raise Exception("Missing GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET in gmail.env or environment")

    data = urllib.parse.urlencode({
        "refresh_token": refresh_token,
        "client_id":     cid,
        "client_secret": sec,
        "grant_type":    "refresh_token",
    }).encode('utf-8')

    req = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )

    try:
        with urllib.request.urlopen(req) as resp:
            body = json.loads(resp.read().decode('utf-8'))
            return body
    except urllib.error.HTTPError as e:
        try:
            error_body = e.read().decode('utf-8')
            parsed = json.loads(error_body)
            err_code = parsed.get("error", "http_error")
            if err_code == "invalid_grant":
                raise ValueError("invalid_grant")
        except ValueError:
            raise
        except Exception:
            pass
        raise Exception(f"HTTP {e.code}: {e.reason}")

def resolve_token(token_or_refresh):
    """
    Returns an access token string.
    If input starts with 'ya29.', it's assumed to be a valid access token.
    Otherwise, it's treated as a refresh token and exchanged.
    """
    if not token_or_refresh:
        return ""
    if token_or_refresh.startswith("ya29."):
        return token_or_refresh
    res = refresh_token_exchange(token_or_refresh)
    if isinstance(res, dict):
        return res.get("access_token", "")
    return str(res)

if __name__ == "__main__":
    print(f"Has credentials: {has_credentials()}")
