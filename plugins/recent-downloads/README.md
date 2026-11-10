# Recent Downloads

A small Ryoku QS Bar button for browsing the latest files in the user's XDG Downloads folder.

## Use

The bar glyph shows a minimal down-arrow icon and the tooltip **Recent Downloads**. Click it to open a panel with up to ten completed files, sorted by modification time. Click a file to open it with the desktop's default application, or use **Open Downloads folder**. Refresh rescans the folder.

## Placement

The plugin is registered as a QS Bar widget but is intentionally installed without a bar placement. In Bar Studio, open **QS Bar Settings → Layout → Add widget**, add **Recent Downloads**, then move it to the left, center, or right lane and reorder it. The selected layout is stored by Ryoku and persists across bar and system restarts. The plugin manifest does not set a default lane.

## Data and dependencies

`bin/recent-downloads` reads file names, paths, sizes, and modification times in the XDG Downloads directory. It skips hidden files, directories, and common partial-download suffixes. It writes no files and makes no network requests. Clicking a file or the folder launches `xdg-open` with that path as a separate argument.

The helper uses Python 3 and `xdg-user-dir` to locate the XDG Downloads directory, falling back to `~/Downloads`. These commands and `xdg-open` are declared in the manifest.

## Files

- `service/Main.qml`: requests and holds the recent-file list.
- `content/Widget.qml`: themed glyph and tooltip.
- `content/Panel.qml`: recent-file panel and open actions.
- `bin/recent-downloads`: read-only XDG Downloads scanner.
