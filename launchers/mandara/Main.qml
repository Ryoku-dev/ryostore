import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import shell.services
import Ryoku.Ui.Singletons

// Mandara — the Jurai suite's launcher. Summon, type, run.
//
// One mouth, four lanes: APPS · COMMAND · ACTIONS · FILES. In free
// mode the query routes itself (apps first, then actions, then a
// command when nothing answers; ">" forces a command, a path shape
// opens the files). TAB locks a lane — the lock crystallizes as a
// rune chip above the field, in the shape of the Obelisk's rune
// tokens from Jurai shell — and Backspace on an empty field
// releases it. What the locked segments will one day compose is
// theirs to become; in v1 the chip locks a lane, and a lane is
// enough.
//
// No core, no court, no ceremony between the keystroke and the
// thing running. Beautiful, accessible, very functional — that is
// the whole job, done well.
Scope {
    id: root

    // ── the contract the shell's launcher host drives ───────────────
    property bool openRequested: false
    readonly property bool shown: root.openRequested
    property string monitor: ""

    function show(mon) {
        root.monitor = mon || "";
        root.query = "";
        root.lockedLane = -1;
        root.selected = 0;
        root.openRequested = true;
    }
    function hide() {
        root.openRequested = false;
    }
    function toggle(mon) {
        root.openRequested ? root.hide() : root.show(mon);
    }
    function stateDump() {
        return {
            open: root.openRequested,
            query: root.query,
            lane: root.effectiveLane,
            lockedLane: root.lockedLane,
            resultCount: root.results.length
        };
    }

    // ── lanes ────────────────────────────────────────────────────────
    readonly property var lanes: [
        { id: "apps",    label: "APPS",    icon: "◈", color: "#22D3EE", hint: "APP" },
        { id: "command", label: "COMMAND", icon: "›", color: "#A78BFA", hint: "COMMAND" },
        { id: "actions", label: "ACTIONS", icon: "✦", color: "#F5B300", hint: "ACTION" },
        { id: "files",   label: "FILES",   icon: "⌂", color: "#4ADE80", hint: "FILE" }
    ]
    // -1 = free (the query routes itself); 0..3 = a locked lane (a chip)
    property int lockedLane: -1

    property string query: ""
    property int selected: 0

    // the query with any lane prefix stripped (">" in free mode)
    readonly property string body: {
        var q = root.query;
        if (root.lockedLane < 0 && q.startsWith(">"))
            return q.slice(1).trim();
        return q.trim();
    }

    // where the query is being answered from, right now
    readonly property string effectiveLane: {
        if (root.lockedLane >= 0)
            return root.lanes[root.lockedLane].id;
        var q = root.query.trim();
        if (q.startsWith(">"))
            return "command";
        if (q.startsWith("/") || q.startsWith("~/"))
            return "files";
        return "apps";
    }

    // ── matching ─────────────────────────────────────────────────────
    // subsequence fuzzy score: starts-with beats word-start beats
    // subsequence; -1 is no match. Small, honest, fast enough.
    function _score(name, q) {
        if (q.length === 0)
            return 0;
        var n = name.toLowerCase();
        var s = q.toLowerCase();
        if (n.startsWith(s))
            return 1000 - n.length;
        var words = n.split(/[\s\-_]+/);
        for (var w = 0; w < words.length; w++)
            if (words[w].startsWith(s))
                return 600 - n.length;
        var ni = 0;
        for (var si = 0; si < s.length; si++) {
            ni = n.indexOf(s[si], ni);
            if (ni < 0)
                return -1;
            ni++;
        }
        return 200 - n.length;
    }

    readonly property var _actions: [
        { name: "Lock screen", keys: ["lock", "lock screen", "secure"],
          act: "lock" },
        { name: "Screenshot", keys: ["screenshot", "screen shot", "capture", "snap"],
          cmd: ["sh", "-c", "grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"] },
        { name: "Sleep", keys: ["sleep", "suspend"],
          act: "suspend" }
    ]

    // ── file lane state (async: ls / find through a Process) ────────
    property var _fileRows: []
    property int _fileGen: 0

    function _refreshFiles() {
        var gen = ++root._fileGen;
        var q = root.body;
        var home = Quickshell.env("HOME") || "";
        var cmd;
        if (q.startsWith("/") || q.startsWith("~/") || q.indexOf("/") >= 0) {
            var path = q.startsWith("~/") ? home + q.slice(1) : q;
            var slash = path.lastIndexOf("/");
            var dir = slash >= 0 ? path.slice(0, slash + 1) : "/";
            root._fileDir = dir;
            cmd = ["ls", "-1p", dir];
        } else {
            root._fileDir = "";
            if (q.length === 0) {
                root._fileRows = [];
                return;
            }
            cmd = ["find", home, "-maxdepth", "3", "-iname", "*" + q + "*",
                   "-not", "-path", "*/.*", "-printf", "%y %p\\n"];
        }
        fileProc.command = cmd;
        fileProc.running = true;
    }
    property string _fileDir: ""

    function _filesDone(text) {
        var q = root.body;
        var tail = q;
        if (root._fileDir.length > 0) {
            var path = q.startsWith("~/")
                ? (Quickshell.env("HOME") || "") + q.slice(1) : q;
            tail = path.slice(root._fileDir.length);
        }
        var rows = [];
        var lines = text.split("\n");
        for (var i = 0; i < lines.length && rows.length < 40; i++) {
            var line = lines[i].trim();
            if (line.length === 0)
                continue;
            var full, name, isDir = false;
            if (root._fileDir.length > 0) {
                // ls -1p: a trailing "/" marks a directory
                isDir = line.endsWith("/");
                name = isDir ? line.slice(0, -1) : line;
                full = root._fileDir + name;
                if (tail.length > 0
                        && name.toLowerCase().indexOf(tail.toLowerCase()) < 0)
                    continue;
            } else {
                // find -printf "%y %p": first char is the type
                isDir = line.startsWith("d ");
                full = line.slice(2);
                name = full.split("/").pop();
            }
            rows.push({ kind: "file", name: name, path: full, isDir: isDir,
                        hint: isDir ? "FOLDER" : "FILE" });
        }
        root._fileRows = rows;
        root.selected = Math.min(root.selected, Math.max(0, rows.length - 1));
    }

    Process {
        id: fileProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._filesDone(text)
        }
    }

    onBodyChanged: {
        if (root.effectiveLane === "files")
            root._refreshFiles();
    }
    onLockedLaneChanged: {
        if (root.effectiveLane === "files")
            root._refreshFiles();
    }

    // ── results ──────────────────────────────────────────────────────
    readonly property var results: {
        var lane = root.effectiveLane;
        var q = root.body;
        var out = [];
        if (lane === "files")
            return root._fileRows;
        if (lane === "command") {
            if (q.length > 0)
                out.push({ kind: "command", name: "Run  " + q, cmd: q, hint: "COMMAND" });
            return out;
        }
        if (lane === "apps" || lane === "actions") {
            if (lane === "apps") {
                var scored = [];
                var apps = DesktopEntries.applications.values;
                for (var i = 0; i < apps.length; i++) {
                    var e = apps[i];
                    if (e.noDisplay)
                        continue;
                    var sc = root._score(e.name, q);
                    if (sc >= 0)
                        scored.push({ entry: e, score: sc });
                }
                scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
                for (var j = 0; j < scored.length && out.length < 8; j++)
                    out.push({ kind: "app", name: scored[j].entry.name,
                               entry: scored[j].entry, hint: "APP" });
            }
            if (lane === "actions" || root.lockedLane < 0) {
                for (var k = 0; k < root._actions.length; k++) {
                    var a = root._actions[k];
                    var hit = q.length === 0;
                    for (var m = 0; m < a.keys.length && !hit; m++)
                        hit = a.keys[m].indexOf(q.toLowerCase()) >= 0
                            || root._score(a.keys[m], q) >= 0;
                    if (hit && out.length < 8)
                        out.push({ kind: "action", name: a.name, cmd: a.cmd, hint: "ACTION" });
                }
            }
            if (lane === "apps" && root.lockedLane < 0 && q.length > 0 && out.length === 0)
                out.push({ kind: "command", name: "Run  " + q, cmd: q, hint: "COMMAND" });
            return out;
        }
        return out;
    }

    // ── running things ───────────────────────────────────────────────
    function runRow(row) {
        if (!row)
            return;
        if (row.kind === "file" && row.isDir) {
            // descend: the folder becomes the query, she stays open
            root.query = row.path + "/";
            root.selected = 0;
            return;
        }
        root.hide();
        if (row.kind === "app")
            AppLaunch.run(row.entry, null);
        else if (row.kind === "command")
            Quickshell.execDetached(["sh", "-c", row.cmd]);
        else if (row.kind === "action") {
            if (row.act)
                SessionActions.run(row.act);
            else
                Quickshell.execDetached(row.cmd);
        }
        else if (row.kind === "file")
            Quickshell.execDetached(["xdg-open", row.path]);
    }

    function cycleLane() {
        // free -> APPS -> COMMAND -> ACTIONS -> FILES -> free
        root.lockedLane = root.lockedLane >= 3 ? -1 : root.lockedLane + 1;
        root.selected = 0;
    }

    // the output the host named, else the focused one
    readonly property var output: {
        const screens = Quickshell.screens;
        const wanted = root.monitor.length > 0 ? root.monitor : Wm.focusedOutput;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === wanted)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    LazyLoader {
        active: root.shown && root.output !== null

        PanelWindow {
            screen: root.output
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "launcher"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }

            // ── the plate: centred, one dark-glass slab ──────────────
            Rectangle {
                id: plate
                width: Tokens.px(600)
                height: plateCol.implicitHeight + Tokens.s4 * 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(Tokens.s4, Math.round((parent.height - height) * 0.30))
                radius: Tokens.radius
                color: Tokens.paperLift
                border.width: Tokens.border
                border.color: Tokens.lineStrong

                MouseArea {
                    anchors.fill: parent
                }

                // her mark, ghosted behind the plate's face
                Text {
                    anchors { right: parent.right; rightMargin: Tokens.s3
                              bottom: parent.bottom; bottomMargin: -Tokens.s4 }
                    text: "曼"
                    font.pixelSize: Tokens.px(120)
                    color: Tokens.ink
                    opacity: 0.05
                }

                Column {
                    id: plateCol
                    anchors { left: parent.left; right: parent.right
                              top: parent.top; margins: Tokens.s4 }
                    spacing: Tokens.s2

                    // the locked segment, crystallized
                    Row {
                        visible: root.lockedLane >= 0
                        spacing: Tokens.s2

                        RuneChip {
                            laneData: root.lockedLane >= 0
                                ? root.lanes[root.lockedLane]
                                : { label: "", icon: "◈", color: "#22D3EE" }
                            isLast: true
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TAB cycles · ⌫ releases"
                            color: Tokens.inkFaint
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                        }
                    }

                    TextInput {
                        id: field
                        width: parent.width
                        focus: true
                        color: Tokens.ink
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fValue
                        Component.onCompleted: field.forceActiveFocus()
                        onTextEdited: {
                            root.query = text;
                            root.selected = 0;
                        }
                        Keys.onTabPressed: root.cycleLane()
                        Keys.onEscapePressed: {
                            if (field.text.length > 0) {
                                field.text = "";
                                root.query = "";
                                root.selected = 0;
                            } else if (root.lockedLane >= 0) {
                                root.lockedLane = -1;
                            } else {
                                root.hide();
                            }
                        }
                        Keys.onReturnPressed: root.runRow(root.results[root.selected])
                        Keys.onEnterPressed: root.runRow(root.results[root.selected])
                        Keys.onDownPressed: root.selected = Math.min(root.results.length - 1, root.selected + 1)
                        Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Backspace && field.text.length === 0
                                    && root.lockedLane >= 0) {
                                root.lockedLane = -1;
                                event.accepted = true;
                            }
                        }

                        Text {
                            visible: field.text.length === 0
                            text: I18n.tr("speak or command")
                            color: Tokens.inkFaint
                            font: field.font
                        }
                    }

                    // the beam: one prism rule under the input
                    Rectangle {
                        width: parent.width
                        height: 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#22D3EE" }
                            GradientStop { position: 1.0; color: "#A78BFA" }
                        }
                        opacity: 0.85
                    }

                    Repeater {
                        model: root.results
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            width: plateCol.width
                            height: Tokens.rowH
                            radius: Tokens.radius
                            color: row.index === root.selected ? Tokens.tint10 : "transparent"

                            // the selection's prism edge
                            Rectangle {
                                visible: row.index === root.selected
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: 2
                                color: "#22D3EE"
                            }

                            IconImage {
                                id: rowIcon
                                visible: row.modelData.kind === "app"
                                anchors { left: parent.left; leftMargin: Tokens.s3
                                          verticalCenter: parent.verticalCenter }
                                implicitSize: Tokens.px(24)
                                source: row.modelData.kind === "app"
                                    ? Icons.path(row.modelData.entry.icon, "application-x-executable")
                                    : ""
                            }
                            Text {
                                visible: row.modelData.kind !== "app"
                                anchors { left: parent.left; leftMargin: Tokens.s3
                                          verticalCenter: parent.verticalCenter }
                                width: Tokens.px(24)
                                horizontalAlignment: Text.AlignHCenter
                                text: row.modelData.kind === "command" ? "›"
                                    : row.modelData.kind === "action" ? "✦" : "⌂"
                                color: row.modelData.kind === "command" ? "#A78BFA"
                                     : row.modelData.kind === "action" ? "#F5B300" : "#4ADE80"
                                font.pixelSize: Tokens.fRow
                            }
                            Text {
                                anchors { left: rowIcon.right; leftMargin: Tokens.s3
                                          verticalCenter: parent.verticalCenter
                                          right: hintText.left; rightMargin: Tokens.s3 }
                                text: row.modelData.name
                                color: Tokens.ink
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fRow
                                elide: Text.ElideRight
                            }
                            Text {
                                id: hintText
                                anchors { right: parent.right; rightMargin: Tokens.s3
                                          verticalCenter: parent.verticalCenter }
                                text: row.modelData.hint || ""
                                color: Tokens.inkFaint
                                font.family: "monospace"
                                font.pixelSize: Tokens.fSmall
                                font.letterSpacing: 1
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runRow(row.modelData)
                                onPositionChanged: root.selected = row.index
                            }
                        }
                    }

                    Text {
                        visible: root.results.length === 0 && root.effectiveLane !== "files"
                        text: "nothing answers to that name"
                        color: Tokens.inkFaint
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall
                    }

                    // her name, lettered small at the foot
                    Item {
                        width: parent.width
                        height: Tokens.fSmall + 4
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: "M A N D A R A"
                            color: Tokens.inkFaint
                            font.family: "monospace"
                            font.pixelSize: Tokens.fSmall
                            opacity: 0.8
                        }
                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: root.lockedLane >= 0
                                ? root.lanes[root.lockedLane].label + " locked"
                                : "TAB locks a lane · > command · / file"
                            color: Tokens.inkFaint
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                        }
                    }
                }
            }
        }
    }
}
