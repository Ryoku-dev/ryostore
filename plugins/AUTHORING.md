# Writing a plugin

A Ryoku plugin ships content the shell mounts into a host: a draggable tile on
the wallpaper, a popout that melts out of the screen frame on hover, or a single
mark on the QS Bar. You
write two things - a service and a content view - and declare which hosts you
support. The shell owns the surface, the placement, the motion, the focus, and
the input region. You never touch any of that.

`plugins/photo-frame/` is the worked example.
`plugins/template/` is the smallest possible version - copy it to start.

## Quickstart

```
cp -r plugins/template plugins/my-plugin
```

1. Edit `plugins/my-plugin/manifest.json`: set `id` to `my-plugin`, pick a
   `name`, `author`, `description`, the `hosts` you support, and `defaults`.
2. Rewrite `service/Main.qml` and `content/Widget.qml`.
3. Replace `assets/preview-widget.png` and rewrite `README.md`.
4. Add an entry to `plugins/registry.json` so it shows up in Settings.
5. **Test it locally** (see below) - enable it in your shell and confirm it
   renders and behaves, then work the **Before you submit** checklist and PR.

## Rules

A plugin runs unsandboxed inside the user's shell, so every plugin follows the
same eleven rules. Ryoku writes them into a scaffolded plugin's `AGENTS.md`, and
Ryostore CI **will** run `ryoku plugin validate` on every plugin PR and block on
the rules it can check.

- **R1 Place.** A plugin is one folder named after its id, authored under
  `$(xdg-user-dir DOCUMENTS)/ryoku-plugins/<id>/` (fallback
  `~/ryoku-plugins/<id>/`); `ryoku plugin new <id>` creates it there. Never write
  into `~/.local/share/ryoku/plugins/` (the receipt-owned install root) or
  `~/.config/quickshell/` (the shipped shell).
- **R2 Shape.** `manifest.json` at the root; `service/Main.qml` (logic, no UI);
  `content/Widget.qml` (the one view); optional `content/Panel.qml` (a bar
  panel); `README.md`; `LICENSE`; `assets/preview-widget.png` (a real capture);
  scripts only under `bin/` with a shebang and the exec bit. Every extra file is
  listed in manifest `files`.
- **R3 Id.** Lowercase `[a-z0-9][a-z0-9-]*`, unique, and not a built-in widget
  id.
- **Which compositor is running is none of your business.** A plugin runs on
  Hyprland and on niri, through one shell, and the only window and workspace state
  it may read is what the Wayland protocols report (`ToplevelManager` for the
  focused window and its app id, `IdleMonitor` for idle): the shell's own
  singletons are not importable from a plugin, and a plugin that shells out to a
  compositor (`hyprctl`, `niri msg`), reads a compositor config path, or branches
  on which compositor is running is broken on the other one. Gate a
  compositor-only feature on the capability it needs and leave it out where the
  capability is absent.
- **R4 Imports.** Only `QtQuick*`, `Quickshell*`, `Ryoku.PluginKit`,
  `Ryoku.PluginKit.Singletons`, and files inside the plugin folder. Never
  `shell.*`, `Ryoku.Ui*` internals, or a relative import that climbs out of the
  folder.
- **R5 Settings.** Declared in `metadata.settings`; read through
  `pluginApi.pluginSettings` behind a default; written only through
  `pluginApi.saveSetting(key, value)`. Never edit `shell.json` or `plugins.json`
  directly.
- **R6 Commands.** Every external program is in the plugin's own `bin/` or listed
  in `dependencies.commands`. No `sudo`, `doas`, `su`. A privileged action is
  allowed only through `pkexec`, only on an explicit click, only when listed in
  manifest `capabilities.privileged` (exact command strings) and explained in the
  README.
- **R7 Network.** Every host the plugin talks to is listed in
  `capabilities.network`. No `curl … | sh`, no downloading and running code.
- **R8 Files.** Write only under `pluginApi.stateDir`
  (`$XDG_STATE_HOME/ryoku/plugins/<id>`), `$XDG_CACHE_HOME/ryoku/plugins/<id>`,
  or a temp dir. Never touch `~/.ssh`, `/etc`, shell rc files, or another
  plugin's folder.
- **R9 Shell.** No `sh -c` with a string built from settings or program output;
  pass argv arrays.
