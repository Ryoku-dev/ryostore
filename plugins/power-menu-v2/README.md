# Power Menu V2

A Ryoku bar plugin (`power-menu-v2`): a profile-style power menu. The panel shows
your avatar and name from the Hub's Profile page, the installed Ryoku version, the
hostname and uptime, a Settings button, and the six session actions in one group.
Every colour comes from the plugin kit `Theme`, so it follows the Ryoku theme and
wallpaper.

## What runs

| Action    | Command                                             |
| --------- | --------------------------------------------------- |
| Lock      | `ryoku-shell lock`                                  |
| Log out   | `hyprctl dispatch hl.dsp.exit()`                    |
| Suspend   | `ryoku-shell suspend`                               |
| Hibernate | `bin/hibernate.sh` (locks, confirms the lock via `journalctl`, then `systemctl hibernate`; `notify-send` if the lock isn't confirmed) |
| Reboot    | `systemctl reboot`                                  |
| Power off | `systemctl poweroff`                                |
| Settings  | `ryoku-shell hub open`                              |

When the panel opens it also runs three read-only queries: `pacman -Q ryoku`
(version badge), `uname -n` (hostname) and `cat /proc/uptime` (uptime).

With "Ask before acting" on, every action except Lock needs a second click within
four seconds. The bar glyph only opens the panel; it never runs anything.

## What it reads and writes

Reads `~/.config/ryoku/profile.json` (`text.name` and the `hero` settings) and the
image that file points at: the Hub's bundled `profile-hero.png` (default),
a file in `~/Pictures/ryodecors/` (gallery) or the custom path. It writes nothing.

## Settings

| key            | type   | default | description                    |
| -------------- | ------ | ------- | ------------------------------ |
| confirm        | toggle | true    | Ask before acting (click twice) |
| show_lock      | toggle | true    | Show Lock                      |
| show_logout    | toggle | true    | Show Log out                   |
| show_suspend   | toggle | true    | Show Suspend                   |
| show_hibernate | toggle | true    | Show Hibernate                 |
| show_reboot    | toggle | true    | Show Reboot                    |
| show_poweroff  | toggle | true    | Show Power off                 |

## Preview

Capture the widget as `assets/preview-widget.png` and list it under `files` in
`manifest.json`.
