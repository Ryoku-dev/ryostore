# Caelestia

The [Caelestia](https://github.com/caelestia-dots/shell) shell's bar and panels for the
**Ryoku Desktop Shell**: a framed bar with a dock, workspaces, greeter, clock and status
icons, and its dashboard, session menu, sidebar, OSD and popouts.

Plain QML: the upstream C++ plugin is not needed.

## Settings

Open the style's own settings from the bar's power or settings buttons, or with

    qs -c shell ipc call caelestiaSettings toggle

Every change is written to `~/.config/ryoku/caelestia/shell.json` and applies at once.
The file only holds what you changed; delete a key to get its default back.

## What it reads and runs

- The forecast comes from Ryoku's weather service; searching a location in the
  weather tab asks geocoding-api.open-meteo.com over HTTPS.
- Apps open through Ryoku's launcher; deleting a screenshot or recording runs `rm`.
- The dashboard follows the Hub's Controls page when the installed Ryoku shell has it.

## Not included

The upstream launcher, overview, lyrics panel and plugin system are left out; Ryoku's own
launcher opens from the bar logo.
