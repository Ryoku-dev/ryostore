# Nothing Status

A Ryoku QS Bar widget with local network, audio and battery indicators.
Its icons are drawn in QML as monochrome lines. The bar uses only neutral
ink; N-Red appears if the battery falls below 16%. The popup shows status
in a charcoal card.

## Access

The bar glyph opens its read-only panel. Show or hide each bar indicator from
QS Bar Settings > Community. The desktop owner can move the widget with
QS Bar Settings > Layout.

## Capabilities

- Runs its own `bin/status.py` every five seconds via Python 3.
- The script reads `/sys/class/power_supply/BAT*/{capacity,status}`.
- It calls local `nmcli` and `wpctl` to read status.
- It makes no network requests, writes no files and performs no privileged
  actions.
- Text uses Noto Sans. Proprietary Nothing font files are not included.
