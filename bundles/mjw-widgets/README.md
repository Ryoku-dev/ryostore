# MJ Widget Set

The full MJ suite in one install: 25 desktop widgets for your wallpaper.
Fifteen of them are ports of the desktop widgets from
[end4-pC](https://github.com/pctrade/end4-pC) (a maintained fork of
[illogical-impulse](https://github.com/end-4/dots-hyprland)) - the clock faces,
calendar, world clock, media card, notes, todo, timers, visualizer, weather,
resources, user card, custom text, image, sticker and image converter - rebuilt
to run as Ryoku plugins: they follow your live theme (matugen / named scheme),
blur your actual wallpaper, read weather from the desktop's own weather daemon
(no API key), and work on Hyprland and niri alike. The ten utility tiles from
the original set (battery, calculator, clipboard, crypto, git, habits, network,
ping, storage, thermal) stay in the set, regrouped under the MJ name.

The set was previously published as **Awe**; the duplicate Awe tiles were
replaced by the illogical-impulse ports, which take priority in function and
look. Each plugin lands as its own install (`mjw-clock`, `mjw-weather`, ...),
so after installing the set you pick which tiles appear from the desktop's
**Add widget** menu, and every tile drags, scales, and locks like the built-in
clock. Right-click a tile for its settings: faces, sizes, shapes and colours
are per-widget, and changes apply live.

## What installs

- 25 plugins (see the component list). No packages, no scripts.
- Nothing is enabled by the install itself; toggle tiles from the desktop.

## Removing

Remove the set from the Store, or remove individual widgets from
Settings > Add-ons. Each plugin cleans up its own state under
`~/.local/state/ryoku/plugins/<id>/`.

## Licensing

The ported widget code derives from end4-pC / illogical-impulse (GPL-3.0);
each plugin carries its own LICENSE, NOTICE and PROVENANCE files.
