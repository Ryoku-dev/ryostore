# Authoring a fastfetch preset for the Ryoku store

A fastfetch preset is one file: the readout a terminal prints when it opens.
Users install presets from **Settings -> Fastfetch**, and applying one copies
your `config.jsonc` verbatim over `~/.config/fastfetch/config.jsonc`.

Copy [`ryoku-dossier/`](ryoku-dossier) to start; it is a complete preset with
the colour contract already wired.

## Layout

```
fastfetch/
  registry.json         the catalogue (envelope: {"schema": 1, "fastfetch": [...]})
  <id>/
    config.jsonc        the preset, and the only file that reaches the terminal
    manifest.json       the product manifest (sizes + sha256 of every file)
    LICENSE             the licence the config ships under
    PROVENANCE.txt      where it came from and what was changed
    preview.webp        1280x720 capture of the readout, install false
```

One folder per preset, named for its `id`. Nothing ships until it is listed in
`registry.json`.

## What a preset may reach for

Applying a preset copies `config.jsonc` over `~/.config/fastfetch/config.jsonc`.
Its other files install alongside it, in the product's own directory:

```
~/.local/share/ryoku/fastfetch/<id>/
```

So a config may name a file in **its own product directory and nowhere else**.
fastfetch expands a leading `~`, which makes that path stable for every user:

```jsonc
"logo": {
  "type": "kitty-direct",
  "source": "~/.local/share/ryoku/fastfetch/my-preset/emblem.png",
  "width": 18, "height": 9,
  "padding": { "left": 1, "right": 3, "top": 1 }
}
```

Every asset named this way must be declared in `manifest.json` with
`"install": true`, or it will not be there when the config asks for it. A
config that names a home directory, an absolute path, another product, or a
shell substitution is rejected.

A logo can also need no asset at all:

```jsonc
"logo": { "type": "builtin", "source": "arch" }
"logo": { "type": "small",   "source": "arch" }
"logo": { "type": "none" }
"logo": { "type": "data", "source": "  /\\\n /  \\\n/____\\\n" }
```

`data` processes `$1`-`$9` colour placeholders; `data-raw` prints verbatim.
Ship only art you are free to redistribute, and say where it came from in
`PROVENANCE.txt`.

Image logos draw through the kitty graphics protocol. Ryoku ships kitty, so
they render as intended there; in a terminal without it fastfetch quietly falls
back to the built-in logo, which is why the readout must still read well
without the picture.

There are no `command` modules. Anything that shells out depends on the user's
tools and can hang a terminal on every launch. Use the built-in module instead,
or drop the row.

## Sizing an emblem

`width` and `height` are character cells, not pixels, and a cell is about twice
as tall as it is wide. For art that should look square, make the cell box about
`2.2 : 1`, and derive the rest from the source's aspect:

```
height = width x (source height / source width) / 2.25
```

The emblem occupies `left + width + right` columns of every row, so count it
against the width budget below. Keep the source itself small - 512 px on the
long side is more than a terminal can show.

## Design budget

The readout opens in every new terminal, so it stays inside **100 columns and
40 lines**, or **105 columns** once an emblem's own columns are counted in.
Wider wraps on a split pane; taller scrolls the first thing the user sees off
the top.

Box drawing has to survive a monospace grid: every border row of a box needs
the same visible width, and Nerd Font icons and CJK count as two columns. Check
the rendered output, not the source:

```sh
fastfetch -c fastfetch/<id>/config.jsonc --pipe false | cat -A | less
```

## Colour, and how it follows the system

fastfetch has four named colour slots. Set them once in `display.color`, then
refer to them from any format string:

| slot | set in | referenced as | what it paints by default |
| --- | --- | --- | --- |
| `keys` | `display.color.keys` | `{#keys}` | module keys |
| `title` | `display.color.title` | `{#title}` | the title module |
| `output` | `display.color.output` | `{#output}` | module values |
| `separator` | `display.color.separator` | `{#separator}` | the key/value separator |

Values may be hex (`"#e2342a"`), an ANSI code (`"38;2;226;52;42"`), or a name
(`"red"`). Prefixes compose: `{#1;keys}` is the slot in bold.

Route the design's accent through a slot rather than hardcoding it in each
format string. A preset whose colour lives in one object can be repainted; a
preset with the same hex typed into fifteen format strings cannot.

An adaptive design may record the intended system roles as a comment:

```jsonc
// ryoku:recolor keys=primary title=foreground separator=outline
```

**Compatibility note:** the current `ryoku-arch` Fastfetch apply path copies the
configuration verbatim; it does not consume this marker or automatically rewrite
these slots when the wallpaper changes. Keep readable literal colours in
`display.color`. The marker records recolouring intent for tooling that supports
it, but is not a promise of live theming on current Ryoku.

The role names correspond to `~/.cache/ryoku/colors.json`: `primary`, `secondary`,
`tertiary`, `foreground`, `background`, `surface`, `outline`, `outlineVariant`,
`onSurface`, `onSurfaceVariant`, and `color0`-`color15`. Omit the marker when a
fixed palette is integral to the design, and describe the actual behaviour in
the store listing.

ANSI palette references (`{#31}`, `{#1;33}`, `{#@141}`) already follow the
terminal theme, which Ryoku regenerates from the same palette. They are a fine
way to stay in step without the marker.

## preview.webp

The preview is a real capture of the readout, never a mock-up: exactly
**1280x720**, WebP, listed in the manifest with `"install": false`.

Shoot it in kitty with its default sixteen colours so the preset's own palette
is what shows, on a background equal to the entry's `surface`, then trim to the
text and centre it on the 1280x720 frame. Check the result before you commit
it: no clipped glyphs, no wrapped line, no ragged box edge.

## registry.json entry

Add a row to the `fastfetch` array:

| field | meaning |
| --- | --- |
| `id` | kebab-case slug, matching the folder and `manifest.json` |
| `name` | display name in Settings |
| `version` | product version, matching `manifest.json` |
| `path` | `fastfetch/<id>` |
| `author` | who wrote the design |
| `summary` | one line for the card |
| `description` | what the readout shows and how it looks |
| `tags` | lowercase keywords |
| `accent` | `#rrggbb`, the readout's accent (the card's accent) |
| `surface` | `#rrggbb`, the background the design assumes |
| `preview` | `preview.webp` |
| `screenshots` | extra captures, usually `[]` |
| `manifest` | `manifest.json` |
| `manifestSha256` | sha256 of `manifest.json` |

`manifest.json` repeats `id`, `category: "fastfetch"` and `version`, and lists
every file with its size and sha256. Regenerate both hashes whenever the config
changes; the validator compares them against the bytes on disk.

## Test and submit

Apply the preset from a checkout as [`DEVELOP.md`](../DEVELOP.md) describes,
open a fresh terminal, then validate from the repo root:

```sh
tests/validate-catalogue.sh
```

It should print `catalogue OK`. Then follow
[`CONTRIBUTING.md`](../CONTRIBUTING.md) to submit.
