# Tansu — Bar & Phone

The **Tansu** top bar and its phone-shaped Quick Panel, built for **Ryoku
Desktop Shell**. Colours follow Ryoku's Matugen palette, so it wears the same
theme as the rest of the shell.

## Features

- **The bar** — workspaces, active window, media, weather, clock and date, tray,
  system status, resource gauges, battery, package updates, notifications,
  privacy (mic / screen-share), keyboard layout, and the utility keys. It can
  auto-hide, sliding away until the pointer reaches its edge.
- **The phone** — the Quick Panel as a phone: quick tiles and sliders,
  a now-playing card while something is playing (tap it for the lyrics, and pin
  the phone into the corner), notifications, dialogs, and the power menu.
- **Built-in Apps** — browse, search and launch desktop applications within
  the same phone, without installing a separate launcher.
- **Rashin** — swipe left on the phone for Ryoku's AI agent: a transcript over
  your wallpaper, with its own composer and stop key.
- **Wallpapers** — a wallpaper board reached from the phone (Desktop and
  Lockscreen sides), backed by `ryogami`.
- **Native backends** — window and workspace state from Ryoku's `Wm` facade,
  system state and actions from `shell.services`, Bluetooth from
  `Quickshell.Bluetooth`, wallpapers from `ryogami`, and the Matugen palette from
  the shell's theme.

## Settings

The gear on the phone opens Tansu's own settings screen — the barstyle's
settings, stripped down to what it owns. Everything Ryoku owns (its displays,
the compositor, keybinds, network, the system theme, the wallpaper daemon,
updates, and the separate launcher) lives in the Ryoku Hub, not here.

The pages are **Quick**, **General**, **Bar**, and **About**. They are stored in
`~/.config/ryoku/barstyle-tansu.json` and are applied live, without a restart.

| Page | What it edits |
|------|---------------|
| Quick | The phone's look (including the now-playing card), and the shell switches (notifications, Night Light, Keep Awake, the bar) |
| General | 24-hour time, the phone's alert, the Quick Panel's hot edge and behaviour, shell reload and reset |
| Bar | Which modules the bar carries (every pill and key), auto-hide, the corner radius, the workspace count, the bar's size, the update badge, media/tray/scroll behaviour, and the utility keys |
| About | What this barstyle is, and its credits |

## Sizes

Tansu draws in logical pixels and never multiplies the compositor's display
scale in on top, so the bar keeps its size across scale changes. **Bar → Size**
has two knobs, both in `~/.config/ryoku/barstyle-tansu.json`: **Bar size**
(0.70–1.30×, the bar strip alone) and **Tansu size** (0.50–3.00×, everything
Tansu draws on that monitor). Neither writes Ryoku's own display scale.

The bar is drawn for 1920 × 1080 at scale 1.0. Below roughly 1,350 logical
pixels of width its modules stop fitting side by side: lower **Bar size** or
switch off pills in **Modules**.

## Compositor support

Window-manager state is read through the shell's compositor-neutral facade, so
the bar runs on **Hyprland** and **niri** alike. A few popups still use
Quickshell's `HyprlandFocusGrab` to dismiss on click-outside; on niri that logs a
harmless warning and the popup closes on a second click instead.

## Dependencies

- **Ryoku Desktop Shell** (Quickshell-based)
- **Hyprland** or **niri** compositor
- **`ryogami`** (for the wallpaper board)

No external scripts or binaries are bundled beyond `ryogami` and the shell's own
services — the bar and the phone run inside Quickshell's QML engine.

## Structure

```
tansu/
├── Scene.qml              # Entry point (loaded by Ryoku Frame.qml)
├── manifest.json          # Ryostore product manifest
├── modules/
│   ├── common/            # Shared theme, widgets and helpers
│   └── tansu/
│       ├── bar/           # The bar and its pills, keys and popups
│       ├── phone/         # The phone body and keys
│       ├── quickPanel/    # The Quick Panel and its overlays
│       ├── settings/      # The Tansu settings screen (Quick/General/Bar/About)
│       ├── wallpaperSelector/  # The wallpaper board
│       └── mediaControls/ # The media panel
├── services/              # Adapters over Ryoku's services
├── assets/icons/          # The Solar icons the bar draws (outline + bold)
└── assets/preview.png
```

## License

GPL-3.0-only — see `PROVENANCE.txt` for attribution.

## Maintenance & support

Tansu is a community contribution. It is maintained and updated by its author
( dodo986 ), not by the Ryoku team. Ryostore runs automated and human screening
on every submission, but that screening is not a guarantee of correctness or
safety: you are responsible for reviewing the code you install and run. Report
issues and request updates through the contributor.
