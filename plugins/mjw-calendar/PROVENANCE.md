# Provenance

`content/` is ported from end4-pC (https://github.com/pctrade/end4-pC), commit 0ff392b, files
`modules/ii/background/widgets/calendar/` and the shared
`modules/common/` widgets and services they use. end4-pC is a fork of
illogical-impulse in end-4/dots-hyprland (https://github.com/end-4/dots-hyprland); both are GPL-3.0, so this
plugin is GPL-3.0-only (LICENSE). The illogical-impulse widget tree is the
material; the port replaced only the shell-wide singletons (Config,
Appearance, GlobalStates, Directories, compositor services) with plugin-local
views of Ryoku's live daemon palette, weather topic and wallpaper state, and
moved placement to the Ryoku desktop host. See NOTICE.
