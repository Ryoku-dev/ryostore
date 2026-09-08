#!/usr/bin/env python3
import os
import secrets
import stat
import re
import json
import urllib.request
import urllib.parse
import urllib.error

def _state_dir_fd():
    """Open the private namespace without following product-controlled symlinks."""
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    if not os.path.isabs(base):
        raise ValueError("XDG_STATE_HOME must be an absolute path")
    os.makedirs(base, mode=0o700, exist_ok=True)
    fd = os.open(base, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in ("ryoku", "plugins", "gmail"):
            try:
                os.mkdir(part, mode=0o700, dir_fd=fd)
            except FileExistsError:
                pass
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        if os.fstat(fd).st_uid != os.getuid():
            raise PermissionError("Gmail state directory is not owned by this user")
        os.fchmod(fd, 0o700)
        return fd
    except BaseException:
        os.close(fd)
        raise


def _private_name(name):
    if name not in ("gmail.env", "accounts.json") and not re.fullmatch(r"message-[0-9a-f]{64}\.html", name):
        raise ValueError("Unknown Gmail private file")
    return name


def read_private_file(name):
    name = _private_name(name)
    directory = _state_dir_fd()
    try:
        try:
            fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        except FileNotFoundError:
            return ""
        with os.fdopen(fd, "r", encoding="utf-8") as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                raise PermissionError("Gmail private file must be an owned regular file")
            os.fchmod(stream.fileno(), 0o600)
            text = stream.read(1024 * 1024 + 1)
            if len(text) > 1024 * 1024:
                raise ValueError("Gmail private file exceeds 1 MiB")
            return text
    finally:
        os.close(directory)


def write_private_file(name, text):
    name = _private_name(name)
    if len(text.encode("utf-8")) > 1024 * 1024:
        raise ValueError("Gmail private file exceeds 1 MiB")
    directory = _state_dir_fd()
    temporary = "." + name + "." + secrets.token_hex(12)
    try:
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=directory)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        # Replacing a link replaces the link itself, never its target.
        os.replace(temporary, name, src_dir_fd=directory, dst_dir_fd=directory)
        os.fsync(directory)
        return os.path.join(os.readlink(f"/proc/self/fd/{directory}"), name)
    finally:
        try:
            os.unlink(temporary, dir_fd=directory)
        except FileNotFoundError:
            pass
        os.close(directory)


def runtime_token():
    """Tokens are inherited privately by helpers, never exposed in process argv."""
    return os.environ.get("RYOKU_GMAIL_TOKEN", "")

def read_json_response(response, limit=64 * 1024 * 1024):
    data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Gmail response exceeds the size limit")
    return json.loads(data)



def _load_env():
    values = {}
    for line in read_private_file("gmail.env").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values

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
        with urllib.request.urlopen(req, timeout=20) as resp:
            body = read_json_response(resp, limit=1024 * 1024)
            return body
    except urllib.error.HTTPError as e:
        try:
            error_body = e.read(1024 * 1024).decode('utf-8')
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
