# Happ

A QS Bar glyph for the Happ proxy client: a status dot, the exit country's
flag and name, and the exit IP. Click it for a panel with the selected server,
city, provider, last check time, and two buttons (Refresh, Open Happ).

## What it runs

- `bin/happ-status local` every 5 s: `pgrep -x happd`, reads
  `/sys/class/net/happ-xray/{operstate,flags}`, and reads the single
  `lastServerName=` line of `~/.config/Happ.conf`. No network.
- `bin/happ-status geo` while the tunnel is up (every 120 s by default, on
  connect, on server change, and on Refresh): one HTTPS request to
  `https://ipinfo.io/json` through the tunnel. The country name is localised
  from the system `iso-codes` database via `gettext` (follows the system
  locale; set `HAPP_LANG` to override).
- `/opt/happ/bin/Happ` only when you click "Open Happ".

HTTPS is used on purpose: some Happ subscriptions route plain HTTP through a
different node, so an HTTP lookup can report the wrong exit.

## Language

Labels are English, or Russian when the system locale is Russian.

## Requirements

Happ desktop client installed at `/opt/happ` (AUR `happ-desktop-bin`), running
in TUN mode (interface `happ-xray`). `curl`, `jq`, `procps` (`pgrep`), `gettext`
and `iso-codes` for localised country names.

## What it reads and writes

Reads the files above. Writes nothing. No privileged commands.

## Network

`ipinfo.io` (HTTPS, no token, no identifiers sent beyond the request itself).
