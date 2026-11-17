# Dynamic Island

The [quickshell-DynamicIsland](https://github.com/Alan-Betty/quickshell-DynamicIsland)
shell by Alan-Betty, ported to Ryoku. A liquid-glass dynamic island at the top
of the screen that grows when something happens: a song starts, a timer runs,
a notification arrives, you open the launcher.

It keeps its three upstream jobs:

- **Island.** Music, timer, stopwatch and screen-recording show up as live
  activities. Click it to open a panel with a clock, weather, calendar,
  media player and quick toggles (Wi-Fi, Bluetooth, night shift, brightness,
  volume and so on).
- **Notifications.** Banners in three styles (banner, island, corner), a
  Notification Center with grouped stacks, inline reply when the app
  supports it, and Do Not Disturb.
- **App launcher.** The island morphs into a Spotlight-style search field:
  apps, `> shell commands` and quick maths.

## Ryoku integration

Ryoku stays the owner of the desktop services the upstream shell carried
itself:

- **Notifications** — Ryoku's shell owns the freedesktop daemon. While
  *Allow Notifications* is on, the island lifts each arrival out of the
  shell's toast queue and draws the banners and the Notification Center
  itself, so exactly one banner surface paints. Do Not Disturb toggles the
  shell's Focus state.
- **Screen recording** — the recording activity mirrors the shell's
  Recorder service, and *Stop* calls it. Screenshots call the shell's
  capture (region shot), not grim/slurp.
- **Night Shift** — toggles the shell's Nightlight service (temperature set
  from the island's slider).
- **Session actions** — lock/suspend/logout/reboot/shutdown go through the
  shell's SessionActions service.
- **Colours** — the accent follows Ryoku's active palette first, then
  Matugen, Pywal/Wallust, the wallpaper, the GTK accent, album art or a
  custom colour. Light/dark follows GTK and the shell surface.
- **Workspaces and windows** — compositor state comes from the neutral `Wm`
  facade (workspace dots, fullscreen hiding, focused screen), never from a
  compositor CLI.

## Open surfaces

```sh
qs ipc call shell openSurface '' launcher    # island app launcher
qs ipc call shell openSurface '' settings    # island settings window
qs ipc call island toggle|center|launcher|settings|playPause|...
```

The island also registers global shortcuts (Wayland global-shortcut
protocol): `quickshell:islandLauncher`, `quickshell:islandToggle`,
`quickshell:islandCenter`, `quickshell:islandSettings`. Bind them in your
desktop's shortcut settings — the island's settings window lists them.

## Settings

The island's settings window (gear icon, or `qs ipc call island settings`)
edits everything live. Changes persist under:

```text
~/.config/ryoku/dynamic-island/settings.json
```

## Honest degradations

- **Glass blur** — upstream relies on a compositor layer blur rule behind
  the island; Ryoku does not add one, so *Liquid Glass* renders as a
  translucent tint without frosting. *Black* is unaffected.
- **Click-away** — a compositor focus grab is not available through the
  neutral facade, so the island instead grows its input mask and swallows
  clicks on the desktop while it is open. Escape and the scrim still close
  everything.
- **OSD pills** — the shell draws its own volume/mic/brightness OSD. The
  island's own pills are opt-in (*Island OSD Pills* in settings) so exactly
  one of each paints out of the box.
- **Reserved strip** — the top reserve subtracts the *Outer gaps* setting
  instead of reading a compositor option.
- **Screen recording indicator** — pgrep-based detection of third-party
  recorders is replaced by the shell's Recorder state; only shell-owned
  recordings show as an activity.
- **Inline reply** — available when the sending app supports it and the
  server advertises it; the shell's daemon does not, so the reply field
  stays hidden while actions still work.

See `PROVENANCE.txt` for what was carried and what was rewritten.
