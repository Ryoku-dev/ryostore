# Ryoku for Zed

This bundle writes a custom theme to `~/.config/zed/themes/ryoku-dynamic.json` and selects it in Zed. A user systemd path unit watches Ryoku's generated `matugen.json` and rebuilds the custom theme when the wallpaper palette changes. The generator and watcher source are included in this bundle for review; installation does not fetch or execute remote source code.

## Install

Install the bundle from Ryostore Extras. Bun is required. The installer synchronizes the current palette, keeps a backup of Zed's settings file, selects **Ryoku Dynamic Dark**, and enables `ryoku-zed-theme-sync.path`. The watcher reads `~/.config/zed/themes/matugen.json` and writes only `ryoku-dynamic.json`.

In Ryoku, enable **Theme apps** from the wallpaper picker (`Super+W` → **App theming**) so Matugen produces the Zed theme. Select **Ryoku Dynamic Dark** or **Ryoku Dynamic Light** in Zed's theme selector to follow the current appearance. The installed theme is dynamic; the bundled `runtime/themes/ryoku.json` is a static fallback palette.

If Zed is open while its theme JSON changes, reopen the theme selector and reselect the Ryoku Dynamic theme. If the running session still displays old colors, restart Zed; the file watcher updates the JSON on disk but cannot force an in-process theme reload. This avoids claiming that file synchronization alone repaints an already-running editor.

## Palette behavior

UI surfaces follow the generated Ryoku palette. Syntax colors are distributed across distinct warm and cool hues so common adjacent categories remain distinguishable. When the source palette is nearly grey, the generator seeds syntax accents from Ryoku violet and applies a chroma floor. It adjusts text lightness to keep at least 4.5:1 contrast against the editor background.

The screenshots show the real Zed editor displaying the bundled theme generator over violet, red, and blue Ryoku palettes. The code shown is the theme generator itself. Source can be reviewed in `runtime/scripts/theme.ts` and `runtime/scripts/install-sync.ts`. From the installed runtime directory, run `bun scripts/theme.ts --verify-monochrome` to check synthetic monochrome light and dark palettes.

To disable the watcher, run:

```sh
systemctl --user disable --now ryoku-zed-theme-sync.path
```

The user may then remove `~/.config/systemd/user/ryoku-zed-theme-sync.path` and `ryoku-zed-theme-sync.service`, followed by `systemctl --user daemon-reload`.
