# Bundles

A bundle is a named set of tools you install together: packages, small installer
scripts, and (later) Ryoku plugins. The Hub's Extras section lists every bundle
here and installs it, or individual items, with one click, backed by
`ryostore-install`.

Each bundle lives in its own folder under `bundles/<id>/` with a `bundle.json`.
The top-level `registry.json` is the index the Hub reads to discover them.

## `registry.json`

```jsonc
{
  "version": 1,
  "bundles": [
    {
      "id": "the-ricer",                 // matches the folder name and bundle.json id
      "name": "The Ricer",               // display name
      "description": "...",              // one-line blurb for the card
      "sources": "System packages",      // where its items come from, for the card label
      "path": "bundles/the-ricer"
      // "packageManagers": ["pacman"],   // optional gate, see "Every Ryoku edition"
      // "packageManagersReason": "..."   // the sentence shown where it is unavailable
    }
  ]
}
```

## `bundle.json`

```jsonc
{
  "id": "the-ricer",
  "name": "The Ricer",
  "description": "Eye-candy and theming tools that don't ship with Ryoku by default.",
  "requires": ["multilib"],              // optional: repos to enable before installing
  "items": [
    { "type": "package", "name": "gpick", "detect": "gpick",
      "summary": "GTK color picker.", "source": "official", "upstream": "https://..." },
    { "type": "script", "name": "ffuf", "detect": "ffuf",
      "summary": "Fast web fuzzer.", "source": "go", "upstream": "https://..." }
  ]
}
```

Each item has a `type`, a `name`, an optional one-line `summary`, an optional
`source` and `upstream` (shown on the card), and a `detect` command:

- **`package`** a package, named as Arch names it. `ryostore-install` routes it
  through `ryoku-host`, so you only ever write that one name. On Arch and
  CachyOS a package that resolves with `pacman -Si` installs from the official
  repos via `ryoku-pkg-add` and the rest from the AUR via `ryoku-pkg-aur-add`.
  On Fedora and Void, which have no AUR, `ryoku-host` names the package for the
  edition from `bundles/packages/<edition>.tsv` and installs it with the
  edition's own manager; see [Every Ryoku edition](#every-ryoku-edition).
  Presence is decided by the package manager; `detect` just documents the
  command the package provides. Packages are batched; anything already present
  is skipped.
- **`script`** installed by running `bundles/<id>/installers/<name>.sh` (see
  [`installers/README.md`](../installers/README.md)). `detect` is the command the script produces, and the
  item is present when that command is on `PATH`.
- **`plugin`** installed through the shell's plugin path, not this command. The
  actuator marks it deferred; install it from the Plugins tab.

`requires` lists prerequisites the actuator satisfies before a bundle's packages
are routed, each idempotent and safe to repeat:

- `multilib` enables Arch's `[multilib]` repo (Steam and every `lib32-` package
  live there). Fedora needs no step, and Void enables its multilib and nonfree
  repositories per package, as the table rows name them.
- `cachyos` adds the `[cachyos-v3]` and `[cachyos]` repositories below every
  Arch repository, so Arch packages stay authoritative. Only Arch and CachyOS
  can use it, so the CachyOS Gaming bundle carries a `packageManagers` gate.
- `gpu-lib32` runs `ryoku-gpu-lib32` to install the 32-bit GPU drivers matching
  the machine, on every edition (Gaming lists it after `multilib`, so the repo
  is on first).

An unrecognised requirement aborts with a "run ryoku update" message rather than
mis-routing the bundle's packages.

## Every Ryoku edition

Ryoku runs on Arch, CachyOS, Fedora and Void, and a bundle offers the same
items on all of them. Item code never names a distribution's tools: scripts go
through the `ryoku-host` seam (`ryoku-host pkg`, `ryoku-host svc`, ...), which
the security screen enforces.

**Edition tables.** `bundles/packages/void.tsv` and `bundles/packages/fedora.tsv`
name every bundle package for that edition, one row per Arch name:

```
arch	void	lanes	notes
steam	steam libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit	gaming	repo=nonfree,multilib
reaper	-	the-influencer	REAPER is proprietary and not packaged for Void; download it from reaper.fm.
```

The second column lists the edition's package names (several when one Arch
package splits), or `-` when the edition has none; the note on a `-` row is the
reason the Store shows. `lanes` lists the bundles that use the package. On Void,
`repo=` names the official repositories a package needs switched on first, and
`repo=ryoku` marks a package from Ryoku's own repository. `ryoku-host` lays the
table under Ryoku's own edition table, and Ryoku's row wins.

An item an edition cannot have stays listed in the Store, greyed out with its
reason, and **Install all** skips it. The validator checks that the tables are
sorted, that every bundle package has a row in each, and that every `-` row
gives a reason. Check a row against the real repositories before you add it:

```sh
docker run --rm -v "$PWD/bundles/packages:/s:ro" -v "$(command -v ryoku-host):/rh:ro" \
  -e RYOKU_HOST_PKGMGR=xbps ghcr.io/void-linux/void-glibc:latest \
  sh -c 'xbps-install -Syu xbps >/dev/null; /rh pkg --overlay /s/void.tsv status <name>'
```

It prints `installed`, `available` or `unavailable` with the row's reason.

**Gates.** When an item cannot be ported at all, because it needs the AUR or
Arch's own repositories, it names the package managers that can have it:
`"packageManagers": ["pacman"]` with a `"packageManagersReason"` sentence, on a
registry entry for a whole bundle or on one item. Use a gate only when no
edition table row could work.

## How installs run

Installs are per item with real feedback:

- The Extras section runs `ryostore-install` inside a **floating terminal** so
  the `sudo` and AUR prompts have a TTY; package installs cannot complete from a
  silent background process. You watch progress there and type your password if
  asked.
- The command writes a per-bundle JSON report
  (`$XDG_RUNTIME_DIR/ryostore/<id>.json`) with each item's `status`
  (`present` | `installing` | `installed` | `removing` | `removed` | `absent` |
  `failed` | `deferred` | `skipped`) that the Hub watches to drive per-item state.
  `ryostore-install status bundle <id>` reports presence without changing
  anything.
- **Uninstall all** (or a single tool) removes the bundle's package items with
  `ryoku-pkg-remove`. Scripts are not auto-removed; plugins are removed from the
  Plugins tab.

## Tiers, interactive items, code guests, and imagery

Each item may set `"tier": "core"` (default) or `"tier": "optional"`. **Install
all** installs only core items; optional items install one at a time from the
card. A `script` item may set `"interactive": true` when it needs the user to
act (for example a manual download that cannot be automated); an aborted
interactive install reports as *deferred*, not *failed*.

A bundle can also ship its own code as guests, all living in this repo:

- `{ "type": "plugin", "name": "<id>" }` a shell plugin from `plugins/<id>/`
  (see [`plugins/AUTHORING.md`](../plugins/AUTHORING.md)): a desktop widget or a
  frame popout, enabled and placed from Settings.
- `{ "type": "nautilus-pack", "name": "<id>" }` a right-click file-manager
  script pack from `nautilus/<id>/` (see
  [`nautilus/AUTHORING.md`](../nautilus/AUTHORING.md)).

Store imagery: a bundle carries `"icon"` (a Material glyph name), `"accent"` (a
hex colour), `"preview"` (a hero image), and `"screenshots": [...]`, all
relative to `bundles/<id>/assets/`. The Hub resolves them to absolute URLs when
it builds the catalogue.
