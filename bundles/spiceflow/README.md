# Ryoku Palette Bridge

Ryoku Palette Bridge keeps Zen, Spotify, and Discord matched to your wallpaper.
Change the wallpaper and all three apps pick up its Ryoku colours automatically.

It works with the themes each app already supports:

- Zen's browser theme changes colour through Firefox's theme API.
- Spotify's Spicetify theme gets the same colours without stopping your music.
- Discord uses the Midnight theme in Vesktop, with its colours updated through
  QuickCSS so the stock Discord theme never flashes on screen.

This bundle is stored under `bundles/spiceflow` because the project started as
Spiceflow, a Spotify-only tool. The current project and its name in Ryostore are
Ryoku Palette Bridge because it now handles all three apps.

Ryostore installs the bridge and automatically configures integrations for
compatible apps already present on the machine. The source is kept at
`~/.local/share/ryoku-palette-bridge`, so you can add another integration
later:

```bash
~/.local/share/ryoku-palette-bridge/install-integrations.sh --all
```

Check the core service and published palette at any time:

```bash
ryoku-palette-bridge-doctor
```

Installing this bundle enables and starts the user service, then configures
supported apps already present. Spotify may restart during initial setup.
Version 2.1.0 pins the tested performance fixes and uses its own detection
command so an older bridge binary does not cause Ryostore to skip the upgrade.
Directly rerunning the installer repairs an inactive service. Ryostore's
Installed badge checks command presence, not service health; use the doctor
above to check a running installation.

Zen's live extension must be signed by Mozilla. The repository includes a
guided setup:

```bash
~/.local/share/ryoku-palette-bridge/setup-zen-signing.sh
```

Zen needs one restart to load its profile preferences and stylesheet. Its
extension must be installed separately before live updates work; installing
this bundle alone does not install the signed extension. The source remains
at the path above; select it as Build source in Win+W's Palette Bridge page
when using Ryoku versions that include those settings.

Maintainer: Sipper1236 (Rayyan), through the upstream GitHub issue tracker.
This community bundle is maintained by its contributor, not the Ryoku team.
Installation contacts github.com to fetch the pinned source and builds it with
Go. Optional app setup invokes Spicetify and Ryoku materialization, writes the
Matugen user overlay and the detected apps' theme configuration, and records
integration ownership. Runtime palette traffic stays on 127.0.0.1:47616.
Zen signing uses Mozilla's add-on service; Vesktop loads Midnight from
refact0r.github.io and its icon from upload.wikimedia.org.

The top-level `installers/ryoku-palette-bridge.sh` is a compatibility copy for
older Ryostore clients that cannot resolve bundle-local installers. The installer
test checks that both copies remain identical. The source build runs from its
own checkout so it also works when launched from the Store's working directory.

Source: <https://github.com/Sipper1236/ryoku-palette-bridge>

License: MIT. The bundled integration templates retain the third-party notices
included upstream.
