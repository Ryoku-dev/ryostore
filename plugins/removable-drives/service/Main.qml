pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// service/Main.qml is the plugin's logic: no UI. The host loads one instance and
// hands it to every view as pluginApi.mainInstance, so the widget and the panel
// read the same live state.
//
// This plugin polls `lsblk` for every block device, flattens the tree, and
// marks any device (or its descendants) that reports rm/hotplug, or a usb
// transport, as a "removable" drive. Actions (unmount / eject) run
// `udisksctl`, which handles its own polkit authorization for the logged-in
// user's own mounts -- no sudo/pkexec needed here. An unlocked encrypted
// container (LUKS, BitLocker, VeraCrypt/TrueCrypt: anything with an open
// `crypt` mapping) is locked (`udisksctl lock`) after its filesystem is
// unmounted, so Eject never leaves an open mapping behind. When an unmount or
// lock is refused, the notification says why: the processes `lsof` sees
// holding it, a permission problem, or active LVM volumes. A missing command
// is reported, never left hanging.
Item {
    id: svc

    // Set by the host after this loads; the plugin's settings live behind it.
    // Read settings through pluginApi.pluginSettings, always behind a default,
    // and write them only through pluginApi.saveSetting(key, value) (R5).
    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property int pollSeconds: settings ? (settings.pollSeconds ?? 5) : 5

    // Flat list of every block device, each:
    // { name, path, parentPath, mountpoint, label, sizeLabel, fstype, type,
    //   model, tran, removable }
    property var drives: []
    property string lastError: ""
    readonly property string readErrorPrefix: "Could not read drives: "
    property string lastAction: ""
    property bool busy: false

    // Mounted removable filesystems -- the ones that actually need a safe
    // unmount before the stick can be pulled.
    readonly property var mountedRemovable: {
        var out = [];
        for (var i = 0; i < svc.drives.length; i++) {
            var d = svc.drives[i];
            // Any mounted removable filesystem needs a safe unmount before
            // removal -- including a disk formatted directly with no
            // partition table, not just its partitions.
            if (d.removable && d.mountpoint !== "")
                out.push(d);
        }
        return out;
    }

    readonly property int readyCount: mountedRemovable.length

    function formatSize(bytesStr) {
        var n = parseInt(bytesStr, 10);
        if (!n || n <= 0)
            return "";
        var units = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024;
            i += 1;
        }
        return (i === 0 ? n.toFixed(0) : n.toFixed(1)) + " " + units[i];
    }

    function flatten(node, parentPath, inheritedRemovable, out) {
        if (!node)
            return;
        // RM/HOTPLUG alone miss plenty of real "USB drive" cases -- many USB
        // HDD/SSD enclosures report rm=false (the kernel's "removable" sysfs
        // attribute is about the media, not the enclosure), so also trust
        // lsblk's own transport column.
        var removableHere = node.rm === true || node.hotplug === true || node.tran === "usb" || inheritedRemovable;
        var path = node.path || ("/dev/" + node.name);
        var entry = {
            name: node.name || "",
            path: path,
            parentPath: parentPath || "",
            mountpoint: node.mountpoint || "",
            label: node.label || "",
            sizeLabel: formatSize(node.size),
            fstype: node.fstype || "",
            type: node.type || "",
            model: node.model || "",
            tran: node.tran || "",
            removable: removableHere
        };
        out.push(entry);
        if (node.children) {
            for (var i = 0; i < node.children.length; i++)
                flatten(node.children[i], path, removableHere, out);
        }
    }

    function refresh() {
        if (lsblkProc.running)
            return;
        lsblkProc.didStart = false;
        lsblkProc.running = true;
    }

    Process {
        id: lsblkProc
        command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,TRAN,RM,HOTPLUG,MOUNTPOINT,SIZE,FSTYPE,LABEL,TYPE,MODEL"]
        // See cmdComponent: a binary that cannot start only flips `running`
        // back to false, without `started` or `exited`.
        property bool didStart: false
        onStarted: didStart = true
        onRunningChanged: {
            if (!running && !didStart)
                svc.lastError = svc.readErrorPrefix + "lsblk is not installed (it ships with util-linux).";
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    var out = [];
                    var devices = data.blockdevices || [];
                    for (var i = 0; i < devices.length; i++)
                        svc.flatten(devices[i], "", false, out);
                    svc.drives = out;
                    // Only clear a read error; an unmount/lock failure must
                    // stay on the panel after the refresh that follows it.
                    if (svc.lastError.indexOf(svc.readErrorPrefix) === 0)
                        svc.lastError = "";
                } catch (e) {
                    svc.lastError = svc.readErrorPrefix + e;
                }
            }
        }
    }

    Timer {
        interval: Math.max(2, svc.pollSeconds) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: svc.refresh()
    }

    // One-shot command runner: fire-and-forget argv, call
    // onDone(exitCode, stderr, stdout, missing) when it ends, then destroy
    // itself. Never built from an interpolated string (R9) -- argv arrays
    // only.
    //
    // A binary that is not installed never emits `started` or `exited` in
    // Quickshell; `running` just drops back to false. That case still calls
    // onDone, with missing = true, so no action is left waiting forever
    // (which used to leave `busy` set and every panel button disabled).
    Component {
        id: cmdComponent
        Process {
            id: proc
            property var onDone: null
            property string errText: ""
            property string outText: ""
            property bool didStart: false
            property bool finished: false
            stdout: StdioCollector {
                onStreamFinished: proc.outText = text
            }
            stderr: StdioCollector {
                onStreamFinished: proc.errText = text
            }
            function finish(code, err, out, missing) {
                if (finished)
                    return;
                finished = true;
                var cb = onDone;
                destroy();
                if (cb)
                    cb(code, err, out, missing);
            }
            onStarted: didStart = true
            onExited: function (exitCode, exitStatus) {
                finish(exitCode, errText, outText, false);
            }
            onRunningChanged: {
                if (running || didStart)
                    return;
                // Leave the signal handler before destroying this object.
                var name = command.length > 0 ? command[0] : "command";
                Qt.callLater(function () {
                    proc.finish(-1, name + " is not installed", "", true);
                });
            }
        }
    }

    function runCmd(argv, onDone) {
        var p = cmdComponent.createObject(svc, {
            command: argv,
            onDone: onDone
        });
        p.running = true;
    }

    function driveByPath(path) {
        for (var i = 0; i < svc.drives.length; i++) {
            if (svc.drives[i].path === path)
                return svc.drives[i];
        }
        return null;
    }

    // Fire a desktop notification so an action's result is visible even if
    // the panel isn't open. Best-effort: failures here never set lastError.
    function notify(title, body, urgent) {
        var argv = ["notify-send", "-a", "Removable Drives"];
        if (urgent)
            argv.push("-u", "critical");
        argv.push(title, body);
        runCmd(argv, null);
    }

    function childrenOf(path) {
        var out = [];
        for (var i = 0; i < svc.drives.length; i++) {
            if (svc.drives[i].parentPath === path)
                out.push(svc.drives[i]);
        }
        return out;
    }

    // An encrypted container is unlocked while lsblk still shows a `crypt`
    // mapping under it. Unmounting the filesystem inside does not remove that
    // node; only `udisksctl lock` does. Keyed on the mapping, not on the
    // container's FSTYPE: blkid says `crypto_LUKS` or `BitLocker`, and
    // nothing at all for VeraCrypt/TrueCrypt, yet every dm-crypt mapping is
    // TYPE `crypt`. A `crypt` node is never a container itself: in a
    // VeraCrypt cipher cascade the stack is locked through the device under
    // it.
    function isUnlockedContainer(d) {
        if (!d || d.type === "crypt")
            return false;
        return svc.cryptChildPath(d.path) !== "";
    }

    // The open crypt mapping directly under a container ("" if locked).
    function cryptChildPath(containerPath) {
        var kids = svc.childrenOf(containerPath);
        for (var i = 0; i < kids.length; i++) {
            if (kids[i].type === "crypt")
                return kids[i].path;
        }
        return "";
    }

    // The container a filesystem lives in, at any depth: find the nearest
    // `crypt` mapping at or above it (an LVM volume or a partition can sit
    // on the mapping), then climb through any stacked mappings (a VeraCrypt
    // cascade) to the real device underneath. Returns "" for a filesystem
    // that is not inside an encrypted mapping.
    function containerOf(d) {
        var cur = d;
        while (cur && cur.type !== "crypt")
            cur = svc.driveByPath(cur.parentPath);
        while (cur && cur.type === "crypt")
            cur = svc.driveByPath(cur.parentPath);
        return svc.isUnlockedContainer(cur) ? cur.path : "";
    }

    // The top-level disk a device belongs to.
    function topDiskOf(d) {
        var cur = d;
        while (cur && cur.parentPath) {
            var up = svc.driveByPath(cur.parentPath);
            if (!up)
                break;
            cur = up;
        }
        return cur ? cur.path : "";
    }

    // What on the same disk as `d` is still open once `d` is unmounted and
    // `lockedPath` (if any) is locked: "" when the drive can be pulled, or
    // a sentence naming what remains. Computed from the drive list before
    // the action runs, so the paths being acted on are skipped explicitly.
    function stillOpenOnDisk(d, lockedPath) {
        var disk = svc.topDiskOf(d);
        var mounted = [];
        var unlocked = [];
        for (var i = 0; i < svc.drives.length; i++) {
            var x = svc.drives[i];
            if (x.path === d.path || svc.topDiskOf(x) !== disk)
                continue;
            if (x.mountpoint !== "")
                mounted.push(x.path);
            else if (x.path !== lockedPath && svc.isUnlockedContainer(x))
                unlocked.push(x.path);
        }
        var parts = [];
        if (mounted.length > 0)
            parts.push(mounted.join(", ") + (mounted.length > 1 ? " are" : " is") + " still mounted");
        if (unlocked.length > 0)
            parts.push(unlocked.join(", ") + (unlocked.length > 1 ? " are" : " is") + " still unlocked");
        return parts.join(" and ");
    }

    // Why a container stays unlocked after a volume nested inside its
    // mapping is unmounted.
    function whyStillUnlocked(containerPath) {
        if (svc.lvmVolumesOn(containerPath).length > 0)
            return "its LVM volumes are still active. To lock it, deactivate their volume group as root (vgchange -an <group>), then use Eject.";
        return "other volumes inside it keep it open. Use Eject to lock it and power the drive off.";
    }

    // Ask lsof which processes keep `target` (a mountpoint or a device node)
    // open: cb(holders, hint). holders is a short "name (pid), ..." line, or
    // "" when none are visible (lsof only sees this user's processes). hint
    // is set when lsof itself is missing, so the user knows how to get the
    // holder names next time.
    function findHolders(target, cb) {
        if (!target) {
            cb("", "");
            return;
        }
        runCmd(["lsof", "-w", "-F", "pc", "--", target], function (code, err, out, missing) {
            if (missing) {
                cb("", "Install lsof to see which program is using it.");
                return;
            }
            var seen = {};
            var list = [];
            var pid = "";
            var lines = (out || "").split("\n");
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i];
                if (l.charAt(0) === "p") {
                    pid = l.substring(1);
                } else if (l.charAt(0) === "c" && pid !== "" && !seen[pid]) {
                    seen[pid] = true;
                    list.push(l.substring(1) + " (" + pid + ")");
                }
            }
            var maxShown = 6;
            var text = list.slice(0, maxShown).join(", ");
            if (list.length > maxShown)
                text += ", +" + (list.length - maxShown) + " more";
            cb(text, "");
        });
    }

    // Turn the udisks refusals a user can act on into plain words; "" for
    // anything else, which is then shown as udisks printed it.
    //  - NotAuthorized*: polkit refused. udisks lets a user lock/unmount
    //    without a password only what that user unlocked/mounted through
    //    udisks; a container opened by another user, crypttab or
    //    `cryptsetup open` needs `encrypted-lock-others` (admin).
    //  - "is not an encrypted device": udisks does not manage the container
    //    at all, typically a volume mounted with the VeraCrypt app.
    function explainUdisksError(verb, err) {
        var e = err || "";
        if (e.indexOf("NotAuthorizedDismissed") !== -1)
            return "The password prompt was cancelled.";
        if (e.indexOf("NotAuthorized") !== -1) {
            if (verb === "lock")
                return "This volume was unlocked outside your session (by another user, the system's crypttab, or cryptsetup), so locking it needs an administrator password.";
            return "It was mounted by another user or by the system (e.g. through fstab), so this needs an administrator password.";
        }
        if (e.indexOf("is not an encrypted device") !== -1)
            return "It was opened by another tool (such as the VeraCrypt app or cryptsetup) that udisks does not manage. Close it in that tool, then eject again.";
        return "";
    }

    // LVM logical volumes stacked on a container's decrypted mapping. While
    // active they hold the mapping open from inside the kernel, so a lock is
    // refused and lsof has no process to name. udisksctl cannot deactivate
    // a volume group, so the plugin only explains this.
    function lvmVolumesOn(containerPath) {
        var names = [];
        var mapping = svc.cryptChildPath(containerPath);
        if (mapping === "")
            return names;
        var kids = svc.childrenOf(mapping);
        for (var i = 0; i < kids.length; i++) {
            if (kids[i].type === "lvm")
                names.push(kids[i].name);
        }
        return names;
    }

    function explainLvm(verb, path) {
        if (verb !== "lock")
            return "";
        var names = svc.lvmVolumesOn(path);
        if (names.length === 0)
            return "";
        return "It holds LVM volumes that are still active (" + names.join(", ") + "). Deactivate their volume group first, as root (vgchange -an <group>), then eject again.";
    }

    function publishError(title, verb, path, why) {
        svc.lastError = "Could not " + verb + " " + path + (why ? ": " + why.replace(/\n/g, " ") : "");
        svc.notify(title, "Could not " + verb + " " + path + (why ? "\n" + why : ""), true);
    }

    // Report a refused unmount/lock/power-off: name the holding processes
    // when lsof can see them, so a user knows what to close instead of
    // guessing. `missing` means udisksctl itself is not installed, so
    // there is nothing to look up.
    function reportBusy(title, verb, path, holderTarget, err, missing, after) {
        if (missing) {
            svc.publishError(title, verb, path, err);
            after();
            return;
        }
        // A permission or ownership refusal, or a kernel holder such as an
        // active LVM volume, is not about open files; asking lsof would
        // only add noise.
        var explained = svc.explainUdisksError(verb, err);
        if (explained === "")
            explained = svc.explainLvm(verb, path);
        if (explained !== "") {
            svc.publishError(title, verb, path, explained);
            after();
            return;
        }
        svc.findHolders(holderTarget, function (holders, hint) {
            var why = holders !== "" ? "In use by: " + holders : (err ? err.trim() : "");
            if (holders === "" && hint)
                why += (why ? "\n" : "") + hint;
            svc.publishError(title, verb, path, why);
            after();
        });
    }

    function failAction(title, verb, path, holderTarget, err, missing) {
        svc.reportBusy(title, verb, path, holderTarget, err, missing, function () {
            svc.busy = false;
            svc.lastAction = "";
            svc.refresh();
        });
    }

    function unmountOne(path) {
        var drive = svc.driveByPath(path);
        if (svc.busy || !drive || !drive.removable || drive.mountpoint === "")
            return;
        // A filesystem directly on an unlocked encrypted mapping: lock the
        // container once the filesystem is unmounted, so "Unmount" really
        // leaves it safe and does not hide a still-decrypted volume. One
        // nested deeper (an LVM volume, a partition inside the mapping)
        // shares the mapping with its siblings, so a lock would only be
        // refused; say the container is still unlocked instead.
        var containerPath = svc.containerOf(drive);
        var lockIt = containerPath !== "" && drive.type === "crypt";
        var nested = containerPath !== "" && !lockIt;
        var leftOpen = svc.stillOpenOnDisk(drive, lockIt ? containerPath : "");
        var useEject = leftOpen !== "" ? " " + leftOpen + "; use Eject before removing the drive." : "";
        var mountpoint = drive.mountpoint;
        svc.busy = true;
        svc.lastError = "";
        svc.lastAction = "Unmounting " + path;
        runCmd(["udisksctl", "unmount", "-b", path], function (code, err, out, missing) {
            if (code !== 0) {
                svc.failAction("Unmount failed", "unmount", path, mountpoint, err, missing);
                return;
            }
            if (!lockIt) {
                svc.busy = false;
                svc.lastAction = "";
                if (nested)
                    svc.notify("Unmounted", path + " is unmounted, but " + containerPath + " is still unlocked: " + svc.whyStillUnlocked(containerPath));
                else if (leftOpen !== "")
                    svc.notify("Unmounted", path + " is unmounted." + useEject);
                else
                    svc.notify("Unmounted", path + " can be removed.");
                svc.refresh();
                return;
            }
            svc.lastAction = "Locking " + containerPath;
            runCmd(["udisksctl", "lock", "-b", containerPath], function (lcode, lerr, lout, lmissing) {
                if (lcode !== 0) {
                    svc.failAction("Lock failed", "lock", containerPath, path, lerr, lmissing);
                    return;
                }
                svc.busy = false;
                svc.lastAction = "";
                if (leftOpen !== "")
                    svc.notify("Unmounted and locked", containerPath + " is locked." + useEject);
                else
                    svc.notify("Unmounted and locked", containerPath + " is locked and can be removed.");
                svc.refresh();
            });
        });
    }

    // Run `udisksctl <verb> -b <path>` over each step in order, stopping at
    // the first failure: done(code, failedStep, err, missing). A step is
    // { path, holder } where holder is what lsof checks if it is refused.
    function udisksSequence(verb, steps, idx, done) {
        if (idx >= steps.length) {
            done(0, null, "", false);
            return;
        }
        runCmd(["udisksctl", verb, "-b", steps[idx].path], function (code, err, out, missing) {
            if (code !== 0) {
                done(code, steps[idx], err, missing);
                return;
            }
            svc.udisksSequence(verb, steps, idx + 1, done);
        });
    }

    // Every mounted filesystem anywhere below a disk, at any depth -- not
    // just its direct partitions. Needed for e.g. a LUKS-unlocked mapper
    // device nested under a partition, which lsblk reports as a grandchild.
    function descendantPaths(rootPath) {
        var frontier = [rootPath];
        var out = [];
        while (frontier.length > 0) {
            var next = [];
            for (var i = 0; i < svc.drives.length; i++) {
                var d = svc.drives[i];
                if (frontier.indexOf(d.parentPath) !== -1) {
                    out.push(d);
                    next.push(d.path);
                }
            }
            frontier = next;
        }
        return out;
    }

    function ejectDisk(diskPath) {
        var disk = svc.driveByPath(diskPath);
        if (svc.busy || !disk || !disk.removable || disk.type !== "disk")
            return;
        // Deepest first, so a filesystem goes before the container it
        // lives in. Both lists are captured now: unmounting does not remove
        // the crypt node, so the container list is still right afterwards,
        // and it also covers a container whose filesystem was unmounted by
        // hand while its mapping was left open.
        var descendants = svc.descendantPaths(diskPath);
        var ordered = descendants.slice().reverse();
        ordered.push(disk);
        var mounts = [];
        var locks = [];
        for (var i = 0; i < ordered.length; i++) {
            var d = ordered[i];
            if (d.mountpoint !== "")
                mounts.push({ path: d.path, holder: d.mountpoint });
            if (svc.isUnlockedContainer(d))
                locks.push({ path: d.path, holder: svc.cryptChildPath(d.path) });
        }
        svc.busy = true;
        svc.lastError = "";
        svc.lastAction = "Ejecting " + diskPath;
        svc.udisksSequence("unmount", mounts, 0, function (code, failed, err, missing) {
            if (code !== 0) {
                svc.failAction("Eject stopped", "unmount", failed.path, failed.holder, err, missing);
                return;
            }
            if (locks.length > 0)
                svc.lastAction = "Locking encrypted volumes on " + diskPath;
            svc.udisksSequence("lock", locks, 0, function (lcode, lfailed, lerr, lmissing) {
                if (lcode !== 0) {
                    svc.failAction("Eject stopped", "lock", lfailed.path, lfailed.holder, lerr, lmissing);
                    return;
                }
                svc.lastAction = "Ejecting " + diskPath;
                settleTimer.diskPath = diskPath;
                settleTimer.restart();
            });
        });
    }

    Timer {
        id: settleTimer
        property string diskPath: ""
        interval: 400
        repeat: false
        onTriggered: {
            var path = diskPath;
            svc.runCmd(["udisksctl", "power-off", "-b", path], function (code, err, out, missing) {
                if (code !== 0) {
                    svc.failAction("Eject failed", "power off", path, path, err, missing);
                    return;
                }
                svc.busy = false;
                svc.lastAction = "";
                svc.notify("Safe to remove", path + " was ejected.");
                svc.refresh();
            });
        }
    }
}
