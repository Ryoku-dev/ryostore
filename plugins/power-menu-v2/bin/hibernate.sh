#!/usr/bin/env bash
# Lock the session, wait until the compositor lock is confirmed, then hibernate.
# Refuses to hibernate if the lock cannot be confirmed, so resume never lands
# on an open desktop.
set -u

last_state() {
  journalctl -t ryoku-idle -b -o cat --no-pager -g 'Wayland session got (locked|unlocked)' 2>/dev/null | tail -n 1
}

since=$(date '+%Y-%m-%d %H:%M:%S')
ryoku-shell lock || exit 1

locked=0
for _ in $(seq 1 50); do
  if journalctl -t ryoku-idle --since "$since" -o cat --no-pager 2>/dev/null | grep -q 'Wayland session got locked'; then
    locked=1
    break
  fi
  # Already locked before the call: no new event is emitted.
  if last_state | grep -q 'got locked'; then
    locked=1
    break
  fi
  sleep 0.2
done

if [ "$locked" -ne 1 ]; then
  notify-send -u critical "Power Menu V2" "Hibernate cancelled: screen lock was not confirmed." 2>/dev/null
  exit 1
fi

exec systemctl hibernate --check-inhibitors=no
