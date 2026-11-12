pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Spotlight-style launcher that grows out of the island (Super+Space).
//   type          → fuzzy-search apps (most-used float up)
//   > cmd         → run a shell command          (Ctrl+Enter: run it in a terminal)
//   1+2*3         → quick maths, Enter copies the result
//   ↑/↓ Tab       → move   Enter → open   Esc → close
Item {
    id: root
    property bool active: false
    readonly property int maxRows: 7
    readonly property int rowH: 46
    readonly property int headerH: 58
    // height the island should take for the current results
    readonly property int wantedHeight: headerH + (rows.length > 0 ? 6 + Math.min(rows.length, maxRows) * rowH + 10 : 34)

    property string query: ""
    property int sel: 0
    readonly property string q: query.trim()
    readonly property bool cmdMode: q.startsWith(">")
    readonly property string cmdText: cmdMode ? q.slice(1).trim() : q

    onActiveChanged: {
        if (active) { field.text = ""; sel = 0; focusTimer.restart(); }
        else field.focus = false;
    }
    // the layer surface gets keyboard focus a frame after it turns exclusive
    Timer { id: focusTimer; interval: 30; onTriggered: { field.forceActiveFocus(); } }

    // ── usage history (launch counts) → ranking ──
    FileView {
        id: histFile
        path: Config.dir + "/launcher-history.json"
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()
        JsonAdapter {
            id: hist
            property var counts: ({})
        }
    }
    function bump(id) {
        const c = Object.assign({}, hist.counts || {});
        c[id] = (c[id] || 0) + 1;
        hist.counts = c;
    }

    // ── maths ──
    // The stock JS evaluator ran through the Function() constructor, which is
    // a hard no in the store's screening; a small shunting-yard parser does
    // the same arithmetic with no eval.
    function mathEval(src) {
        // tokenize
        const t = [];
        let i = 0;
        while (i < src.length) {
            const c = src[i];
            if (c === " " || c === "\t") { i++; continue; }
            if (c === ",") { t.push({ t: "num", v: "." }); i++; continue; }
            if (/[0-9.]/.test(c)) {
                let j = i;
                while (j < src.length && /[0-9.]/.test(src[j])) j++;
                t.push({ t: "num", v: src.slice(i, j) });
                i = j;
                continue;
            }
            if ("+-*/%^()".indexOf(c) >= 0) { t.push({ t: c }); i++; continue; }
            return NaN;
        }
        // shunting-yard → RPN
        const out = [], ops = [];
        const prec = { "+": 1, "-": 1, "*": 2, "/": 2, "%": 2, "^": 3 };
        const right = { "^": true };
        let prev = null;
        for (const tok of t) {
            if (tok.t === "num") { out.push(tok.v); }
            else if (tok.t === "(") { ops.push(tok); }
            else if (tok.t === ")") {
                while (ops.length && ops[ops.length - 1].t !== "(") out.push(ops.pop().t);
                if (!ops.length) return NaN;
                ops.pop();
            } else {
                // unary minus / plus
                if ((tok.t === "-" || tok.t === "+") && (prev === null || prev === "(" || prec[prev] !== undefined))
                    out.push("0");
                while (ops.length && prec[ops[ops.length - 1].t] !== undefined &&
                       (prec[ops[ops.length - 1].t] > prec[tok.t] ||
                        (prec[ops[ops.length - 1].t] === prec[tok.t] && !right[tok.t])))
                    out.push(ops.pop().t);
                ops.push(tok);
            }
            prev = tok.t;
        }
        while (ops.length) {
            if (ops[ops.length - 1].t === "(") return NaN;
            out.push(ops.pop().t);
        }
        // evaluate RPN
        const st = [];
        for (const o of out) {
            if (o === "+" || o === "-" || o === "*" || o === "/" || o === "%" || o === "^") {
                if (st.length < 2) return NaN;
                const b = st.pop(), a = st.pop();
                st.push(o === "+" ? a + b : o === "-" ? a - b : o === "*" ? a * b
                     : o === "/" ? a / b : o === "%" ? a % b : Math.pow(a, b));
            } else {
                const v = parseFloat(o);
                if (isNaN(v)) return NaN;
                st.push(v);
            }
        }
        return st.length === 1 ? st[0] : NaN;
    }
    readonly property string mathResult: {
        const s = cmdMode ? "" : q;
        if (s.length < 2 || !/^[0-9+\-*/().%^ ,]+$/.test(s) || !/[0-9]/.test(s) || !/[+\-*/%^]/.test(s)) return "";
        const v = mathEval(s);
        if (typeof v !== "number" || isNaN(v) || !isFinite(v)) return "";
        return String(Math.round(v * 1e10) / 1e10);
    }

    // ── results ──
    function score(e, s) {
        const n = (e.name || "").toLowerCase();
        if (!s) return 1;
        let sc = 0;
        if (n === s) sc = 1000;
        else if (n.startsWith(s)) sc = 800;
        else if (n.split(/[\s\-_.]+/).some(w => w.startsWith(s))) sc = 600;
        else if (n.indexOf(s) >= 0) sc = 400;
        else if ((e.genericName || "").toLowerCase().indexOf(s) >= 0) sc = 250;
        else if ((e.keywords || []).some(k => String(k).toLowerCase().startsWith(s))) sc = 200;
        else if ((e.id || "").toLowerCase().indexOf(s) >= 0) sc = 150;
        else if ((e.comment || "").toLowerCase().indexOf(s) >= 0) sc = 60;
        else {
            // subsequence ("ffx" → firefox)
            let i = 0;
            for (let k = 0; k < n.length && i < s.length; k++) if (n[k] === s[i]) i++;
            if (i === s.length && s.length >= 2) sc = 40;
        }
        return sc;
    }
    readonly property var rows: {
        const out = [];
        if (!active) return out;
        if (cmdMode) {
            if (cmdText !== "") {
                out.push({ kind: "cmd", title: cmdText, sub: "Run command  ·  Ctrl+Enter in terminal", icon: "terminal" });
            }
            return out;
        }
        if (mathResult !== "") out.push({ kind: "math", title: "= " + mathResult, sub: "Enter to copy", icon: "calculate" });
        const s = q.toLowerCase();
        const counts = hist.counts || {};
        const apps = DesktopEntries.applications.values;
        const scored = [];
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i];
            if (!e || e.noDisplay) continue;
            const sc = score(e, s);
            if (sc <= 0) continue;
            const used = counts[e.id] || 0;
            scored.push({ e: e, sc: sc + Math.min(used, 40) * (s ? 6 : 25) });
        }
        scored.sort((a, b) => b.sc - a.sc || (a.e.name || "").localeCompare(b.e.name || ""));
        const lim = s ? 40 : 24;
        for (let i = 0; i < scored.length && i < lim; i++)
            out.push({ kind: "app", entry: scored[i].e, title: scored[i].e.name, sub: scored[i].e.genericName || scored[i].e.comment || "" });
        if (s && out.length === 0)
            out.push({ kind: "cmd", title: q, sub: "No apps found  ·  Enter runs it as a command", icon: "terminal" });
        return out;
    }
    onRowsChanged: sel = Math.min(sel, Math.max(0, rows.length - 1))
    onQueryChanged: sel = 0

    function terminal(cmd) {
        // order: kitty, then xdg-terminal-exec, then $TERMINAL (default foot)
        return ["sh", "-c", "if command -v kitty >/dev/null; then exec kitty --hold sh -c \"$1\"; " +
                "elif command -v xdg-terminal-exec >/dev/null; then exec xdg-terminal-exec sh -c \"$1; exec $SHELL\"; " +
                "else exec ${TERMINAL:-foot} sh -c \"$1; exec $SHELL\"; fi", "sh", cmd];
    }
    function activate(i, inTerminal) {
        const r = rows[i];
        if (!r) return;
        if (r.kind === "app") {
            const e = r.entry;
            bump(e.id);
            if (e.runInTerminal) Quickshell.execDetached(terminal(e.execString.replace(/%[fFuUdDnNickvm]/g, "").trim()));
            else e.execute();
        } else if (r.kind === "cmd") {
            const c = r.title;
            if (inTerminal) Quickshell.execDetached(terminal(c));
            else Quickshell.execDetached(["sh", "-c", c]);
        } else if (r.kind === "math") {
            Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", mathResult]);
        }
        Hub.closeLauncher();
    }

    // ── search field ──
    Item {
        id: header
        width: parent.width
        height: root.headerH
        Icon {
            id: searchIcon
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            text: root.cmdMode ? "terminal" : "search"
            size: 22
            color: root.cmdMode ? Theme.accent : Theme.fg2
        }
        TextField {
            id: field
            anchors.left: searchIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            height: 40
            leftPadding: 2
            placeholderText: "Search apps, or > to run a command"
            placeholderTextColor: Theme.fg3
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 19
            font.weight: Font.Medium
            selectionColor: Theme.accent
            background: Item {}
            onTextChanged: root.query = text
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { Hub.closeLauncher(); e.accepted = true; }
                else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier)) || (e.key === Qt.Key_N && (e.modifiers & Qt.ControlModifier))) {
                    root.sel = Math.min(root.rows.length - 1, root.sel + 1); e.accepted = true;
                } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier))) {
                    root.sel = Math.max(0, root.sel - 1); e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    root.activate(root.sel, !!(e.modifiers & Qt.ControlModifier)); e.accepted = true;
                }
            }
        }
    }
    Rectangle {
        visible: root.rows.length > 0
        x: 18; y: root.headerH
        width: parent.width - 36; height: 1
        color: Theme.sep
    }

    // ── results ──
    ListView {
        id: list
        x: 8
        y: root.headerH + 6
        width: parent.width - 16
        height: Math.min(root.rows.length, root.maxRows) * root.rowH
        clip: true
        model: root.rows
        currentIndex: root.sel
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 120
        highlightFollowsCurrentItem: true
        highlight: Rectangle { radius: 14; color: Theme.fill2 }
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: root.rowH
            Item {
                id: ico
                x: 12
                width: 30; height: 30
                anchors.verticalCenter: parent.verticalCenter
                IconImage {
                    anchors.fill: parent
                    visible: row.modelData.kind === "app"
                    source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.entry.icon, "application-x-executable") : ""
                    asynchronous: true
                }
                Rectangle {
                    anchors.fill: parent
                    visible: row.modelData.kind !== "app"
                    radius: 9
                    color: Theme.alpha(Theme.accent, 0.22)
                    Icon { anchors.centerIn: parent; text: row.modelData.icon || "bolt"; size: 18; fill: 1; color: Theme.accent }
                }
            }
            Column {
                anchors.left: ico.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Txt { width: parent.width; text: row.modelData.title; size: 14; weight: Font.DemiBold }
                Txt { width: parent.width; visible: text !== ""; text: row.modelData.sub; size: 11.5; color: Theme.fg2 }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.sel = row.index
                onClicked: m => root.activate(row.index, !!(m.modifiers & Qt.ControlModifier))
            }
        }
    }
    Txt {
        visible: root.rows.length === 0
        x: 22; y: root.headerH + 4
        text: root.cmdMode ? "Type a command, Enter to run" : "Type to search"
        size: 12; color: Theme.fg3
    }
}
