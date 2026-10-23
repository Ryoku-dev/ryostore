pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Logic only. Holds the six session actions with the arm-then-confirm flow and
// the per-action visibility settings (same behavior as power-menu V1), plus the
// read-only profile data the panel shows: name and hero image from the Hub's
// ~/.config/ryoku/profile.json, the installed Ryoku version, the hostname and
// the uptime. Nothing here writes anywhere.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    readonly property bool confirm: settings && settings.confirm !== undefined ? settings.confirm : true

    // Display order follows the YASB menu. Glyphs are Material Design icons from
    // JetBrainsMono Nerd Font (Theme.mono), the same codepoints as the YASB config.
    readonly property var actions: [
        { id: "lock",      label: "Lock",      glyph: 0xF0341, needsConfirm: false },
        { id: "logout",    label: "Log out",   glyph: 0xF0343, needsConfirm: true  },
        { id: "suspend",   label: "Suspend",   glyph: 0xF0904, needsConfirm: true  },
        { id: "hibernate", label: "Hibernate", glyph: 0xF0901, needsConfirm: true  },
        { id: "reboot",    label: "Reboot",    glyph: 0xF0453, needsConfirm: true  },
        { id: "poweroff",  label: "Power off", glyph: 0xF0906, needsConfirm: true  }
    ]

    // id of the action waiting for its confirming second click, or "".
    property string armed: ""

    function enabled(id) {
        var key = "show_" + id;
        return settings && settings[key] !== undefined ? settings[key] : true;
    }

    function argvFor(id) {
        switch (id) {
        case "logout":    return ["hyprctl", "dispatch", "hl.dsp.exit()"];
        case "lock":      return ["ryoku-shell", "lock"];
        case "suspend":   return ["ryoku-shell", "suspend"];
        case "hibernate": return [svc.pluginApi.pluginDir + "/bin/hibernate.sh"];
        case "reboot":    return ["systemctl", "reboot"];
        case "poweroff":  return ["systemctl", "poweroff"];
        }
        return [];
    }

    function run(id) {
        var needs = false;
        for (var i = 0; i < actions.length; i++) {
            if (actions[i].id === id)
                needs = actions[i].needsConfirm;
        }
        if (svc.confirm && needs && svc.armed !== id) {
            svc.armed = id;
            disarm.restart();
            return;
        }
        svc.armed = "";
        disarm.stop();
        var argv = svc.argvFor(id);
        if (argv.length > 0)
            Quickshell.execDetached(argv);
        if (svc.pluginApi)
            svc.pluginApi.closePanel();
    }

    function openSettings() {
        Quickshell.execDetached(["ryoku-shell", "hub", "open"]);
        if (svc.pluginApi)
            svc.pluginApi.closePanel();
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: svc.armed = ""
    }

    // ── profile data (read-only) ─────────────────────────────────────────────

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (svc.home + "/.config")
    readonly property string userName: Quickshell.env("USER") || ""

    property string displayName: ""
    property string heroKind: "default"
    property string heroSource: ""
    property real focalX: 0.5
    property real focalY: 0.5
    property real zoom: 1
    property string version: ""
    property string hostName: ""
    property real uptimeSecs: 0

    readonly property string name: svc.displayName !== "" ? svc.displayName : svc.userName

    // Same source rules as the Hub's Profile page (hero.kind).
    readonly property string avatarPath: {
        if (svc.heroKind === "gallery")
            return svc.heroSource !== "" ? svc.home + "/Pictures/ryodecors/" + svc.heroSource : "";
        if (svc.heroKind === "custom") {
            if (svc.heroSource.indexOf("~/") === 0)
                return svc.home + svc.heroSource.slice(1);
            if (svc.heroSource.indexOf("/") === 0)
                return svc.heroSource;
            return "";
        }
        return svc.configHome + "/quickshell/hub/art/profile-hero.png";
    }

    readonly property string subtitle: {
        var parts = [];
        if (svc.hostName !== "")
            parts.push("@" + svc.hostName);
        if (svc.uptimeSecs > 0)
            parts.push("up " + svc.formatUptime(svc.uptimeSecs));
        return parts.join(" \u00B7 ");
    }

    function formatUptime(sec) {
        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return d + "d " + h + "h";
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    function num(v, fallback) {
        return typeof v === "number" && isFinite(v) ? v : fallback;
    }

    function parseProfile(raw) {
        var o = null;
        try {
            o = raw && raw.length ? JSON.parse(raw) : null;
        } catch (e) {
            o = null;
        }
        var hero = o && o.hero ? o.hero : {};
        svc.displayName = o && o.text && typeof o.text.name === "string" ? o.text.name : "";
        svc.heroKind = typeof hero.kind === "string" ? hero.kind : "default";
        svc.heroSource = typeof hero.source === "string" ? hero.source : "";
        svc.focalX = Math.max(0, Math.min(1, svc.num(hero.focalX, 0.5)));
        svc.focalY = Math.max(0, Math.min(1, svc.num(hero.focalY, 0.5)));
        svc.zoom = Math.max(1, svc.num(hero.zoom, 1));
    }

    // "ryoku 0.75.3.r3968.gcfd8899-1" -> "0.75.3"
    function parseVersion(raw) {
        var fields = String(raw || "").trim().split(/\s+/);
        if (fields.length < 2) {
            svc.version = "";
            return;
        }
        var m = fields[1].match(/^\d+(\.\d+)*/);
        var v = m ? m[0] : fields[1];
        var parts = v.split(".");
        svc.version = parts.length > 3 ? parts.slice(0, 3).join(".") : v;
    }

    // Called when the panel opens; cheap, one-shot reads.
    function refresh() {
        profileFile.reload();
        if (svc.version === "" && !versionProc.running)
            versionProc.running = true;
        if (svc.hostName === "" && !hostProc.running)
            hostProc.running = true;
        if (!uptimeProc.running)
            uptimeProc.running = true;
    }

    FileView {
        id: profileFile
        path: svc.configHome + "/ryoku/profile.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: svc.parseProfile(text())
        onLoadFailed: svc.parseProfile("")
    }

    Process {
        id: versionProc
        command: ["pacman", "-Q", "ryoku"]
        stdout: StdioCollector {
            onStreamFinished: svc.parseVersion(text)
        }
    }

    Process {
        id: hostProc
        command: ["uname", "-n"]
        stdout: StdioCollector {
            onStreamFinished: svc.hostName = String(text || "").trim()
        }
    }

    Process {
        id: uptimeProc
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                var secs = parseFloat(String(text || "").trim().split(/\s+/)[0]);
                svc.uptimeSecs = isFinite(secs) ? secs : 0;
            }
        }
    }

    Component.onCompleted: svc.refresh()
}
