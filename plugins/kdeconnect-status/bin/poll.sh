#!/usr/bin/env bash
# Polls kdeconnectd over the user D-Bus for the first reachable+paired device
# and prints one line of JSON the widget can parse directly:
#   {"found":bool,"name":str,"reachable":bool,"charge":int,"charging":bool,"notifCount":int}
# Read-only: every busctl call here is a Get/call on kdeconnectd's own
# read-only properties and methods, nothing is ever set or sent.
set -euo pipefail

fail_json() {
    printf '{"found":false}\n'
    exit 0
}

command -v busctl >/dev/null 2>&1 || fail_json
command -v jq >/dev/null 2>&1 || fail_json

DEST=org.kde.kdeconnect

# First device id kdeconnectd currently reports as reachable+paired.
DEVID=$(busctl --user --json=short call "$DEST" /modules/kdeconnect \
    org.kde.kdeconnect.daemon devices bb false true 2>/dev/null \
    | jq -r '.data[0][0] // empty') || fail_json

[ -n "$DEVID" ] || fail_json

BASE="/modules/kdeconnect/devices/$DEVID"

get_prop() {
    # $1 = object path suffix, $2 = interface, $3 = property
    busctl --user --json=short get-property "$DEST" "$BASE$1" "$2" "$3" 2>/dev/null \
        | jq -r '.data'
}

NAME=$(get_prop "" org.kde.kdeconnect.device name)
REACHABLE=$(get_prop "" org.kde.kdeconnect.device isReachable)
CHARGE=$(get_prop /battery org.kde.kdeconnect.device.battery charge 2>/dev/null || echo -1)
CHARGING=$(get_prop /battery org.kde.kdeconnect.device.battery isCharging 2>/dev/null || echo false)

NOTIF_COUNT=$(busctl --user --json=short call "$DEST" "$BASE/notifications" \
    org.kde.kdeconnect.device.notifications activeNotifications 2>/dev/null \
    | jq -r '.data[0] | length' 2>/dev/null || echo 0)

jq -nc \
    --arg name "${NAME:-}" \
    --argjson reachable "${REACHABLE:-false}" \
    --argjson charge "${CHARGE:--1}" \
    --argjson charging "${CHARGING:-false}" \
    --argjson notifCount "${NOTIF_COUNT:-0}" \
    '{found:true,name:$name,reachable:$reachable,charge:$charge,charging:$charging,notifCount:$notifCount}'
