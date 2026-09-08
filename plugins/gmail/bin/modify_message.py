#!/usr/bin/env python3
"""Add/remove Gmail labels on a message or thread.

Usage: modify_message.py <message|thread> <id> [--add L1,L2] [--remove L1,L2]
Access token is read from the RYOKU_GMAIL_TOKEN environment variable
(gmail_config.runtime_token), never from argv.
Outputs JSON: { "success": true } or { "success": false, "error": "..." }
"""
import sys
import os
import json
import urllib.request
import urllib.error
import gmail_config


def main():
    if len(sys.argv) < 3:
        print(json.dumps({"success": False, "error": "Usage: modify_message.py <message|thread> <id> [--add ...] [--remove ...]"}))
        sys.exit(1)

    kind = sys.argv[1]
    obj_id = sys.argv[2]
    add_labels = []
    remove_labels = []

    i = 3
    while i < len(sys.argv):
        if sys.argv[i] == "--add" and i + 1 < len(sys.argv):
            add_labels = [x for x in sys.argv[i + 1].split(",") if x]
            i += 2
        elif sys.argv[i] == "--remove" and i + 1 < len(sys.argv):
            remove_labels = [x for x in sys.argv[i + 1].split(",") if x]
            i += 2
        else:
            i += 1

    try:
        token = gmail_config.resolve_token(gmail_config.runtime_token())
    except Exception as e:
        print(json.dumps({"success": False, "error": f"Token resolution error: {str(e)}"}))
        sys.exit(1)

    if not token:
        print(json.dumps({"success": False, "error": "Failed to resolve access token"}))
        sys.exit(1)

    resource = "threads" if kind == "thread" else "messages"
    url = f"https://gmail.googleapis.com/gmail/v1/users/me/{resource}/{obj_id}/modify"

    body = {}
    if add_labels:
        body["addLabelIds"] = add_labels
    if remove_labels:
        body["removeLabelIds"] = remove_labels

    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            print(json.dumps({"success": True, "status": resp.getcode(), "id": obj_id}))
    except urllib.error.HTTPError as e:
        print(json.dumps({"success": False, "code": e.code, "error": e.read(1024 * 1024).decode("utf-8", errors="replace")}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
