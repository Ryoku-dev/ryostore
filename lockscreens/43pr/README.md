# 43PR monochrome lockscreen

The centered clock/date and outlined password capsule from 43PR's Hyprlock
configuration, adapted to Ryoku's existing qylock theme host. Install from
Ryostore > Lockscreens and select it in Ryoku Hub > Lockscreen.

The host, not this theme, owns secure session locking and PAM authentication.
Passwords are passed only to its `sddm.login` bridge, cleared from the input
immediately, and never logged or written. The theme has no external commands,
file writes, network access or privileged actions. Previewing does not lock.

This is a visual port, not a Hyprlock config installer. It uses a solid dark
background rather than capturing the desktop, and omits the upstream media
polling scripts and hardcoded keyboard-layout controls. No external artwork or
font files are bundled. See `PROVENANCE.txt` and `LICENSE` for attribution.

Maintenance: https://github.com/Sipper1236/ryostore/issues
