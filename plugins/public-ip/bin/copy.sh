#!/usr/bin/env bash
# Copies the address given as $1 to the Wayland clipboard. $1 always arrives as
# its own argv element (never concatenated into a shell string), so this is
# safe even though the value comes from a previous network read.
set -euo pipefail

command -v wl-copy >/dev/null 2>&1 || exit 0
[ -n "${1:-}" ] || exit 0

printf '%s' "$1" | wl-copy