- **R10 Secrets and binaries.** No tokens, keys or credentials in the tree; no
  compiled binaries (ELF/Mach-O/`.so`) and no symlinks; scripts only.
- **R11 Honesty.** `official` is never `true` for a community plugin; `author` is
  `Name <mail>`; the README says what runs, what it reads, what it writes, and
  every privileged or network capability.

## The manifest

`manifest.json` describes the plugin.

| Field | What it is |
| --- | --- |
| `id` | Folder name and unique key. Lowercase, no spaces. |
| `name` | Display name in Settings. |
| `version` | `x.y.z`. Bump it when you publish a change. |
| `author` | `Name <email>`. |
| `description` | One sentence shown in the catalogue. |
| `license` | SPDX id, e.g. `MIT`. |
| `tags` | Strings for filtering, e.g. `["photo", "desktop-widget"]`. |
| `entryPoints` | The QML files the shell loads (see below). |
| `files` | Extra files the install must fetch (helpers, assets) beyond the entry points. |
| `capabilities.densities` | Which densities your content draws (see Density). |
| `hosts` | The hosts your content supports: `desktopWidget`, `framePopout`, `topbarGlyph`. |
| `defaults` | Where it lands when first enabled (see Hosts). |
| `commands` | Executables the plugin ships, e.g. `["bin/ryoku-foo"]`. |
| `dependencies.commands` | Commands that must be present on the system. |
| `metadata.settings` | The settings schema the shell renders (see Settings). |

## The two entry points

```json
"entryPoints": {
  "main": "service/Main.qml",
  "content": "content/Widget.qml"
}
```

- **`main`** - persistent, non-visual logic. It loads once when the plugin is
  enabled and stays alive while the content mounts and unmounts, so its state
  survives. The template keeps its click counter here. This is
  your service.
- **`content`** - the one adaptive view. The shell mounts it in the host and
  lays out at the size it reports back. It reads everything from your service.
  This is the only visible piece.

There is no separate panel or settings QML. The same `content` renders in every
host; settings are a schema (below), not a hand-written page.

## Hosts and where it lands

`hosts` lists the surfaces your content can render in:

- **`desktopWidget`** - a draggable tile on the wallpaper, alongside the clock
  and weather. The user drags to move, drags the corner bracket to scale, and
  right-clicks for its menu. Rendered at `compact` density.
- **`framePopout`** - a popout that slides out of a screen edge on hover (or a
  plugins-menu key). Rendered at `full` density.
- **`topbarGlyph`** - a single mark on the QS Bar (the top bar). The user adds it
  from the bar's add-widget picker; a community bar widget also shows under QS Bar
  Settings > Community, with its author, a switch, and its settings. Rendered at
  `glyph` density.

`defaults` is where the plugin lands when first enabled, plus its menu identity:

```json
"defaults": {
  "host": "desktopWidget",
  "desktopWidget": { "bg": "card" },
  "framePopout": { "edge": "top", "align": "end" },
  "key": "m",
  "icon": "extension",
  "label": "My Plugin"
}
```

- `host` - the host used on first enable; the user can move it later.
- `desktopWidget.bg` - the tile backing: `card`, `glass`, or `none`.
- `framePopout.edge` / `align` - which edge it slides from and where along it.
- `key` - optional single key in Ryoku's plugins menu (leader, then your key)
  that toggles a frame popout.
- `icon` / `label` - the plugin's mark and name in menus and Settings.

Declare only the hosts that make sense. Photo Frame is `desktopWidget` only; a
bar widget is `topbarGlyph` only.

## Density

The host picks a density and sets it on your content. Today:

- `desktopWidget` -> `compact`
- `framePopout` -> `full`
- `topbarGlyph` -> `glyph`

`glyph` is the single-mark density the QS Bar host renders at: one tight mark,
no room for a full layout. Branch on `density` for the ones you draw, and list
them in `capabilities.densities`. A desktop-only plugin only needs `["compact"]`;
a bar widget only needs `["glyph"]`.

## The properties the shell sets

The shell sets these for you - declare them and read them, do not assign them.

On your **`content`** (`content/Widget.qml`):

