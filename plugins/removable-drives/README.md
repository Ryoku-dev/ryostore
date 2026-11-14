# Removable drives

A Ryoku QS Bar plugin (`removable-drives`) that lists every removable or USB
drive attached to the machine. You can unmount or eject a drive from it before
you pull the drive out, like the "removable media" tray applet on other
desktops.

## What it does

### Service

`service/Main.qml` polls `lsblk -J -b -o
NAME,PATH,TRAN,RM,HOTPLUG,MOUNTPOINT,SIZE,FSTYPE,LABEL,TYPE,MODEL` on a timer,
every 5 seconds by default, and flattens the device tree. It marks a device as
removable when `lsblk` reports `RM`, `HOTPLUG` or a `TRAN` of `usb` for the
device or any of its descendants. The `usb` check matters because many USB
HDD and SSD enclosures report `RM=0`.

The service exposes the flat drive list, the number of mounted removable
filesystems, and three actions:

- `unmountOne(path)` unmounts one filesystem. If the filesystem sits directly
  on an unlocked encrypted container, it then locks the container. If it is an
  LVM volume or a partition inside the container, the container stays
  unlocked and the notification says why. The notification only says the
  drive can be removed when nothing else on that disk is still mounted or
  unlocked; otherwise it names what is left.
- `ejectDisk(diskPath)` unmounts every mounted filesystem under that disk, at
  any depth. It locks every encrypted container on the disk that is still
  unlocked, including one whose filesystem you already unmounted by hand. It
  waits for udisks to settle, then powers the disk off.
- `refresh()` polls `lsblk` again.

Every action sends a `notify-send` desktop notification on success or failure,
so you see the result even with the panel closed. When udisks refuses an
unmount, lock or power-off, the plugin asks `lsof` which processes still hold
the filesystem or device. It names them in the notification and on the panel,
for example `In use by: vim (4242), bash (4243)`, so you know what to close.

### Widget

`content/Widget.qml` puts a fixed-width USB glyph on the bar. A small badge on
it shows how many removable filesystems are still mounted, which is the number
you still need to unmount. Clicking the glyph opens the panel and changes
nothing else.

### Panel

`content/Panel.qml` shows one card per attached removable disk, with its model,
size and device path. The disk's mounted partitions are listed under the card
with their label, mountpoint and size, and each has its own **Unmount**
button. A decrypted volume appears under the disk it lives on.

Each card also has an **Eject** button. It unmounts everything on the disk,
locks its encrypted volumes and runs `udisksctl power-off`, after which you can
unplug the disk. A **Refresh** button polls `lsblk` immediately.

## What it reads and writes

The plugin reads block-device state with `lsblk`, which changes nothing. The
unmount and eject actions run `udisksctl unmount -b <path>`,
`udisksctl lock -b <path>` and `udisksctl power-off -b <path>` as plain argv,
never through a shell string, and send the result with `notify-send`.

When udisks refuses one of these commands, the plugin runs
`lsof -w -F pc -- <mountpoint-or-device>`, which is also read-only, to name the
processes holding it. `lsof` only sees your own processes. If another user or
the kernel holds the device, the notification shows the udisks error text
instead.

`udisksctl` handles polkit authorization itself for filesystems mounted in your
own session, so the plugin never needs `sudo`, `doas`, `su` or `pkexec`. It
makes no network connections and writes no files. The manifest declares neither
`capabilities.privileged` nor `capabilities.network`.

## Encrypted drives

Before the plugin powers off a disk, it locks every unlocked container on it.
That covers LUKS1 and LUKS2, BitLocker, VeraCrypt and TrueCrypt (cipher
cascades included), and whole-disk encryption without a partition table. The
plugin recognises a container by the open `crypt` mapping that `lsblk` shows,
not by the partition type, because VeraCrypt volumes have no recognisable
header. It never unlocks anything.

When udisks refuses to lock a container, the notification says why:

- A container unlocked outside your session needs an administrator password
  to lock. That includes containers opened by another user, by `/etc/crypttab`
  or with `cryptsetup open`.
- udisks does not manage a volume mounted with the VeraCrypt app. Close it in
  VeraCrypt.
- LVM volumes inside the container keep it open. Deactivate the volume group as
  root with `vgchange -an <group>`. The plugin does not do this for you.

Hardware-encrypted drives and folder encryption such as fscrypt, gocryptfs and
Plasma Vaults need no lock. A plain unmount or eject is enough.

If `lsblk`, `udisksctl`, `lsof` or `notify-send` is not installed, the panel
names the missing command and keeps working.

## Settings

| key         | type   | default | description                       |
| ----------- | ------ | ------- | --------------------------------- |
| pollSeconds | int    | 5       | How often to re-poll `lsblk`      |
| showBadge   | toggle | true    | Show the mounted-count badge      |

## Preview

Take a screenshot of the widget, save it as `assets/preview-widget.png` and
list it under `files` in `manifest.json`. The store shows it in the catalogue.

## Check and install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

The second command installs the plugin onto the QS Bar. It also appears under
**QS Bar Settings > Community**.

## Author

Buxter <11074827+klopster@users.noreply.github.com>. This is a community plugin,
so `official` is false in the manifest.
