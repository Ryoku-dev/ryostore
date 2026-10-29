# Sugar Tracker

A Ryoku QS Bar plugin for recording daily sugar intake in grams. Use its panel
to add common or custom amounts, review today's entries, and compare the total
with your configurable daily goal.

## What it does

- Shows a sugar mark on the QS Bar; the current total appears next to it after
  you have logged an entry.
- Adds 4 g, 8 g, or 12 g with one tap, or lets you enter a custom amount.
- Displays today's total, progress toward your goal, and the latest entries.
- Supports undoing the latest entry and clearing today's log.

The default 25 g goal is a configurable reference, not individualized dietary
advice.

## Install

From this directory, install and add it to the bar:

```bash
ryoku plugin add /path/to/sugar-tracker --bar
```

Replace the path with this plugin's directory. To install from Git instead, use
your repository URL. The plugin will appear in QS Bar Settings > Community;
Ryoku's plugin manager handles enabling and placement.

## How it plugs in

This is a community `topbarGlyph` plugin, implemented using Ryoku's standard
entry points:

- `service/Main.qml` holds today's log, total, persistence, and actions.
- `content/Widget.qml` renders the bar glyph and opens the panel.
- `content/Panel.qml` renders quick-add actions, the log, and goal progress.

Ryoku owns the bar placement, panel surface, and settings UI.

## Settings

| Setting | Default | Meaning |
| --- | ---: | --- |
| Daily sugar goal (g) | 25 | Goal shown in the bar panel; change it in Ryoku Settings > Plugins > Sugar Tracker. |

## Data and permissions

The plugin runs as part of Ryoku Shell with the user's permissions. It does not
run external programs or access the network. It reads and writes its own log at
`pluginApi.stateDir/sugar-log.json` (under Ryoku's per-plugin state directory).
Entries older than 14 days are discarded when the log loads. No other plugin or
shell configuration files are modified.

## Develop

```text
sugar-tracker/
├── manifest.json
├── service/Main.qml
├── content/Widget.qml
├── content/Panel.qml
├── README.md
└── LICENSE
```

Validate with:

```bash
ryoku plugin validate .
```

## License

MIT — see [LICENSE](LICENSE).
