#!/usr/bin/env python3
"""Send an email using Gmail API.
Input: JSON on stdin; token via RYOKU_GMAIL_TOKEN. Private mail never enters argv.
Outputs JSON: { "success": true } or { "success": false, "error": "<msg>" }
"""
import sys
import json
import base64
import urllib.request
import urllib.parse
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import mimetypes
import os
import gmail_config

def send_message(token, raw_msg, thread_id=None):
    payload = {"raw": raw_msg}
    if thread_id:
        payload["threadId"] = thread_id
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return gmail_config.read_json_response(resp)

def main():
    raw_input = sys.stdin.read(1024 * 1024 + 1)
    if len(raw_input) > 1024 * 1024:
        print(json.dumps({"success": False, "error": "Message input exceeds 1 MiB"}))
        return
    try:
        data = json.loads(raw_input)
        to_address = data["to"]
        subject = data["subject"]
        body_html = data["body"]
        cc_address = data.get("cc")
        bcc_address = data.get("bcc")
        thread_id = data.get("threadId")
        in_reply_to = data.get("inReplyTo")
        references = data.get("references")
        attachments = data.get("attachments", [])
    except (ValueError, KeyError, TypeError):
        print(json.dumps({"success": False, "error": "Invalid message input"}))
        return

    try:
        # 1. Resolve token (access or refresh)
        try:
            token = gmail_config.resolve_token(gmail_config.runtime_token())
        except Exception as e:
            print(json.dumps({"success": False, "error": f"Failed to get access token: {str(e)}"}))
            sys.exit(0)

        # 2. Build MIME message
        message = MIMEMultipart('mixed')
        message['To'] = to_address
        message['From'] = 'me'
        if cc_address:
            message['Cc'] = cc_address
        if bcc_address:
            message['Bcc'] = bcc_address
        message['Subject'] = subject

        if in_reply_to:
            message['In-Reply-To'] = in_reply_to
        if references:
            message['References'] = references

        alt_part = MIMEMultipart('alternative')
        html_part = MIMEText(body_html, 'html', 'utf-8')
        alt_part.attach(html_part)
        message.attach(alt_part)

        # Attachments
        remaining_bytes = 25 * 1024 * 1024 - len(body_html.encode("utf-8"))
        for att_path in attachments:
            if not os.path.isfile(att_path):
                raise FileNotFoundError("An attachment is no longer available")
            ctype, encoding = mimetypes.guess_type(att_path)
            if ctype is None or encoding is not None:
                ctype = 'application/octet-stream'
            maintype, subtype = ctype.split('/', 1)
            
            with open(att_path, 'rb') as f:
                part = MIMEBase(maintype, subtype)
                content = f.read(max(0, remaining_bytes) + 1)
                remaining_bytes -= len(content)
                if remaining_bytes < 0:
                    raise ValueError("Message attachments exceed 25 MiB")
                part.set_payload(content)
            
            encoders.encode_base64(part)
            filename = os.path.basename(att_path)
            part.add_header('Content-Disposition', 'attachment', filename=filename)
            message.attach(part)

        # 3. Base64url encode the message
        raw_msg = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8').rstrip('=')

        # 4. Send message
        try:
            response = send_message(token, raw_msg, thread_id)
            if 'id' in response:
                print(json.dumps({"success": True}))
            else:
                print(json.dumps({"success": False, "error": "Unknown API error"}))
        except Exception as e:
             print(json.dumps({"success": False, "error": f"Failed to send email: {str(e)}"}))
             
    except Exception as e:
        print(json.dumps({"success": False, "error": f"Internal error: {str(e)}"}))
        
    sys.exit(0)

if __name__ == "__main__":
    main()
