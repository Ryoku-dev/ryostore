# Visualizer

A desktop audio-spectrum tile, ported from the Awe widget suite
(github.com/neur0map/MJ-widgets, BSL-1.0).

![Visualizer on the desktop](assets/preview-widget.png)

## What it does

It draws the desktop's real audio spectrum, in one of three modes (bars, wave,
radial); double-click or tap the mode pill to cycle them. The bands come from
the tile's own PipeWire playback analyser, so it answers to whatever is
actually playing -- music, a browser video, a game -- not one media player, and
it settles to a faint resting breath on silence.

## Commands and network

- One optional command: the tile runs `cava` itself to read the PipeWire
  playback monitor, and only while a stream is actually playing. cava is an
  optional dependency: without it the tile stays at its resting line rather
  than failing.
- No network access.

It writes nothing to disk (the analyser config is piped to cava's stdin). The
original stored tile position, scale and mode on disk; that persistence is
dropped because the shell owns placement and scale.

## Credits

Ported from Awe by neur0map. BSL-1.0.
