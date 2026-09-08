#!/usr/bin/env python3
import sys, urllib.request, urllib.error, json, os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import gmail_config

def main():
    if len(sys.argv) < 3:
        print(json.dumps({"success": False, "error": "Usage: delete_email.py <token_or_refresh> <message_id> [mode=trash|permanent|untrash]"}))
        sys.exit(1)

    token_arg = sys.argv[1]
    message_id = sys.argv[2]
    mode = sys.argv[3] if len(sys.argv) > 3 else "trash"

    # Safe token resolution
    try:
        token = gmail_config.resolve_token(token_arg)
        if not token:
            print(json.dumps({"success": False, "error": "Failed to resolve access token"}), flush=True)
            sys.exit(1)
    except Exception as e:
        print(json.dumps({"success": False, "error": f"Token resolution error: {str(e)}"}), flush=True)
        sys.exit(1)

    if mode == "trash":
        url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{message_id}/trash"
        method = "POST"
    elif mode == "untrash":
        url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{message_id}/untrash"
        method = "POST"
    else:
        url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{message_id}"
        method = "DELETE"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    data = b"{}" if method == "POST" else None

    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            status = resp.getcode()
            print(json.dumps({"success": True, "status": status, "id": message_id, "mode": mode}), flush=True)
            sys.exit(0)
    except urllib.error.HTTPError as e:
        raw_body = e.read().decode("utf-8", errors="replace")
        print(f"[delete_email] HTTP Error {e.code}: {raw_body}", file=sys.stderr, flush=True)
        print(json.dumps({"success": False, "code": e.code, "error": raw_body}), flush=True)
        sys.exit(1)
    except Exception as e:
        print(f"[delete_email] Error: {str(e)}", file=sys.stderr, flush=True)
        print(json.dumps({"success": False, "error": str(e)}), flush=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
