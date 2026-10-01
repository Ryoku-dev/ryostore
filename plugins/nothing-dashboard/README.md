# Nothing Battery

This desktop widget replaces the former CPU/MEM/BAT diagnostic dashboard. Its
charcoal square, circular device pictogram and dotted percentage follow the
user's Nothing OS screenshot. N-Red appears only when the battery is critical.

`service/Main.qml` runs `bin/status.py` every ten seconds. The script reads
`/sys/class/power_supply/BAT*/capacity` and `status`, writes nothing, accesses
no network and uses no privileges. The widget is visual only.
