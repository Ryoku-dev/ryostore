# Lumania launcher

The search notch from [Lumania Shell](https://github.com/rover-001/lumania-shell)
by rover, ported as a Ryoku app launcher.

Super+Space blooms the panel out of the bottom-left corner of the screen: a
search line over a grid of apps, with your recent apps on the first row. Type
to filter, walk the grid with the arrow keys or the pointer, and press Enter or
click a tile to open it. Escape or a click anywhere outside closes it.

Pick it in Settings -> App Launcher, and pair it with the Lumania bar style so
the panel grows out of that style's bottom-left lip.

## What it honours

- **Hidden apps** from Ryoku's `~/.config/ryoku/launcher.json`, the same list
  Settings -> App Launcher edits.
- Reduced motion and the shell's colour scheme.
- Terminal apps open in your chosen terminal, through `AppLaunch`.

Recents are kept in `~/.local/state/ryoku/lumania-recents.json`.
