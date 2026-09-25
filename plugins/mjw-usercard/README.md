# User Card

A Ryoku desktop widget for the wallpaper stage, ported from the desktop widgets
of [end4-pC](https://github.com/pctrade/end4-pC) (a fork of
[illogical-impulse](https://github.com/end-4/dots-hyprland)).

Greeting, username/host, uptime and weather quip with lock, settings and session buttons wired to the real Ryoku surfaces.

## Install

Add the *MJ Widget Set* from Ryostore, or enable this plugin from the desktop's
**Add widget** menu. Place it like the built-in tiles: drag to move, drag the
corner bracket to scale, right-click for settings and colour.

## What runs, what it reads, what it writes

- Reads: whoami, hostname, /proc/uptime, os-release, weather topic
- Network: none
- Writes: the plugin's own state under
  `$XDG_STATE_HOME/ryoku/plugins/mjw-usercard` (style choices and widget data only).
  Nothing is written to shipped configs or other plugins' folders.
- Commands: whoami, ryoku-shell (session verbs)

## Colours

Auto colour follows the desktop palette (matugen / named scheme). The tile's
frosted glass tints the wallpaper behind it; every surface retints when the
theme changes.

License: GPL-3.0-only (see LICENSE, NOTICE). Original upstream code (c) pctrade,
end-4 and contributors.
