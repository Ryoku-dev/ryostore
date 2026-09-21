# Provenance and licensing determination

This file records the evidence behind the plugin's declared licence
(`MIT AND CC-BY-SA-4.0`). See `LICENSE` (MIT, the code) and `NOTICE`
(attribution and the data terms).

## Summary

The plugin is a composite. Its code is original and MIT. One bundled data file
is derived from a CC BY-SA 4.0 source and therefore carries that licence
itself, which is why the declared licence is a conjunction rather than plain
MIT. Nothing in the tree is GPL, and no third-party UI code is vendored.

## 1. The code is original

`service/Main.qml`, `content/*.qml` and `bin/kotoba` were written for this
plugin. No QML was copied from the Ryoku shell, from `end-4/dots-hyprland`, or
from any other plugin. The only external QML the tree touches is the public
`Ryoku.PluginKit` module (`MicroLabel`), imported, never copied — which is
exactly what R4 permits.

## 2. The vocabulary deck is EDRDG-derived — CC BY-SA 4.0

`data/decks/core-vocab.json` is built from:

- **JMdict_e** — `http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz`
- **KANJIDIC2** — `http://ftp.edrdg.org/pub/Nihongo/kanjidic2.xml.gz`

Both are EDRDG publications licensed **CC BY-SA 4.0**
(`https://www.edrdg.org/edrdg/licence.html`). The build keeps entries carrying
JMdict's own frequency markers (`nf01`–`nf20`, `news1`, `ichi1`, `spec1`),
takes the first English gloss, and joins KANJIDIC2 `grade` as a difficulty
proxy.

Three obligations follow, all met:

1. **Attribution.** Credited in `NOTICE`, in `README.md`, and visibly on the
   widget itself — the tile's footer renders the source and licence of every
   loaded deck that is not CC0. That credit is derived at runtime from the
   deck files actually loaded, so it cannot drift out of date or be shown
   falsely.
2. **ShareAlike.** `core-vocab.json` is a derived version of the dictionary
   data, so the file is itself distributed under CC BY-SA 4.0. This is scoped
   to the data file; the standard reading is that an application bundling the
   data is not a derivative work of the data, so the plugin code stays MIT.
3. **Notification.** EDRDG asks to be told about substantial uses. This is a
   request rather than a licence condition; it costs nothing and should be
   done before any public listing.

### What was deliberately NOT used

**JLPT vocabulary lists were rejected.** The Japan Foundation withdrew the
official lists after the 2010 exam revision and has published none since.
Every N5–N1 list in circulation — Tanos / `jlptstudy`, and the `jlpt-vocab`
repositories that derive from it — is a community reconstruction with **no
explicit open licence on the word data**. Repositories carrying an MIT licence
generally license their *code*, not the list they inherited.

Difficulty ordering therefore comes from JMdict frequency markers and
KANJIDIC2 grade, both unambiguously CC BY-SA 4.0, rather than from a list this
plugin has no clear right to redistribute.

## 3. FSRS — MIT, reimplemented

`bin/kotoba` implements the FSRS memory model and uses its published default
parameters. The algorithm and its reference implementations
(`open-spaced-repetition`) are MIT. The Python in this tree was written for
this plugin; the model and parameters are the FSRS project's work, credited in
`NOTICE`.

An algorithm is not itself copyrightable; the MIT attribution is given because
the parameter set is the project's published output and crediting it is right.

## 3a. The optional downloaded dictionary

v1.1 can download JMdict_e, KANJIDIC2 and the Tanaka Corpus from
`ftp.edrdg.org` on explicit user action. This is a **fetch, not a
redistribution**: the files land in the user's own cache and are imported into
a local database. The plugin tree ships none of them, so the tree's licence is
unchanged by the feature.

Attribution is still given — in `NOTICE`, in `README.md`, and on the widget
itself, whose footer credit is derived at runtime from the decks actually
loaded.

The raw EDRDG XML is used rather than the `jmdict-simplified` JSON
redistribution because the simplified form **drops the `nf` frequency bands**
and carries no kanji grades, which would silently remove two of the four deck
axes. Verified against release 3.6.2: 22,640 common words, zero `nf*` tags
retained.

## 4. Fonts

No font is bundled. Japanese text uses Noto Sans CJK JP from the system
(`noto-fonts-cjk`, OFL 1.1).
