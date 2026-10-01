# Nothing Audio

A charcoal circular audio widget with a geometric white waveform, based on
the user's Nothing OS screenshot. Click it to mute or unmute the default
PipeWire output. The icon turns grey when muted.

The service polls `bin/audio.py` every three seconds. The script reads the
default sink with `wpctl get-volume`; a click runs `wpctl set-mute`. It writes
no files, uses no network and needs no privileges.
