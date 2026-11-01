# PIA VPN

A Ryoku shell plugin (`pia-vpn`) for the `topbarGlyph` host. Shows live Private
Internet Access VPN status on the bar and gives full control from the panel:
connection state, public/VPN IP, current region, connect/disconnect, opening
the PIA desktop app, and a favorite-region switcher with a searchable browser
of every region PIA offers.

## Requirements

- PIA's official Linux desktop client, installed via the official installer
  from the Private Internet Access website (a differently-laid-out repackage,
  e.g. some third-party AUR packages, can break the hardcoded path below).
- That installer puts `piactl` on `PATH` -- it backs every status, connect,
  disconnect, and region call this plugin makes. It also installs the desktop
  GUI binary at the fixed path `/opt/piavpn/bin/pia-client`, which this plugin
  hardcodes for the OPEN APP button only; it is not a setting and is not
  auto-detected. If your install puts the GUI somewhere else, everything
  except OPEN APP still works, since the rest of the plugin only calls
  `piactl` (resolved from `PATH`, not a fixed path).

## What it does

- **Bar glyph**: a coloured dot (accent when Connected, dim otherwise) plus the
  current region id, elided to the bar's width budget. Left click only opens
  the panel -- no click on the bar mutates anything.
- **Panel**: connection state, region, public IP, VPN IP (while connected),
  CONNECT/DISCONNECT, OPEN APP (launches the PIA desktop client), a list of
  favorited regions (star to unfavorite, click the name to switch to it and
  reconnect), and a searchable scrollable list of every region (star to add a
  favorite, click the name to switch to it and reconnect).

## What it runs

Every external command is the system `piactl` (PIA's own CLI, declared in
`dependencies.commands`) or the PIA desktop binary at its fixed install path
`/opt/piavpn/bin/pia-client` (also declared there). All calls use an argv
array, never a shell string (R9):

- `piactl get connectionstate|region|pubip|vpnip` -- polled on a timer
  (`pollSeconds` setting) to refresh the panel and glyph.
- `piactl get regions` -- fetched once on load to populate the region browser.
- `piactl connect` / `piactl disconnect` -- the CONNECT/DISCONNECT button.
- `piactl set region <id>` then `piactl connect` -- switching to a favorite or
  browsed region (mirrors what the PIA dashboard itself does when you pick a
  region while connected).
- `/opt/piavpn/bin/pia-client --quiet` -- the OPEN APP button. PIA's own
  single-instance guard shows the existing dashboard if one is already
  running, rather than starting a second instance.

No `sudo`/`pkexec`, no network access of its own (`piactl` talks to the local
PIA daemon over its own socket, not something this plugin opens), no files
written outside the plugin's own settings.

## What it reads and writes

Reads: nothing off disk directly; all live state comes from `piactl` stdout.
Settings are read through `pluginApi.pluginSettings` behind a default (R5).

Writes: only the `favoriteRegions` setting, through `pluginApi.saveSetting`,
when you press the star next to a region. No other file is touched.

## Settings

| key             | type | default | description                                     |
| --------------- | ---- | ------- | ------------------------------------------------ |
| favoriteRegions | text | `[]`    | JSON array of favorited region ids; managed by the panel's star buttons, not meant for hand-editing |
| pollSeconds     | int  | 5       | How often the panel/glyph re-poll `piactl get ...` |

## Preview

Capture a real screenshot of the widget and save it as
`assets/preview-widget.png`, then list it under `files` in `manifest.json`. The
store shows it in the catalogue.

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

Enable and place it under **Ryoku Settings > Add-ons**, or find it directly on
the bar (installed with `--bar`).

## Author

Buxter <11074827+klopster@users.noreply.github.com>: this plugin is community-made (`official` is false).
