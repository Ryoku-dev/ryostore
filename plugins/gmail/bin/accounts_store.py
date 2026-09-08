#!/usr/bin/env python3
import sys
import json

import gmail_config

def get_accounts():
    raw = gmail_config.read_private_file("accounts.json")
    if not raw:
        return []
    accounts = json.loads(raw)
    if not isinstance(accounts, list) or not all(isinstance(account, dict) for account in accounts):
        raise ValueError("Gmail accounts must be an array of objects")
    return accounts


def save_accounts(accounts):
    if not isinstance(accounts, list) or not all(isinstance(account, dict) for account in accounts):
        raise ValueError("Gmail accounts must be an array of objects")
    gmail_config.write_private_file("accounts.json", json.dumps(accounts, indent=2) + "\n")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps(get_accounts()))
        sys.exit(0)

    cmd = sys.argv[1]
    if cmd == "get":
        print(json.dumps(get_accounts()))
    elif cmd == "save":
        payload = sys.stdin.read(1024 * 1024 + 1)
        try:
            parsed = json.loads(payload)
            save_accounts(parsed)
            print("OK")
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
