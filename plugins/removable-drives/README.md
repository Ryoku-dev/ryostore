# Removable Drives

A Ryoku QS Bar plugin (`removable-drives`) that lists every removable/USB
drive currently attached and lets you safely unmount or eject it before you
pull it out, the way other desktops' "removable media" tray applet does.

## What it does

- **Service** (`service/Main.qml`): polls `lsblk -J -b -o
  NAME,PATH,TRAN,RM,HOTPLUG,MOUNTPOINT,SIZE,FSTYPE,LABEL,TYPE,MODEL` on a timer
  (default every 5s), flattens the device tree, and marks a device (or any of
  its descendants) "removable" when `lsblk` reports `RM`, `HOTPLUG`, or a `TRAN`
  of `usb` (plenty of USB HDD/SSD enclosures report `RM=0` even though they are
  clearly removable). It exposes the flat drive list, the count of mounted
  removable filesystems, and three actions: `unmountOne(path)`,
  `ejectDisk(diskPath)` (unmounts every mounted filesystem anywhere under that
  disk, at any depth, waits briefly for udisks to settle, then powers the disk
  off), and `refresh()`. Every action fires a `notify-send` desktop
  notification on success or failure, so the result is visible even with the
  panel closed.
- **Widget** (`content/Widget.qml`): a fixed-width USB glyph on the bar with a
  small badge showing how many removable filesystems are currently mounted
  (i.e. still need a safe unmount). Clicking it only opens the panel; it never
  mutates anything.
- **Panel** (`content/Panel.qml`): one card per attached removable disk
  (model, size, device path) with its mounted partitions listed underneath
  (label, mountpoint, size), each with its own **Unmount** button, plus a
  per-disk **Eject** button that unmounts everything on that disk and runs
  `udisksctl power-off` so it is safe to physically remove. A **Refresh**
  button forces an immediate re-poll.

## What it reads and writes

Reads block-device state via `lsblk` (read-only). Unmount/eject actions run
`udisksctl unmount -b <path>` and `udisksctl power-off -b <path>` as plain argv
(never through a shell string), and fire `notify-send` for the result.
`udisksctl` handles its own polkit authorization for a user's own
session-mounted filesystems, so this plugin never needs `sudo`, `doas`, `su`,
or `pkexec`. No network access. No files are written anywhere (no
`capabilities.privileged`, no `capabilities.network`).

## Settings

| key         | type   | default | description                       |
| ----------- | ------ | ------- | --------------------------------- |
| pollSeconds | int    | 5       | How often to re-poll `lsblk`      |
| showBadge   | toggle | true    | Show the mounted-count badge      |

## Preview

Capture a real screenshot of the widget and save it as
`assets/preview-widget.png`, then list it under `files` in `manifest.json`. The
store shows it in the catalogue.

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

It installs straight onto the QS Bar; it also shows under **QS Bar Settings >
Community**.

## Author

Buxter <11074827+klopster@users.noreply.github.com>: this plugin is community-made (`official` is false).
