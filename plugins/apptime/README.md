# App Time

A Ryoku shell plugin that answers "what did I actually do on this machine?".
It watches Hyprland focus events, banks foreground time per app per day, pauses
while you are idle, and shows your **top apps in hours and minutes** in a panel
under its bar glyph — for today or any archived day.

## What it looks like

- **Bar glyph**: a small clock + today's total (e.g. `3h 12m`). Left click
  opens the panel. Hover/open tints it with the live accent.
- **Panel**: `TODAY` header with the day total and ‹ › chevrons to browse the
  per-day archive (click the date to jump back to today). Each app row has a
  rank, name, accent usage bar (relative to the leader) and its time in hours
  & minutes — no seconds.

Theming comes from the plugin kit's `Theme`/`Scheme` singletons, which resolve
the daemon palette (a fixed named scheme or the live wallpaper colours), so
the widget retints with the desktop like every other Ryoku component.

## What it runs, reads, and writes

- **Runs**: nothing external. No subprocesses, no shell, no network, no
  privileged calls. All data stays on the machine.
- **Reads**:
  - Hyprland focus events and the toplevel list through `Quickshell.Hyprland`
    (same source as the built-in dock): `activewindowv2`, `closewindow`, and
    each window's class.
  - Real input-idle state through `Quickshell.Wayland` `IdleMonitor`, the
    Wayland `ext-idle-notify` protocol — keyboard *and* pointer, tracked by
    the compositor, honouring idle inhibitors (caffeine).
- **Writes** (all under `$XDG_STATE_HOME/ryoku/plugins/apptime/`, atomic
  temp+rename):
  - `today.json` — live day, every 15 s and on unload.
  - `usage-YYYY-MM-DD.json` — one archive file per finished day.
  - `history.json` — index of archived days.

## Settings (QS Bar Settings > Community > App Time)

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `glyphTotal` | toggle | on | Show today's total next to the bar clock |
| `topCount` | int | 5 | How many apps the panel lists (1–10) |
| `idleMinutes` | int | 5 | Pause counting after this many idle minutes (0 = off) |

## Behaviour notes / honest limits

- Time counts only while a **regular window holds focus** (foreground use).
  Layer surfaces like the bar never count.
- **Idle**: after `idleMinutes` without real input the tally freezes; moving
  the mouse or typing resumes the same app. Idle inhibitors (the caffeine
  toggle) suspend the pause. If you never lock your screen, this is the
  guard against counting a machine you walked away from.
- Windows that are not "using an app" are excluded: `hyprlock`, XDG desktop
  portals.
- **Granularity is per app class**, not per window: every Firefox window is
  one "Firefox" entry.
- Each day is archived at local midnight and browsable from the panel; the
  archive is kept in `usage-*.json` files (no automatic pruning yet).
- App labels are a heuristic from the WM class (`.desktop` name lookup is a
  future improvement).

## Development

```sh
ryoku plugin validate .
ryoku plugin add . --bar --yes      # installs and places it on the QS Bar
ryoku plugin remove apptime         # uninstall
```

Layout: `service/Main.qml` (tracker logic, no UI), `content/Widget.qml`
(glyph), `content/Panel.qml` (panel). Follows the Ryoku plugin rules R1–R11.
