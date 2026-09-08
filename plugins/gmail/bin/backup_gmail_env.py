#!/usr/bin/env python3
import sys
import os

def main():
    if len(sys.argv) < 3:
        print("Usage: backup_gmail_env.py <client_id> <client_secret>", file=sys.stderr)
        sys.exit(1)

    client_id = sys.argv[1].strip()
    client_secret = sys.argv[2].strip()

    target_dir = os.path.expanduser("~/.config/ryoku")
    os.makedirs(target_dir, exist_ok=True)
    env_path = os.path.join(target_dir, "gmail.env")

    lines = []
    if os.path.exists(env_path):
        try:
            with open(env_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
        except Exception:
            lines = []

    keys_to_set = {
        "GOOGLE_CLIENT_ID": client_id,
        "GOOGLE_CLIENT_SECRET": client_secret
    }

    updated_keys = set()
    new_lines = []
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("#") and "=" in stripped:
            parts = stripped.split("=", 1)
            key = parts[0].strip()
            if key in keys_to_set or key in ("GMAIL_CLIENT_ID", "GMAIL_CLIENT_SECRET"):
                target_key = "GOOGLE_CLIENT_ID" if "ID" in key else "GOOGLE_CLIENT_SECRET"
                new_lines.append(f"{target_key}={keys_to_set[target_key]}\n")
                updated_keys.add(target_key)
                continue
        new_lines.append(line)

    for key, val in keys_to_set.items():
        if key not in updated_keys:
            new_lines.append(f"{key}={val}\n")

    with open(env_path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)

    try:
        os.chmod(env_path, 0o600)
    except Exception:
        pass

    # Also save to plugin dir .env as fallback
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        plugin_env = os.path.join(os.path.dirname(script_dir), ".env")
        with open(plugin_env, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
        os.chmod(plugin_env, 0o600)
    except Exception:
        pass

    print("Success")

if __name__ == "__main__":
    main()
