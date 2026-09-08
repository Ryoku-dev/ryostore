# Imi — Material 3 Island Bar

A Material 3-inspired top bar style for **Ryoku Desktop Shell**.  
Ported and adapted from the Immaterial Impulse dotfiles (end-4).

## Note to neuromap : i just realized that there are a couple unnecessary leftover qml files. since the bar is a heavily customized fork, it shouldnt be hard to see which files are trash, you can remove them yourself or lmk if you need me to do some changes. (most trash are at imi/services/

## Features

- **Island Architecture** — Three rounded pill groups (left, center, right) with independent blur regions and configurable corner styles.
- **Morphing Popouts** — Popout cards smoothly animate position and size when hovering between widgets. Cards stay hidden until content is loaded (no top-left flash).
- **Kanji Workspaces** — Workspace indicators using Japanese numerals with click and scroll navigation. Supports multi-monitor and configurable workspace count.
- **Audio Visualizer** — Native MusicBars spectrum visualizer via PipeWire, embedded in the media pill alongside MPRIS controls (artist, title, album art).
- **System Gauges** — CPU, RAM, and temperature ring gauges with animated fills.
- **Weather Widget** — Current conditions, hourly forecast chart, and multi-day outlook via popout card.
- **Calendar Popout** — Clock + calendar grid popout with locale-aware formatting.
- **Privacy Indicator** — Mic, camera, and screencast status chips that appear/disappear with smooth animations.
- **Submap Indicator** — Hyprland keybind submap pill (e.g. resize mode) with auto-hide.
- **System Tray** — Collapsible tray icons with overflow.
- **Matugen Theming** — Full dynamic color palette from Ryoku's Matugen integration.
- **Edit Mode** — Drag-and-drop widget reordering via Bar Studio.
- **Multi-Monitor** — Per-output Scopes with boundary-aware popout positioning.

## Configuration

All options are exposed through Ryoku Settings > Bar section and stored in `~/.config/ryoku/shell.json` under the `bar` key:

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

## Dependencies

- **Ryoku Desktop Shell** (Quickshell-based)
- **Hyprland** compositor
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
