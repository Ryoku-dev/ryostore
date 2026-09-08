#!/usr/bin/env python3
import sys
import json

import gmail_config

def main():
    payload = sys.stdin.read(16385)
    if len(payload) > 16384:
        raise ValueError("Credential input is too large")
    data = json.loads(payload)
    client_id = str(data["client_id"]).strip()
    client_secret = str(data["client_secret"]).strip()
    if not client_id or not client_secret or any(c in client_id + client_secret for c in "\r\n\x00"):
        raise ValueError("Credentials must be nonempty single-line values")
    gmail_config.write_private_file(
        "gmail.env",
        f"GOOGLE_CLIENT_ID={client_id}\nGOOGLE_CLIENT_SECRET={client_secret}\n",
    )
    print("Success")

if __name__ == "__main__":
    main()
