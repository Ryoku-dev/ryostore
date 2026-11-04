# Imi 2

A full-desktop Material 3 shell for the Ryoku desktop shell. Version 2
brings the whole ii shell family: the bar with its widget set and edit
mode, the dynamic island, both sidebars, on-screen display, notification
banners, the session screen and the vertical bar.

Ryoku provides the platform. Compositor state goes through the host's
Wm facade (Hyprland and niri alike), colors come from the shell's
matugen palette, and audio, network, battery, brightness, weather,
notifications, media and the rest are the shell's own services - the
barstyle keeps no private copies of them.

## Configuration

Settings live in `~/.config/ryoku/barstyle-imi/config.json`, mirroring
the option categories (bar, appearance, sidebar, osd, and so
on). The bar's own edit mode (double-click the bar) covers widget
layout; the settings window covers the rest.

## Structure

```
imi/
├── Scene.qml               # Entry point (loaded by Ryoku Frame.qml, per monitor)
├── GlobalStates.qml        # Cross-surface UI state bus
├── modules/common/         # Config, Appearance, widget kit, functions
├── modules/ii/             # bar, dynamicIsland, sidebars, osd, sessionScreen, ...
├── services/               # Host-service adapters and services
└── assets/                 # Icons, theme palettes, preview
```

## Dependencies

- Ryoku Desktop Shell (Quickshell-based)
- Hyprland or niri

## License

GPL-3.0 - see PROVENANCE.txt for attribution. Community-maintained by
dodo986.
