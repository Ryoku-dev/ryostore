pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import shell.services
import Ryoku.Ui.Singletons

// Island: the Dynamic Island's launcher for Ryoku.
//
// Super+Space and a black pill drops from the top edge and stretches into a
// search field. Apps you open often float up; type sums for an answer you can
// copy; start with ">" to run a command (Ctrl+Enter runs it in a terminal).
Scope {
    id: root

    // ── the contract the shell's launcher host drives ──
    property bool open: false
    property bool closing: false
    readonly property bool shown: open || closing
    property string monitor: ""

    function show(mon) {
        root.monitor = mon || "";
        root.query = "";
        root.selected = 0;
        closeTimer.stop();
        root.closing = false;
        root.open = true;
    }
    function hide() {
        if (!root.open) return;
        root.open = false;
        root.closing = true;
        closeTimer.restart();
    }
    function toggle(mon) { root.open ? root.hide() : root.show(mon); }
    function stateDump() { return { open: root.open, query: root.query, results: root.rows.length }; }
    Timer { id: closeTimer; interval: Tokens.reduceMotion ? 1 : 260; onTriggered: root.closing = false }

    // ── usage history: apps you open often rank higher ──
    FileView {
        id: histFile
        path: Quickshell.statePath("island-launcher.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()
        JsonAdapter { id: hist; property var counts: ({}) }
    }
    function bump(id) {
        const c = Object.assign({}, hist.counts || {});
        c[id] = Math.min(999, (c[id] || 0) + 1);
        hist.counts = c;
    }

    // ── maths: a small shunting-yard evaluator, no eval ──
    function mathEval(src) {
        const toks = [];
        for (let i = 0; i < src.length;) {
            const c = src[i];
            if (c === " ") { i++; continue; }
            if (/[0-9.,]/.test(c)) {
                let j = i;
                while (j < src.length && /[0-9.,]/.test(src[j])) j++;
                // one well-formed number, or the whole sum is rejected ("1.2.3" is not 1.2)
                const num = src.slice(i, j).replace(/,/g, ".");
                if (!/^(?:\d+\.?\d*|\.\d+)$/.test(num)) return NaN;
                toks.push({ n: Number(num) });
                i = j;
                continue;
            }
            if ("+-*/%^()".indexOf(c) < 0) return NaN;
            toks.push({ o: c });
            i++;
        }
        // unary minus binds looser than ^, so -2^2 is -(2^2) = -4
        const prec = { "+": 1, "-": 1, "*": 2, "/": 2, "%": 2, "neg": 2.5, "^": 3 };
        const out = [], ops = [];
        let prev = null;
        for (const t of toks) {
            if (t.n !== undefined) { if (isNaN(t.n)) return NaN; out.push(t); }
            else if (t.o === "(") ops.push("(");
            else if (t.o === ")") {
                while (ops.length && ops[ops.length - 1] !== "(") out.push({ o: ops.pop() });
                if (!ops.length) return NaN;
                ops.pop();
            } else {
                let op = t.o;
                const unary = prev === null || (prev.o !== undefined && prev.o !== ")");
                if (unary && op === "+") { prev = t; continue; }
                if (unary && op === "-") op = "neg";
                while (ops.length && ops[ops.length - 1] !== "(" && op !== "neg"
                       && (prec[ops[ops.length - 1]] > prec[op] || (prec[ops[ops.length - 1]] === prec[op] && op !== "^")))
                    out.push({ o: ops.pop() });
                ops.push(op);
            }
            prev = t;
        }
        while (ops.length) { const o = ops.pop(); if (o === "(") return NaN; out.push({ o: o }); }
        const st = [];
        for (const t of out) {
            if (t.n !== undefined) { st.push(t.n); continue; }
            if (t.o === "neg") { if (!st.length) return NaN; st.push(-st.pop()); continue; }
            if (st.length < 2) return NaN;
            const b = st.pop(), a = st.pop();
            st.push(t.o === "+" ? a + b : t.o === "-" ? a - b : t.o === "*" ? a * b
                  : t.o === "/" ? a / b : t.o === "%" ? a % b : Math.pow(a, b));
        }
        return st.length === 1 ? st[0] : NaN;
    }

    // ── results ──
    property string query: ""
    property int selected: 0
    readonly property string q: query.trim()
    readonly property bool cmdMode: q.startsWith(">")
    readonly property string mathResult: {
        const s = cmdMode ? "" : q;
        if (s.length < 2 || !/^[0-9+\-*/().%^ ,]+$/.test(s) || !/[0-9]/.test(s) || !/[+\-*/%^]/.test(s)) return "";
        const v = mathEval(s);
        return typeof v === "number" && isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
    }
    function score(e, s) {
        const n = (e.name || "").toLowerCase();
        if (!s) return 1;
        if (n === s) return 1000;
        if (n.startsWith(s)) return 800;
        if (n.split(/[\s\-_.]+/).some(w => w.startsWith(s))) return 600;
        if (n.indexOf(s) >= 0) return 400;
        if ((e.genericName || "").toLowerCase().indexOf(s) >= 0) return 250;
        if ((e.keywords || []).some(k => String(k).toLowerCase().startsWith(s))) return 200;
        if ((e.comment || "").toLowerCase().indexOf(s) >= 0) return 60;
        let i = 0;
        for (let k = 0; k < n.length && i < s.length; k++) if (n[k] === s[i]) i++;
        return i === s.length && s.length >= 2 ? 40 : 0;
    }
    readonly property var rows: {
        const out = [];
        if (!open) return out;
        if (cmdMode) {
            const c = q.slice(1).trim();
            if (c !== "") out.push({ kind: "cmd", title: c, sub: "Run command  ·  Ctrl+Enter in a terminal", glyph: "›" });
            return out;
        }
        if (mathResult !== "") out.push({ kind: "math", title: "= " + mathResult, sub: "Enter copies the answer", glyph: "=" });
        const s = q.toLowerCase();
        const counts = hist.counts || {};
        const apps = DesktopEntries.applications.values;
        const scored = [];
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i];
            if (!e || e.noDisplay) continue;
            const sc = score(e, s);
            if (sc <= 0) continue;
            scored.push({ e: e, sc: sc + Math.min(counts[e.id] || 0, 40) * (s ? 6 : 25) });
        }
        scored.sort((a, b) => b.sc - a.sc || (a.e.name || "").localeCompare(b.e.name || ""));
        for (let i = 0; i < scored.length && i < 40; i++)
            out.push({ kind: "app", entry: scored[i].e, title: scored[i].e.name, sub: scored[i].e.genericName || scored[i].e.comment || "" });
        return out;
    }
    onRowsChanged: selected = Math.min(selected, Math.max(0, rows.length - 1))

    function activate(i, inTerminal) {
        const r = rows[i];
        if (!r) return;
        if (r.kind === "app") { bump(r.entry.id); AppLaunch.run(r.entry, null); }
        else if (r.kind === "cmd") {
            const argv = ["sh", "-c", r.title];
            Spawn.runApp(inTerminal ? ["ryoku-app", "terminal", "--"].concat(argv) : argv, { label: "island-launcher" });
        } else if (r.kind === "math") Quickshell.execDetached(["wl-copy", "--", mathResult]);
        root.hide();
    }

    readonly property var output: {
        const screens = Quickshell.screens;
        const wanted = root.monitor.length > 0 ? root.monitor : Wm.focusedOutput;
        for (let i = 0; i < screens.length; i++) if (screens[i].name === wanted) return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    LazyLoader {
        active: root.shown && root.output !== null

        PanelWindow {
            id: win
            screen: root.output
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "launcher"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors { top: true; bottom: true; left: true; right: true }

            MouseArea { anchors.fill: parent; onClicked: root.hide() }

            readonly property int maxRows: 7
            readonly property real rowH: 48 * Tokens.uiScale
            readonly property real headH: 60 * Tokens.uiScale
            readonly property real fullH: headH + (root.rows.length > 0 ? 8 + Math.min(root.rows.length, maxRows) * rowH + 10 : 34 * Tokens.uiScale)
            property real grow: 0
            Component.onCompleted: grow = 1
            Connections { target: root; function onOpenChanged() { win.grow = root.open ? 1 : 0; } }
            Behavior on grow {
                NumberAnimation {
                    duration: Tokens.reduceMotion ? 1 : (root.open ? 460 : 240)
                    easing.type: root.open ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 1.05
                }
            }

            Item {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8 * Tokens.uiScale
                width: 126 * Tokens.uiScale + (600 - 126) * Tokens.uiScale * win.grow
                height: 36 * Tokens.uiScale + (win.fullH - 36 * Tokens.uiScale) * win.grow
                Behavior on height { enabled: win.grow > 0.99; NumberAnimation { duration: Tokens.dur(160); easing.type: Easing.OutCubic } }

                // glass on this pill refracts the pill
                property var glassSource: null
                property Item glassSpace: null
                property color glassBase: "#000000"

                MouseArea { anchors.fill: parent }
                RectangularShadow {
                    anchors.fill: parent
                    radius: Math.min(28 * Tokens.uiScale, height / 2)
                    blur: 36
                    spread: -4
                    offset.y: 12
                    color: Qt.rgba(0, 0, 0, 0.55)
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: Math.min(28 * Tokens.uiScale, height / 2)
                    color: "#000000"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.07)

                    Item {
                        anchors.fill: parent
                        opacity: Math.max(0, (win.grow - 0.5) * 2)

                        Text {
                            id: glass
                            x: 22 * Tokens.uiScale
                            height: win.headH
                            verticalAlignment: Text.AlignVCenter
                            text: root.cmdMode ? "›" : "⌕"
                            color: root.cmdMode ? Tokens.sun : Qt.rgba(1, 1, 1, 0.55)
                            font.pixelSize: 22 * Tokens.uiScale
                        }
                        TextInput {
                            id: field
                            anchors.left: glass.right
                            anchors.leftMargin: 12 * Tokens.uiScale
                            anchors.right: parent.right
                            anchors.rightMargin: 20 * Tokens.uiScale
                            height: win.headH
                            verticalAlignment: TextInput.AlignVCenter
                            focus: true
                            color: "#ffffff"
                            selectionColor: Tokens.sun
                            font.family: Tokens.ui
                            font.pixelSize: 19 * Tokens.uiScale
                            font.weight: Font.Medium
                            Component.onCompleted: forceActiveFocus()
                            onTextEdited: { root.query = text; root.selected = 0; }
                            // reopening during the close animation keeps this field
                            // alive, so take show()'s reset and the focus back
                            Connections {
                                target: root
                                function onQueryChanged() { if (field.text !== root.query) field.text = root.query; }
                                function onOpenChanged() { if (root.open) field.forceActiveFocus(); }
                            }
                            Text {
                                visible: field.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Search apps, or > to run a command")
                                color: Qt.rgba(1, 1, 1, 0.32)
                                font: field.font
                            }
                            Keys.onPressed: e => {
                                const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
                                if (e.key === Qt.Key_Escape) root.hide();
                                else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier)) || (ctrl && e.key === Qt.Key_N))
                                    root.selected = Math.min(root.rows.length - 1, root.selected + 1);
                                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_P))
                                    root.selected = Math.max(0, root.selected - 1);
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.activate(root.selected, ctrl);
                                else return;
                                e.accepted = true;
                            }
                        }
                        Rectangle {
                            visible: root.rows.length > 0
                            x: 18 * Tokens.uiScale; y: win.headH
                            width: parent.width - 36 * Tokens.uiScale; height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }
                        ListView {
                            id: list
                            x: 8 * Tokens.uiScale
                            y: win.headH + 8
                            width: parent.width - 16 * Tokens.uiScale
                            height: Math.min(root.rows.length, win.maxRows) * win.rowH
                            clip: true
                            model: root.rows
                            currentIndex: root.selected
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: Tokens.dur(120)
                            // the selection is a slab of glass gliding down the list
                            highlight: GlassControl {
                                width: list.width
                                height: win.rowH
                                radius: 14 * Tokens.uiScale
                                tint: "#ffffff"
                                tintAmount: 0.06
                                shadow: 0.3
                            }
                            delegate: Item {
                                id: row
                                required property var modelData
                                required property int index
                                width: list.width
                                height: win.rowH
                                Item {
                                    id: ico
                                    x: 12 * Tokens.uiScale
                                    width: 30 * Tokens.uiScale; height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    IconImage {
                                        anchors.fill: parent
                                        visible: row.modelData.kind === "app"
                                        source: row.modelData.kind === "app" ? Icons.path(row.modelData.entry.icon, "application-x-executable") : ""
                                        asynchronous: true
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: row.modelData.kind !== "app"
                                        radius: 9 * Tokens.uiScale
                                        color: Qt.rgba(Tokens.sun.r, Tokens.sun.g, Tokens.sun.b, 0.22)
                                        Text {
                                            anchors.centerIn: parent
                                            text: row.modelData.glyph || ""
                                            color: Tokens.sun
                                            font.pixelSize: 17 * Tokens.uiScale
                                            font.weight: Font.Bold
                                        }
                                    }
                                }
                                Column {
                                    anchors.left: ico.right
                                    anchors.leftMargin: 12 * Tokens.uiScale
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14 * Tokens.uiScale
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        width: parent.width
                                        text: row.modelData.title
                                        color: "#ffffff"
                                        font.family: Tokens.ui
                                        font.pixelSize: 14 * Tokens.uiScale
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        visible: text !== ""
                                        text: row.modelData.sub
                                        color: Qt.rgba(235 / 255, 235 / 255, 245 / 255, 0.6)
                                        font.family: Tokens.ui
                                        font.pixelSize: 11.5 * Tokens.uiScale
                                        elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.selected = row.index
                                    onClicked: m => root.activate(row.index, (m.modifiers & Qt.ControlModifier) !== 0)
                                }
                            }
                        }
                        Text {
                            visible: root.rows.length === 0
                            x: 22 * Tokens.uiScale
                            y: win.headH + 4
                            text: root.cmdMode ? I18n.tr("Type a command, Enter to run") : I18n.tr("Nothing matches")
                            color: Qt.rgba(1, 1, 1, 0.32)
                            font.family: Tokens.ui
                            font.pixelSize: 12 * Tokens.uiScale
                        }
                    }
                }
            }
        }
    }
}
