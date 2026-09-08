#!/usr/bin/env python3
import json
import os
import gmail_config

def main():
    cid, sec = gmail_config.get_credentials()
    print(json.dumps({
        "client_id": cid,
        "client_secret": sec
    }))

if __name__ == "__main__":
    main()
