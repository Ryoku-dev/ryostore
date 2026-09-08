#!/usr/bin/env python3
"""Download an explicitly selected attachment without following or overwriting files."""
import base64
import json
import os
import sys
import urllib.parse
import urllib.request

import gmail_config

MAX_ATTACHMENT_BYTES = 50 * 1024 * 1024


def save_attachment(target_dir, filename, content):
    safe_name = os.path.basename(filename.replace("\\", "/"))
    safe_name = "".join(c for c in safe_name if ord(c) >= 32 and ord(c) != 127)
    if not safe_name or safe_name in (".", ".."):
        safe_name = "attachment"
    os.makedirs(target_dir, mode=0o700, exist_ok=True)
    directory = os.open(target_dir, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    base, extension = os.path.splitext(safe_name)
    try:
        counter = 0
        while True:
            candidate = safe_name if counter == 0 else f"{base} ({counter}){extension}"
            try:
                fd = os.open(candidate, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                             0o600, dir_fd=directory)
                break
            except FileExistsError:
                counter += 1
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(content)
        except BaseException:
            os.unlink(candidate, dir_fd=directory)
            raise
        return os.path.join(target_dir, candidate)
    finally:
        os.close(directory)


def main():
    if len(sys.argv) < 4:
        print(json.dumps({"error": "Missing attachment arguments."}))
        return 1
    message_id, attachment_id, filename = sys.argv[1:4]
    try:
        token = gmail_config.resolve_token(gmail_config.runtime_token())
        message = urllib.parse.quote(message_id, safe="")
        attachment = urllib.parse.quote(attachment_id, safe="")
        url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{message}/attachments/{attachment}"
        request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        with urllib.request.urlopen(request, timeout=30) as response:
            data = response.read(MAX_ATTACHMENT_BYTES * 4 // 3 + 4097)
        if len(data) > MAX_ATTACHMENT_BYTES * 4 // 3 + 4096:
            raise ValueError("Attachment exceeds the 50 MiB download limit")
        encoded = json.loads(data)["data"]
        raw_bytes = base64.b64decode(encoded + "=" * (-len(encoded) % 4), altchars=b"-_", validate=True)
        if len(raw_bytes) > MAX_ATTACHMENT_BYTES:
            raise ValueError("Attachment exceeds the 50 MiB download limit")
        target_dir = sys.argv[4] if len(sys.argv) > 4 else os.path.expanduser("~/Downloads")
        path = save_attachment(target_dir, filename, raw_bytes)
        print(json.dumps({"success": True, "path": path, "attachmentId": attachment_id}))
        return 0
    except Exception as error:
        print(json.dumps({"error": str(error), "attachmentId": attachment_id}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
