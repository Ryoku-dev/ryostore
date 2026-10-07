# Imi — Material 3 Island Bar

A Material 3-inspired top bar style for **Ryoku Desktop Shell**.  
Ported and adapted from the Immaterial Impulse dotfiles (end-4).

## Features

- **Island Architecture** — Three rounded pill groups (left, center, right) with independent blur regions and configurable corner styles.
- **Morphing Popouts** — Popout cards smoothly animate position and size when hovering between widgets. Cards stay hidden until content is loaded (no top-left flash).
- **Kanji Workspaces** — Workspace indicators using Japanese numerals with click and scroll navigation. Supports multi-monitor and configurable workspace count.
- **Audio Visualizer** — Native MusicBars spectrum visualizer via PipeWire, embedded in the media pill alongside MPRIS controls (artist, title, album art).
- **System Gauges** — CPU, RAM, and temperature ring gauges with animated fills.
- **Weather Widget** — Current conditions, hourly forecast chart, and multi-day outlook via popout card.
- **Calendar Popout** — Clock + calendar grid popout with locale-aware formatting.
- **Privacy Indicator** — Mic, camera, and screencast status chips that appear/disappear with smooth animations.
- **Submap Indicator** — Hyprland keybind submap pill (e.g. resize mode) with auto-hide. Hidden on other compositors.
- **Autohide Bar** — Optional hover-reveal bar with Super-hold peek, overlay mode (windows ignore it) or push mode (windows make room), and popups that hold the bar out while open.
- **System Tray** — Collapsible tray icons with overflow.
- **Matugen Theming** — Full dynamic color palette from Ryoku's Matugen integration.
- **Edit Mode** — Drag-and-drop widget reordering via Bar Studio. Double-click the bar to open its own edit mode: `+` adds widgets and holds the autohide switch.
- **Multi-Monitor** — Per-output Scopes with boundary-aware popout positioning.

## Configuration

Imi keeps its own settings, separate from the shell's `shell.json`, in
`~/.config/immaterial-impulse/config.json` under the `bar` key. Edit them live
from the bar's own **Edit Mode** (double-click the bar) and its widget picker;
value changes apply without restarting the shell:

| Key | Description | Default |
|-----|-------------|---------|
| `bar.cornerStyle` | `0` = rounded, `3` = Material 3 islands | `3` |
| `bar.vertical` | Vertical bar mode | `false` |
| `bar.shadow` | Drop shadow under bar background | `true` |
| `bar.workspaces.shown` | Number of workspace indicators | `10` |
| `bar.workspaces.showAllMonitors` | Show workspaces from all monitors | `false` |
| `bar.layouts.left` | Widget order for the left pill | `[...]` |
| `bar.layouts.center` | Widget order for the center pill | `[...]` |
| `bar.layouts.right` | Widget order for the right pill | `[...]` |
| `bar.autoHide.enable` | Slide the bar away until the pointer hits the screen edge | `false` |
| `bar.autoHide.hoverRegionWidth` | Reveal-strip height in px at the screen edge | `2` |
| `bar.autoHide.pushWindows` | Reserve bar space when shown (`false` = bar overlays windows) | `false` |
| `bar.autoHide.dismissPopups` | Keep the bar out while a bar popup is open, closing the popup on pointer-leave | `true` |
| `bar.autoHide.showWhenPressingSuper.enable` | Peek the bar while Super is held | `true` |
| `bar.autoHide.showWhenPressingSuper.delay` | Hold delay in ms before the peek shows | `140` |

## Compositor support

Imi reads all window-manager state (workspaces, focused window, fullscreen)
through the shell's compositor-neutral facade, so it runs on **Hyprland** and
**niri** alike. Compositor-specific extras degrade gracefully elsewhere: the
keybind submap pill and scratchpad handling only appear on Hyprland, and
focus-grab dismissal of pinned popups falls back to toggle-off on other
compositors.

## Dependencies

- **Ryoku Desktop Shell** (Quickshell-based)
- **Hyprland** or **niri** compositor
- **PipeWire** (for audio visualizer)
- **Python 3** (installer only)

No external scripts or binaries are bundled — the bar runs entirely within Quickshell's QML engine using Ryoku's native services (`shell.services`, `shell.barkit`).

## Structure

```
imi/
├── Scene.qml              # Entry point (loaded by Ryoku Frame.qml)
├── GlobalStates.qml       # Shared state singleton (active popout, etc.)
├── manifest.json          # Ryostore plugin descriptor
├── modules/
│   ├── common/            # Shared models, config, widgets, functions
│   └── imi/
│       ├── bar/           # Bar content, popout overlay, widgets
│       └── editMode/      # Drag-and-drop reorder coordinator
├── popouts/               # Calendar, weather, and other popout cards
├── shared/                # Popout base component
├── services/              # Network, sound theme adapters
├── widgets/               # Desktop widget components
├── assets/                # Icons and preview image
└── components/            # Reusable UI primitives
```

## License

GPL-3.0 — see PROVENANCE.txt for attribution.

## Maintenance & support

Imi is a community contribution. It is maintained and updated by its author
( dodo986 ), not by the Ryoku team. Ryostore runs robust
automated and human screening on every submission, but that screening is not a
guarantee of correctness or safety: you are responsible for reviewing the code
you install and run. Report issues and request updates through the contributor.
