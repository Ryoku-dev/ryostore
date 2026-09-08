#!/usr/bin/env python3
import sys, json, urllib.request, urllib.parse
import gmail_config

refresh_token = gmail_config.runtime_token()

try:
    res = gmail_config.refresh_token_exchange(refresh_token)
    if isinstance(res, dict):
        token = res.get("access_token", "")
        expires = res.get("expires_in", 3600)
    else:
        token = str(res)
        expires = 3600

    print(json.dumps({
        "access_token": token,
        "expires_in": expires
    }))
except Exception as e:
    sys.exit(1)
