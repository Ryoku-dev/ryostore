# GoXLR

A Ryoku shell plugin (`goxlr`) that ports the core of the Noctalia GoXLR
plugin: a bar capsule showing one channel's volume, a mic-mute toggle, a
flash-style notification when any channel changes, and per-channel volume
controls in the panel. It talks to the [goxlr-utility](https://github.com/GoXLR-on-Linux/goxlr-utility)
daemon's local HTTP API — the same daemon the official GoXLR app and the
Noctalia plugin use.

## Requirements

- `goxlr-utility`'s `goxlr-daemon` running and reachable (default
  `localhost:14564`).
- `curl` and `jq` on `PATH` (listed in `dependencies.commands`).

## What it does (and deliberately does not)

Ported:

- **Bar capsule**: shows one configured channel's volume (icon, value, or
  both), coloured to reflect connection/mute state.
- **Flash as OSD substitute**: Ryoku bar plugins don't get an OSD surface the
  way Noctalia widgets can, so instead of a popup, the capsule itself
  temporarily switches to show whichever channel just changed — glyph, name,
  and new value — for `flashTimeoutMs`, then reverts to the configured
  channel. This happens for changes from any source: the GoXLR hardware
  itself, the vendor app, or another copy of this plugin on a second
  monitor.
- **Mic mute**: right-click the capsule to toggle the mic's cough/mute.
- **Per-channel volumes**: left-click opens the panel, which lists every
  channel with a slider and shows live mute state.

Not ported (out of scope for this port): routing matrix, effects/FX
presets, sampler, lighting, and profile switching. These are higher-risk,
higher-surface-area features that don't fit a single bar capsule + panel;
they're better served by the full GoXLR app for now.

## Settings

| key              | type   | default        | description                                                 |
| ---------------- | ------ | -------------- | ------------------------------------------------------------ |
| host             | text   | `localhost`    | Daemon host                                                   |
| port             | int    | `14564`        | Daemon port                                                   |
| refreshMs        | int    | `1000`         | Poll interval while the panel is closed (ms)                  |
| volumeDisplay    | choice | `percent`      | Show volumes as percent or raw (0-255)                        |
| channel          | choice | `Mic`          | Channel shown on the bar                                      |
| display          | choice | `glyph_value`  | Bar display: icon only, icon + value, or value only           |
| glyph            | text   | `◆`            | Bar icon: a literal character/emoji, or (with `glyphStyle: icon`) a [Material Symbols](https://fonts.google.com/icons) ligature name like `mic`; the mute icon stays `✖` |
| glyphStyle       | choice | `text`         | Interpret `glyph` as literal text/emoji, or as a Material Symbols icon name |
| showChannelName  | toggle | `false`        | Prefix the bar value with the channel name                    |
| scrollStep       | int    | `2`            | Volume change per scroll notch on the capsule (%)              |
| muteIndicator    | toggle | `true`         | Change colour while the shown channel is muted                 |
| hideWhenAbsent   | toggle | `false`        | Hide the capsule entirely when no GoXLR is connected            |
| flashEnabled     | toggle | `true`         | Flash the capsule when any channel's volume or mute changes     |
| flashTimeoutMs   | int    | `1500`         | How long the flash stays up (ms)                               |
| flashPollMs      | int    | `200`          | Poll interval while watching for changes to flash (ms)          |

## Usage

- **Left click** the capsule: open/close the panel (per-channel volume
  sliders and mute states).
- **Right click** the capsule: toggle mic mute.
- **Scroll** over the capsule: adjust the configured channel's volume by
  `scrollStep`.

## `bin/` scripts (for compositor keybinds)

Two standalone scripts talk to the daemon directly over HTTP, independent of
the plugin runtime, for binding to Hyprland/compositor keybinds:

- `bin/mic-mute-toggle` — toggles the mic's cough/mute.
- `bin/volume-step <channel> <percent>` — nudges a channel's volume by a
  signed percent (defaults: `Mic 2`).

Both honour `GOXLR_HOST`/`GOXLR_PORT` env vars (default
`localhost:14564`). `ryoku plugin validate` flags an `undeclared-host`
warning on both — expected, since the host comes from a shell variable the
static analyzer can't resolve to a literal; it is non-blocking.

## What it reads and writes

Reads: GoXLR channel volumes and mute state from the daemon's HTTP API only
(`localhost`/`127.0.0.1` per `capabilities.network`). Writes: volume/mute
commands back to the same daemon API, and plugin settings via
`pluginApi.saveSetting`. No files, no privileged actions, no other hosts.

## Preview

See `assets/preview-widget.png`.

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

It lists under **Community** in QS Bar Settings. Publish it only when you
want to share it: `ryoku plugin share goxlr`.

## Author

josh <josh@example.com>: this plugin is community-made (`official` is
false).
