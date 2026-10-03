# Nothing Media

The preview image is a schematic illustration. It contains no wallpaper,
album art, track title or playback history.

A 392 × 256 charcoal music widget, sized to three columns by two rows of the
Nothing Interface grid, with album art filling the cover area when the
player provides it. The geometric record remains when art is unavailable. It
displays the selected MPRIS player's title, artist, progress and song text.
Synced lines follow the playback position; plain lyrics remain still. When
the song has no text, the card says so. The button toggles play/pause.

The service polls `bin/media.py` every two seconds. It reads local MPRIS
metadata through `playerctl`, then subscribes to `ryoku-shell.sock` for the
same lyrics frame as Ryoku's original desktop music widget. Ryoku's daemon
owns any lyric lookup. Qt may load the artwork URL supplied by the player;
for Spotify this is an HTTPS image. The plugin writes no files and needs no
privileges.
