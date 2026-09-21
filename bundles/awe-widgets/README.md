# Awe Widget Set

The full Awe suite in one install: 24 Material 3 desktop widgets for your
wallpaper, ported to run as Ryoku plugins. Each one lands as its own plugin
(`awe-clock`, `awe-weather`, ...), so after installing the set you pick which
tiles appear from the desktop's **Add widget** menu, and every tile drags,
scales, and locks like the built-in clock.

The widgets are a port of [Awe](https://github.com/neur0map/MJ-widgets)
(Boost Software License 1.0) by neur0map. Position and size persistence from
the original is dropped: the Ryoku shell owns placement. Each widget's README
lists exactly what it runs, reads, and writes.

## What installs

- 24 plugins (see the component list). No packages, no scripts.
- Nothing is enabled by the install itself; toggle tiles from the desktop.

## Removing

Remove the set from the Store, or remove individual widgets from
Settings > Add-ons. Each plugin cleans up its own state under
`~/.local/state/ryoku/plugins/<id>/`.
