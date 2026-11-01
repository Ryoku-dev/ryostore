# Caelestia

A faithful plain-QML port of the [Caelestia shell](https://github.com/caelestia-dots/shell) for Ryoku. It carries the upstream framed bar, popouts, dashboard, launcher, Nexus settings, session menu, sidebar, notifications and OSD from revision `b51fdb35ca7a14ac5a49e0d94fc5de2d79756aed`.

Caelestia keeps its Material 3 layout and motion while Ryoku supplies compositor-neutral workspace and window state on Hyprland, niri and Wayfire. Ryoku also remains the owner of wallpaper, capture, lock, palette and session actions.

## Open surfaces

The normal Ryoku surface bus controls the port:

```text
qs ipc call shell openSurface '' launcher
qs ipc call shell openSurface '' settings
qs ipc call shell openSurface '' dashboard
qs ipc call shell openSurface '' session
qs ipc call shell openSurface '' sidebar
```

`launcher` opens Caelestia's upstream launcher. `settings` opens Nexus. The remaining routes open their upstream Caelestia surfaces.

## Settings

Nexus edits the generated upstream config model. Changes persist under:

```text
~/.config/ryoku/caelestia/shell.json
```

Defaults are generated from the pinned plugin headers. Removing a stored key restores its upstream default.

## Ryoku handoffs

- Wallpaper controls call `ryogami wallpaper`.
- Capture and recording call `ryoku-shell screenshot` and `ryoku-shell record`.
- Lock and session controls use Ryoku's session services.
- Keep Awake uses the shared `Flags.keepAwake` state.
- Workspace and window actions use the neutral `Wm` facade.
- Colours follow Ryoku's active `Theme` palette.

See `PROVENANCE.txt` for excluded desktop-owner directories and deliberate native-plugin degradations.