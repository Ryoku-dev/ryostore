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
// user's own mounts -- no sudo/pkexec needed here.
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
    property string lastAction: ""

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
        lsblkProc.running = true;
    }

    Process {
        id: lsblkProc
        command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,TRAN,RM,HOTPLUG,MOUNTPOINT,SIZE,FSTYPE,LABEL,TYPE,MODEL"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    var out = [];
                    var devices = data.blockdevices || [];
                    for (var i = 0; i < devices.length; i++)
                        svc.flatten(devices[i], "", false, out);
                    svc.drives = out;
                    svc.lastError = "";
                } catch (e) {
                    svc.lastError = "Could not read drives: " + e;
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

    // One-shot command runner: fire-and-forget argv, call onDone(exitCode) when
    // it exits, then destroy itself. Never built from an interpolated string
    // (R9) -- argv arrays only.
    Component {
        id: cmdComponent
        Process {
            property var onDone: null
            property string errText: ""
            stdout: StdioCollector {}
            stderr: StdioCollector {
                onStreamFinished: parent.errText = text
            }
            onExited: function (exitCode, exitStatus) {
                var cb = onDone;
                var err = errText;
                destroy();
                if (cb)
                    cb(exitCode, err);
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

    // Fire a desktop notification so an action's result is visible even if
    // the panel isn't open. Best-effort: failures here never set lastError.
    function notify(title, body, urgent) {
        var argv = ["notify-send", "-a", "Removable Drives"];
        if (urgent)
            argv.push("-u", "critical");
        argv.push(title, body);
        runCmd(argv, null);
    }

    function unmountOne(path, after) {
        svc.lastError = "";
        svc.lastAction = "Unmounting " + path;
        runCmd(["udisksctl", "unmount", "-b", path], function (code, err) {
            svc.lastAction = "";
            if (code !== 0) {
                svc.lastError = "Could not unmount " + path + (err ? ": " + err : "");
                svc.notify("Unmount failed", path + (err ? "\n" + err : ""), true);
            } else {
                svc.notify("Unmounted", path + " can be removed.");
            }
            svc.refresh();
            if (after)
                after(code);
        });
    }

    function unmountSequence(paths, idx, done) {
        if (idx >= paths.length) {
            done();
            return;
        }
        runCmd(["udisksctl", "unmount", "-b", paths[idx]], function (code, err) {
            if (code !== 0)
                svc.lastError = "Could not unmount " + paths[idx] + (err ? ": " + err : "");
            svc.unmountSequence(paths, idx + 1, done);
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

    // Unmount every mounted filesystem on a disk (at any depth), then power
    // it off so it is safe to physically unplug. A short settle delay before
    // power-off avoids a spurious "device busy" right after udisks finishes
    // an unmount.
    function ejectDisk(diskPath) {
        var descendants = svc.descendantPaths(diskPath);
        var parts = [];
        for (var i = 0; i < descendants.length; i++) {
            if (descendants[i].mountpoint !== "")
                parts.push(descendants[i].path);
        }
        svc.lastError = "";
        svc.lastAction = "Ejecting " + diskPath;
        svc.unmountSequence(parts, 0, function () {
            settleTimer.diskPath = diskPath;
            settleTimer.restart();
        });
    }

    Timer {
        id: settleTimer
        property string diskPath: ""
        interval: 400
        repeat: false
        onTriggered: {
            runCmd(["udisksctl", "power-off", "-b", diskPath], function (code, err) {
                svc.lastAction = "";
                if (code !== 0) {
                    svc.lastError = "Could not power off " + diskPath + (err ? ": " + err : "");
                    svc.notify("Eject failed", diskPath + (err ? "\n" + err : ""), true);
                } else {
                    svc.notify("Safe to remove", diskPath + " was ejected.");
                }
                svc.refresh();
            });
        }
    }
}
