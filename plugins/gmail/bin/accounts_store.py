#!/usr/bin/env python3
import sys
import os
import json

ACCOUNTS_FILE = os.path.expanduser("~/.config/ryoku/gmail_accounts.json")

def get_accounts():
    if not os.path.exists(ACCOUNTS_FILE):
        return []
    try:
        with open(ACCOUNTS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
            if isinstance(data, dict) and "accounts" in data:
                return data["accounts"]
    except Exception:
        pass
    return []

def save_accounts(accounts):
    os.makedirs(os.path.dirname(ACCOUNTS_FILE), exist_ok=True)
    with open(ACCOUNTS_FILE, "w", encoding="utf-8") as f:
        json.dump(accounts, f, indent=2)
    try:
        os.chmod(ACCOUNTS_FILE, 0o600)
    except Exception:
        pass

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps(get_accounts()))
        sys.exit(0)

    cmd = sys.argv[1]
    if cmd == "get":
        print(json.dumps(get_accounts()))
    elif cmd == "save":
        payload = sys.argv[2] if len(sys.argv) > 2 else "[]"
        try:
            parsed = json.loads(payload)
            save_accounts(parsed)
            print("OK")
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
