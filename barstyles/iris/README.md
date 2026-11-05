# Shima

Shima is Ryoku's native integration of [iNiR](https://github.com/snowarch/iNiR)
by snowarch and contributors. It includes the iRiS, Material ii and Waffle
panel families, upstream widgets, configurable animations, Liquid Glass,
audio-reactive Cava visualisers, Matugen-aware colour palettes and a Ryoku
paper-and-ink appearance.

Shima remains a normal Ryoku subshell. Select it in Hub and manage installation
and updates through RyoStore. It uses the established `barstyles/iris` identity,
not a separate session or a duplicate Shima product.

## Installation

This directory publishes storefront metadata and preview imagery only.
Shima's executable runtime is installed through the native Ryoku integration,
which pins and builds iNiR through Nix on Ryoku-on-NixOS.

Do not install these metadata files as an independent barstyle. Editions without
native Shima support must leave installation unavailable rather than offering a
non-functional package. RyoStore editions with a native `iris` entry may merge
this presentation onto that entry while retaining their own install lifecycle.

The embedded preview was taken from the integrated Shima desktop and shows
Organic Edge visualisers and media controls. SDDM integration is not included.

## Credits

- **snowarch and the iNiR contributors:** upstream iNiR desktop shell
- **aethctl:** Shima's Ryoku integration and storefront preview

The upstream iNiR project is licensed under GPL-3.0. No upstream QML runtime
source is duplicated in this catalogue product.