| Property | Type | What it is |
| --- | --- | --- |
| `pluginApi` | `var` | Your handle to the service, settings, and plugin dir. |
| `screen` | `var` | The screen the tile is on (set by the desktop-widget host). May be null elsewhere. |
| `active` | `bool` | True while the content is visible / the popout is open. |
| `density` | `string` | `glyph`, `compact`, or `full`. |
| `s` | `real` | Scale multiplier; multiply your sizes and font sizes by it. |
| `widthBudget` | `real` | The resolved content width. Lay out to this. |

On your **`main`**: just `pluginApi`.

Size your content with `implicitWidth` / `implicitHeight` off `widthBudget` (with
a sane fallback), so the host can place and animate the tile. The host already
animates size changes and keeps the content mounted, so do **not** add a
`Behavior on implicitHeight` (or width) to the root or gate your body on a lazy
`Loader`: a second animation fights the host's and the view looks squashed while
it opens. Just change `implicitHeight` and let the host tween it.

## Reading your service from the content

`pluginApi.mainInstance` is the live `main` instance. Derive a convenience
property and read state through it:

```qml
readonly property var service: pluginApi ? pluginApi.mainInstance : null
// ...
text: qsTr("Clicked %1 times").arg(service?.clickCount ?? 0)
onClicked: service?.increment()
```

Use the `?.` and `?? default` guards - `service` is null until `main` has loaded.

## Settings

Declare settings as a schema in `metadata.settings`; the shell renders the form
in the plugin's menu and persists changes to `pluginApi.pluginSettings`. Your
content reads them - it does not write them.

```json
"metadata": {
  "settings": [
    { "key": "caption", "type": "text", "label": "Caption", "group": "Photo",
      "default": "", "placeholder": "Shown on polaroid / framed" }
  ]
}
```

Each entry has a `key`, a `type`, a `label`, a `group` (the section header), and
a `default`. The types:

- `text` - a line of text; optional `placeholder`.
- `image` - an image path picker.
- `toggle` - a boolean switch.
- `choice` - a dropdown; give `options: [{ "value", "label" }, ...]`.
- `slider` - a number; give `min`, `max`, `step`, and `decimals`.

Read a value with `pluginApi.pluginSettings.<key>`, guarded:

```qml
readonly property string caption: (pluginApi?.pluginSettings?.caption ?? "") || ""
```

## Shipping a command

If your plugin needs to shell out to a system tool or a helper script, ship the
script under `bin/`, list it in `commands`, and list any system tools it needs
under `dependencies.commands`. Run it from the service with a `Process`, building
the path from `pluginApi.pluginDir`.

## Imports you can use

In the service and content:

- `Ryoku.PluginKit` - `GlyphIcon`, `MicroLabel`, `SearchField`, `CornerTicks`,
  `WaveMeter`, `Card`.
- `Ryoku.PluginKit.Singletons` - `Theme` (colours, fonts), `Motion` (durations,
  easings, radii), `Scheme` (the live wallpaper palette), `Config`.

`Theme` and `Scheme` follow the wallpaper, so do not hardcode a colour that
should theme. Match the existing usage in `plugins/photo-frame/`; do not invent
parallel styling. That is what keeps a
plugin from reading like a generic widget bolted onto the desktop.

## README and preview (required)

Every plugin ships a `README.md` and a preview image it embeds - name it
`assets/preview-widget.png` for a desktop tile, `assets/preview-popout.png` for
a popout. Follow the section order in `plugins/template/README.md`: title,
one-liner, the image, What it does, Install, How it plugs in, Settings table,
Develop tree, Credits.

## Test it locally

Before you list a plugin or open a PR, run it in your own shell. The dev
override discovers a plugin straight from its source folder - no registry entry,
no Store install, no receipt required:

```
# point the shell at this repo's plugins folder (colon-separate several dirs)
systemctl --user set-environment RYOSTORE_PLUGINS_DIR="$HOME/Work/ryostore/plugins"
systemctl --user restart ryoku-shell
```

Then open Ryoku Settings and enable it:

```
ryoku-shell hub open        # or Super+comma
```

Go to **Add-ons -> Plugins**, find your plugin, toggle it on, and set the host
to **Desktop widget** (or **Frame popout**). A desktop widget lands on the
wallpaper: drag to move it, drag the corner bracket to scale, right-click for its
menu and settings. Placement and settings persist to
`~/.config/ryoku/plugins.json` and the shell hot-reloads, so after the first
enable you can edit `content/Widget.qml` and reopen the widget to see the change
(restart `ryoku-shell` if a change is cached).

