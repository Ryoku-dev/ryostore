# Fan Control

Fans on the QS Bar, and a panel that changes what the kernel is doing with them.

Source and issues: <https://github.com/lorenzo-vecchio/fan-control>

The bar mark shows the fan speed (or the profile, or the hottest sensor - your
pick) and turns gold when a sensor crosses your warning temperature. Click it and
the panel opens: the live rpm, the hottest sensors, and four ways to run the
fans - **AUTO** (the EC's own curve), **PERFORMANCE** (a fixed high level),
**MAX** (full speed) and a custom level slider.

Community plugin (`official` is false): not reviewed or maintained by Ryoku.

## Profiles

| Tap | What it writes | When to use it |
| --- | --- | --- |
| **AUTO** | `pwm1_enable=2`, the kernel's "hardware PWM": the EC/firmware owns the fans again | the resting state; exactly what a fresh boot comes up in |
| **PERFORMANCE** | `pwm1_enable=1` + `pwm1=performanceLevel` (128-255, default 200) | a long build or a call on your lap: louder than the EC's curve, cooler |
| **MAX** | ThinkPad: `pwm1_enable=0`, the EC's "disengaged" full speed. Elsewhere: `pwm1_enable=1` + `pwm1=255` | the heaviest load |
| **CUSTOM** | `pwm1_enable=1` + `pwm1=<slider>` (128-255) | you want an exact level |

The fan is **never** driven below `128/255`: that is the kernel's own documented
safe floor ("try to set pwm1 to at least 128"), below which the EC may stop the
fan entirely. The slider, the manifest schema and the helper all clamp to it, so
this plugin cannot switch a fan off.

Nothing is applied at login: a fresh boot starts on the EC's own curve, and the
panel always shows the profile the machine is *actually* on, read back from
`pwm1_enable`, not the last button you tapped. The firmware keeps the last word
either way - a ThinkPad's DSDT reprograms the fan on its own when it decides it
must.

## What it runs, reads and writes

- **Runs** its own helper, `bin/fanctl`, a POSIX shell script shipped in the
  plugin folder. Nothing else. Two invocations:
  - `bin/fanctl status --json` - unprivileged, every `poll` seconds, reads sysfs
    and prints one JSON status.
  - `pkexec <plugin folder>/bin/fanctl set auto|max|level <n>` - privileged, only
    from a panel tap (see below).
- **Reads** `/sys/class/hwmon/*/{name,fan*_input,temp*_input,temp*_label,pwm1,pwm1_enable}`
  and `/sys/module/thinkpad_acpi/parameters/fan_control`.
- **Writes** `/sys/class/hwmon/hwmonN/pwm1_enable` and `pwm1` on one chip: the
  ThinkPad EC fan when there is one, else the first non-GPU chip exposing
  `pwm1_enable` (a desktop Super-I/O, a Dell, an ASUS). GPU fans are skipped:
  their `pwm` attributes normally report rather than control.
- **Settings** are the shell's own store (`~/.config/ryoku/plugins.json`), through
  the plugin API only. No state directory, no cache, no files of its own.
- **Network**: none. No host is contacted, and the plugin ships no binaries, only
  the shell script.

## Privileges

Fan control is a root-owned sysfs write, so the plugin escalates - only through
`pkexec`, only on an explicit tap in the panel, never from the bar mark and never
on a timer. It has two shapes, and the panel always says which one it used.

**The plugin's own helper (default: asks).** `pkexec <plugin folder>/bin/fanctl
set ...`. This copy lives in your home, so it can never be granted passwordless -
anything able to write that file would get root out of it. `hyprpolkitagent`
asks for your password the first time; polkit then keeps the authorisation for
about five minutes, so switching profiles a few times in a row does not re-prompt.

**A root-owned copy (optional: no prompt at all).** Install the same helper at a
fixed, root-owned path and authorise *exactly* that path with a polkit rule - the
same shape as Ryoku's own `4x-ryoku-*.rules` for `ryoku-power` and
`ryoku-game-tune`. This is a one-time, by-hand step; a community plugin cannot
install system files:

```
sudo install -m 0755 -o root -g root \
  ~/.local/share/ryoku/plugins/fan-control/bin/fanctl /usr/local/bin/ryoku-fanctl

sudo tee /etc/polkit-1/rules.d/56-ryoku-fan-control.rules >/dev/null <<'EOF'
polkit.addRule(function (action, subject) {
    if (action.id === "org.freedesktop.policykit.exec" &&
        action.lookup("program") === "/usr/local/bin/ryoku-fanctl" &&
        subject.local && subject.active && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
```

With that in place the plugin uses the root-owned copy on its own (the
**Privileged helper** setting, `auto` by default) and taps apply immediately.
The grant stays safe because nobody but root can rewrite a root-owned file, and
because nothing the caller says reaches an arbitrary write: the helper accepts
three verbs (`auto`, `max`, `level <n>`), validates the level as an integer
inside 128-255, and writes only `/sys/class/hwmon/*/pwm1` and `pwm1_enable`,
built from `/sys/class/hwmon`. Delete the rule file to be asked again. After a
plugin update that changes `bin/fanctl`, re-run the `install` line to refresh the
system copy.

## Requirements

- A fan the hwmon interface can *control*: `pwm1` and `pwm1_enable` present and
  writable.
- **ThinkPads**: `thinkpad_acpi` must be loaded with `fan_control=1`, because the
  kernel disables fan control by default ("fan control operations are disabled by
  default for safety reasons, to enable them the module parameter fan_control=1
  must be given"). Without it the panel says so instead of failing silently:

  ```
  echo 'options thinkpad_acpi fan_control=1' | sudo tee /etc/modprobe.d/thinkpad-acpi.conf
  # then reboot, or: sudo modprobe -r thinkpad_acpi && sudo modprobe thinkpad_acpi fan_control=1
  ```

- Many other machines (Dell, ASUS, desktops with a Super-I/O chip such as
  `nct6775`) need nothing. If the machine exposes no `pwm1_enable` at all, the
  panel shows a read-only notice and the plugin still reports rpm and
  temperatures.

## Settings

| key | type | default | description |
| --- | --- | --- | --- |
| barText | choice | rpm | what rides beside the bar mark: nothing, RPM, the profile, or the hottest sensor |
| poll | int | 5 | seconds between the unprivileged status reads (2-60) |
| warnTemp | int | 90 | past this the readout and the bar mark turn gold (40-110 C) |
| helperMode | choice | auto | which helper the privileged writes use: the root-owned copy when installed, always it, or always the plugin's own copy |
| performanceLevel | int | 200 | the level PERFORMANCE applies (128-255) |
| customLevel | int | 191 | where the panel's slider starts, and what APPLY remembers |

## Preview

`assets/preview-widget.png` is a real capture of the mark on the QS Bar, and
`assets/preview-panel.png` one of the panel: the rpm, the hottest sensors, the
three profiles and the custom level slider.

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

Or straight from the repository, the way any user would:

```
ryoku plugin add https://github.com/lorenzo-vecchio/fan-control --bar --yes
```

It lands on the bar and lists under **Community** in QS Bar Settings.

## Author

Lorenzo Giovanni Vecchio <106695602+lorenzo-vecchio@users.noreply.github.com>:
this plugin is community-made (`official` is false).
