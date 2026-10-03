# Nothing Screen Time

A charcoal capsule with a dotted readout of **today's** screen time. It uses the
same total as Ryoku's Stash and Screen Time service, which counts focused apps
and persists the last 30 days. The value resets at midnight, not when this
widget is reloaded.

`service/Main.qml` runs `bin/activity.py` every ten seconds. The script only
reads `$XDG_STATE_HOME/ryoku/screentime.json` (or the corresponding
`~/.local/state` path) and prints today's total. It writes no files, uses no
network and needs no privileges. Ryoku persists the counter about every 30
seconds, so this display may lag the Stash by that amount.
