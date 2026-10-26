# 43PR bar for Ryoku

A community port of 43PR's joined, monochrome bar. Workspaces, open-app icons,
CPU/RAM badges, calendar, media marquee, volume, battery and connectivity retain
the upstream layout and interaction model. Colors follow Ryoku's active theme.
Hyprland is required for workspace actions; other modules use Quickshell services.

Select it in **Ryoku Hub > Bar** after installing from the Bar Styles category.
Right-click a module opens Ryoku bar settings, not the upstream settings app.
The former notification button opens Add-ons; power opens Graphics & Power.
No upstream notification daemon or power action is installed.

Commands run only on clicks: `ryoku-shell hub open <page>`,
`ryoku-shell bar settings`, `ryogami wallpaper ui`.
`nmcli -t -f TYPE,STATE device` reads connectivity every ten seconds.
The bar reads `/proc/stat`, `/proc/meminfo`, PipeWire, UPower, MPRIS and Hyprland.
No direct network access, privilege escalation or shell interpreter is used.
Settings write only `$XDG_CACHE_HOME/ryoku/43pr-bar.json` (default `~/.cache`).

The upstream layout controls remain available through the scoped IPC target
`43pr-bar`: `setPosition top|right|bottom|left`, `setStyle floating|joined|strip`,
`moveModule <id> start|center|end`, `shiftModule <id> <delta>`, and
`setStatsMode compact|default`. Call these on the active Ryoku Quickshell instance.
Defaults return if the cache is cleared. This is not a new Ryoku settings page.

Upstream and MIT license: see `PROVENANCE.txt` and `LICENSE`.
Maintenance of this adaptation: https://github.com/Sipper1236/ryostore/issues
