# Tatami

A full-screen app launcher for Ryoku. Super+Space spreads every app you have
across the screen as a grid of mats under a section index (Internet, Media,
Graphics, Develop, Office, Games, System, Utility), the way a printed catalogue
lays out its plates.

- Type to search every app at once: names first, then generic names, keywords
  and descriptions.
- Arrow keys move across the grid, Enter opens the app, Tab and Shift+Tab step
  through the sections, Escape clears the search and then closes.
- Click a mat to open it, or click outside the sheet to close.

Tatami uses Ryoku's own palette, type and motion, so it follows your colour
scheme and the reduced-motion setting. Apps start through the shell's launcher
service, so terminal apps open in your chosen terminal.

## Settings

Settings -> App Launcher shows these for Tatami (`settings.json` lists them):

- **Backdrop frost** blurs the desktop behind the sheet; 0 leaves it sharp.
- **Overlay opacity** sets how opaque the wash behind the sheet is.
- **Hidden apps** drops the apps you never open from the shelf.
- **Grid** sets the columns and the width of each mat. The sheet is columns
  times that width, and columns drop on a screen too narrow for them.
- **Sections** orders the section chips and hides the ones you do not use. A
  hidden section still shows its apps under All and in search.
- **Favorites** pins apps first in every section and in search, marked with a
  star.

Install it from RyoStore -> App launchers, then pick it in
Settings -> App Launcher.
