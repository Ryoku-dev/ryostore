#!/usr/bin/env bash
# Fetches this machine's public IPv4 from checkip.amazonaws.com and prints it
# trimmed, with no trailing newline. Prints nothing (exit 0) on any failure,
# so the widget can tell "no reading yet" from a real address.
set -euo pipefail

command -v curl >/dev/null 2>&1 || exit 0

ip=$(curl -fsS --max-time 5 https://checkip.amazonaws.com/ 2>/dev/null | tr -d '[:space:]') || exit 0

# Sanity-check it looks like an IPv4/IPv6 address before trusting it.
if [[ "$ip" =~ ^[0-9a-fA-F:.]+$ ]] && [ -n "$ip" ]; then
    printf '%s' "$ip"
fi
