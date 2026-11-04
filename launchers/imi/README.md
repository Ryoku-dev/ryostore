# imi launcher

The imi overview search, ported from the imi barstyle family to run as a Ryoku
store app launcher. It is the same search experience the barstyle ships:
a morphing search field over grouped results, with nine core panels.

## What it searches

- **Apps** — every desktop entry, with fuzzy, typo-tolerant and frecency
  ranking. Launches go through the host's `AppLaunch`, so terminal apps open
  in the user's terminal.
- **Calculator** — qalc-backed math and unit conversion (`=` prefix, or just
  type an expression). Degrades to no math rows when qalc is not installed.
- **Clipboard** — the host daemon's clipboard history (`;` prefix), with
  pinning, delete, image previews and content detectors.
- **Emojis** — the emoji grid (`:` prefix) with categories, recents and search.
- **Windows** — every window on every compositor through the host's Wm facade
  (`#` prefix): focus, close, copy title.
- **Commands** — the user's command catalogue at
  `~/.local/state/imi/commands.json`, shared with the imi barstyle.
- **Web search** — browser tabs, bookmarks, history and a search continuation
  (`?` prefix). Opens with `xdg-open`/`Qt.openUrlExternally`.
- **Files** — fd-backed file and folder search (`,` prefix, plus inline
  results for plain queries). Degrades when fd is missing.
- **File content** — ripgrep-backed full-text search (`'` prefix). Degrades
  when rg is missing.

Everything else the upstream overview had (AI chat, bluetooth, translator,
media downloader, speed test, typing test, material symbols, calendar, tasks,
timers, settings search, gmail, and the window-grid surfaces) is not part of
this port.

## Use

Install from RyoStore, pick it in Settings → App Launcher, press Super+Space.
Escape, a click outside, and launching anything close it.

Result actions: Ctrl+K opens a row's action panel (pin to top via favorites,
add a Ctrl+letter keybind, add a single-word alias, reset ranking). Tab
filters result categories. Up/Down moves, Ctrl+Up/Down jumps between groups.

## Config

The launcher keeps its own settings at `~/.config/ryoku/launcher-imi.json`
(prefixes, module toggles, result section order, panel widths, clipboard
detectors, browser-site indexing). It never writes the host's
`launcher.json`. Aliases, favorites, result keybinds, recent queries and
calculator history live in `~/.local/state/imi/`, shared with the imi
barstyle's state directory.

## Fonts

Ships the imi family's fonts (Google Sans Flex, Material Symbols Rounded,
JetBrains Mono Nerd Font) so the look matches the barstyle everywhere; their
licences ride along in `assets/fonts/`.
