# Lumania

A thin frame around the screen with seven notches hung on it, ported from
[Lumania Shell](https://github.com/rover-001/lumania-shell) by rover.

| Where | Notch | What it does |
| --- | --- | --- |
| Top centre | Island | Clock, now-playing media with cover art and controls, the newest notification |
| Top left | Power | Lock, log out, suspend, restart, power off |
| Top right | Tray | System tray icons with their menus |
| Left edge | Workspaces | Workspace rail, one row per workspace |
| Bottom right | Control centre | Wi-Fi, Bluetooth, volume, brightness, battery, power profile, night light, focus |
| Bottom centre | Wallpapers | The ryogami filmstrip; click a thumb to apply it |
| Bottom left | Search | Opens the app launcher; right-click opens settings |

The notches stay out of the way until you need them: they slide under the frame
while a window is open and lift when the corner is touched.

## Settings

Right-click the bottom-left lip to open the settings panel. It edits the frame
thickness, the corner radius, the island width, how many wallpaper thumbs the
filmstrip shows, and whether motion is reduced. Everything lands in
`~/.config/ryoku/barstyle-lumania.json` and applies at once.

The accent is not editable here: it reads Ryoku's wallpaper palette, so it
retints whenever matugen does. Ryoku owns everything else: the displays, the
wallpaper, the theme, network and power.

## Notes

- The wallpaper filmstrip reads the ryogami index and applies with
  `ryogami wallpaper set`, so it never touches the wallpaper directly.
- Notifications are the shell's own server; this style only draws the newest
  popup in the island. Ryoku's own banner window still paints beside it until
  the shell lists this style in `styleOwnsBanners`, so the settings panel has an
  **Island notifications** switch to silence the island's copy.
- The launcher that the bottom-left lip opens ships as the separate
  **Lumania** launcher in RyoStore -> App launchers.
