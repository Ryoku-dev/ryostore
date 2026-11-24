# QR Pin

Pin any web address as a QR code on the wallpaper. It stays across reboots
until you clear it.

![QR Pin](assets/preview-widget.png)

## What it does

Type or paste a URL on the desktop tile, hit **PIN** (or Enter). The plugin
writes a QR PNG under its state dir and shows it over the wallpaper. **CLEAR**
drops the pin. Drag the tile to place it; right-click for size and opacity.

## What it reads and writes

| | |
| --- | --- |
| Runs | `bin/qrpin` → `qrencode`, `wl-paste` |
| Reads | clipboard (on Paste only); plugin setting `url` |
| Writes | `$XDG_STATE_HOME/ryoku/plugins/qrpin/url` and `qr.png` |
| Network | none (the URL is only encoded, never fetched) |
| Privileged | none |

## Settings

| key | type | default | description |
| --- | --- | --- | --- |
| url | text | "" | Optional Hub mirror of the pinned URL |

The live pin is the state file; clearing the tile clears both.

## Install

```
ryoku plugin validate ~/Documents/ryoku-plugins/qrpin
ryoku plugin add ~/Documents/ryoku-plugins/qrpin --yes
```

Enable under **Settings → Add-ons → Plugins**. It lands as a desktop widget on
the wallpaper.

## Credits

Author: Visnu <109976023+visnudeva@users.noreply.github.com> — community
plugin (`official` is false).
