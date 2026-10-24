# GitHub Heatmap

Your GitHub contribution calendar, living on the wallpaper. One square per day,
coloured by how much you shipped, with streaks, records and a hover readout,
all styled to sit next to Ryoku's own desktop widgets.

![Month blocks](assets/preview-widget.png)

## Features

- **Your calendar, no token.** Reads the public contributions page; with the
  GitHub CLI logged in, it picks up your username on its own.
- **Year or last N months.** Step through past years, or show the last 1–12
  months ending today.
- **Four designs.** *GitHub*, *Grid*, *Minimal* or *Full* in one click, from
  the card or the desktop's right-click menu, then fine-tune anything.
- **Eight palettes.** Theme, Green, Blue, Purple, Pink, Orange, Ice and Mono,
  with GitHub's levels or a scale relative to your best day. Theme follows the
  desktop's Colour section like the built-in widgets: Auto, Solid, or a
  Gradient that runs from one colour to another across the levels (Gradient
  needs a desktop that passes `accentColor2`; elsewhere it shows the first colour).
- **Shape and spacing.** Rounded, square or circle cells; cell size and gap;
  months as one continuous grid or as separate blocks.
- **Labels your way.** Month names (`jan`, `Jan`, `J`, `1`), weekday labels
  (`mon wed fri`, all, or initials), week starting Sunday or Monday, text size.
- **Streaks and record.** Current and best streak, active days and your
  biggest day, plus a legend.
- **Hover info** as a floating tip, in the toolbar, or off; optional click to
  open that day on GitHub.
- **Card options.** Toolbar on or off; the calendar's two looks, frosted
  glass or solid paper, the desktop's plain card, or no background; corner radius.
- **English and Spanish**, following the system language by default.

![GitHub style](assets/preview-github.png)

## Settings

The desktop's right-click menu keeps it short, like the built-in calendar:
Lock, size and opacity, Colour, then two rows, Design and Background, each
stepping to the next value on click (on a desktop that supports
`"style": "cycle"`; elsewhere they show as chips).

Every option is in the card itself: hover the widget and press the gear for a
panel with five tabs (Design, Data, Grid, Text, Card). Palettes and shapes show
a sample on their chips, and a row that depends on another (month format,
weekday style, today's count) only appears while it applies. With the toolbar
hidden, the gear and refresh icons appear in the top-left corner on hover.

![Settings panel](assets/preview-settings.png)

![Minimal style with a floating tip](assets/preview-minimal.png)

## Language

English and Spanish. The `language` setting defaults to `auto`, which follows
the system locale (`LANG`); any language other than Spanish shows English. The
right-click menu labels come from the manifest and stay in English.

## Glass background

The *Glass* background draws the same frosted wallpaper plate as Ryoku's
calendar when the desktop host hands plugins its wallpaper mirror
(`pluginApi.wallpaperSource` and `wallpaperRect`; the manifest asks for it with
`capabilities.glass`). Without them it uses the tinted glass the desktop gives
every plugin tile.

## What it runs, reads and writes

- **Runs** `bin/gh-contrib <username> <year|last>` (Python 3, stdlib only) on
  load, on refresh, on a period change, and every `refreshMin` minutes
  (default 30).
- **Network**: `github.com` only, the public page
  `https://github.com/users/<user>/contributions` (with `from`/`to` for a
  calendar year). No token, no login; it sees public contributions, and private
  ones only if the user enabled "Private contributions" on their profile.
- **Runs** `gh api user --jq .login` (GitHub CLI) once when no username is
  set, to take the logged-in account as the default. Optional.
- **Opens** `https://github.com/<user>?tab=overview&from=<day>&to=<day>` in the
  browser only when "Click opens the day on GitHub" is on and a day is clicked.
- **Writes**: nothing but its own settings, through `pluginApi.saveSetting` on
  the bar or `ryoku-plugins-place github-heatmap settings <json>` on the
  desktop (the shell's own settings writer; the desktop host has no
  saveSetting).
- No privileged actions.

Preview images use generated demo data and backgrounds.