Watch the shell log while you open it, and confirm - at every density you
declare:

```
journalctl --user -u ryoku-shell -f
```

- it reports a size and renders (a root that never sets `implicitWidth` /
  `implicitHeight` collapses to nothing);
- drag, corner-resize, and the right-click menu all work on the wallpaper tile;
- every `metadata.settings` entry appears in the menu and actually changes the view;
- the log shows no QML errors when the widget opens.

Unset the override when you are done:

```
systemctl --user unset-environment RYOSTORE_PLUGINS_DIR
systemctl --user restart ryoku-shell
```

## List it in the registry

Add an object to the `plugins` array in `plugins/registry.json` so it appears in
Settings -> Plugins -> Discover:

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "path": "plugins/my-plugin",
  "version": "0.1.0",
  "author": "Your Name",
  "official": false,
  "tagline": "One short line.",
  "description": "One sentence.",
  "icon": "extension",
  "tags": ["desktop-widget"],
  "hosts": ["desktopWidget"],
  "preview": "assets/preview-widget.png",
  "screenshots": ["assets/preview-widget.png"],
  "lastUpdated": "2026-06-29"
}
```

Keep `path` as `plugins/<id>`, `hosts` in sync with the manifest, and
`lastUpdated` in `YYYY-MM-DD`. A few fields decide how the Store files it:

- `tags` classify it by surface. A bar widget carries `"bar-widget"`; a desktop
  plugin carries `"desktop-widget"` and/or `"frame-popout"`. The Store's
  ALL / BAR / DESKTOP subtabs filter on this and on `hosts`.
- `hosts` is copied from the manifest. It is what tells the shell, and the Store
  filter, whether the plugin is a bar mark, a desktop tile, or both.
- `official: true` is for plugins the Ryoku team maintains. Community plugins
  leave it `false` (or omit it). A community plugin shows this warning in the
  Store detail and under QS Bar Settings > Community, verbatim:

  > Community plugin. Ryoku does not review or maintain it: it runs inside your
  > shell with your permissions, so inspect its code before you trust it.

## Share a widget from your desktop

Built a widget in your own shell? You do not have to hand-write any of the above.
From the desktop:

- `ryoku plugin export <id>` copies the installed plugin into your Documents
  folder (`ryoku-plugins/<id>/`, or `~/ryoku-plugins/<id>/`), writes its
  `product-manifest.json` and a ready `registry-entry.json` (`official: false`),
  and inits a git repo. Inspect it, tidy the README, drop in a real preview.
- `ryoku plugin share <id>` goes the rest of the way: with `gh` logged in it
  forks this repo, adds `plugins/<id>/`, upserts the registry entry, and opens
  the pull request for you (it prints the URL). Without `gh` it opens the
  submission form prefilled.

Prefer to do it by hand? Drop the folder in `plugins/<id>/`, add its registry
entry, then regenerate the manifest and hash with the packer:

```
tools/pack-product.py plugins/<id> --touch
```

It rewrites `plugins/<id>/product-manifest.json` (per-file sha256, size, and
mode) and updates the entry's `manifestSha256` (and `lastUpdated`, with
`--touch`). Then run `tests/validate-catalogue.sh` and open your PR.

## Before you submit

- [ ] `manifest.json` `id` matches the folder name, and `version` is bumped.
- [ ] `hosts` in the manifest and the registry entry agree.
- [ ] `README.md` follows the template order and embeds a real
      `assets/preview-*.png` (not a placeholder).
- [ ] Tested locally via `RYOSTORE_PLUGINS_DIR` (see **Test it locally**): it
      renders, drags, resizes, and every setting works, with a clean shell log.
- [ ] Listed in `plugins/registry.json` with `path`, `hosts`, and `lastUpdated`
      correct.
- [ ] Regenerated `product-manifest.json` and its `manifestSha256` with
      `tools/pack-product.py plugins/<id>` after any file change.
- [ ] `tests/validate-catalogue.sh` passes from the repo root.
- [ ] `ryoku plugin validate <dir>` passes with no blocking findings; Ryostore
      CI will run it on your PR.

Then open your PR.
