pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "menu.js" as M

// The plugin's logic: the dropped files, what can be done with them, and every
// call into bin/utsuri. No UI lives here. The host loads one instance and
// hands it to the glyph and the panel as pluginApi.mainInstance.
//
// Every call is an argv array, never a shell string (R9). bin/utsuri answers
// each call with one JSON line; nothing else on stdout is ever parsed.
//
// Each Process has its own "active" flag, set when we start it and cleared only
// in its onExited. A process is never restarted inline (stop + start in one
// tick); a newer request waits in a pending slot and starts from onExited, so a
// stale reply can never land on top of a newer drop.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // ---- settings, each read behind its default (R5) -----------------------
    function _text(key, fallback) {
        const v = settings ? settings[key] : undefined;
        return (v === undefined || v === null || String(v).trim() === "") ? fallback : String(v).trim();
    }
    readonly property string engineDir: _text("engineDir", "~/.local/share/utsuri/engine")
    readonly property string outputMode: _text("output", "next") === "folder" ? "folder" : "next"
    readonly property string ocrLang: _text("ocrLang", "eng").trim() || "eng"

    // ---- is the Shift+drag trigger set up? -----------------------------------
    // Only the compositor can see Shift mid-drag, so the trigger is a block the
    // user pastes into ~/.config/hypr/user.lua (hypr/trigger.lua). The first
    // shift() call proves it works and is remembered in stateDir; until then the
    // bar icon shows (barIcon "auto") and the panel explains the setup.
    readonly property bool hyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    property bool triggerSeen: false
    readonly property string triggerSnippet: (pluginApi && pluginApi.pluginDir) ? pluginApi.pluginDir + "/hypr/trigger.lua" : ""
    function _sawTrigger() {
        if (svc.triggerSeen)
            return;
        svc.triggerSeen = true;
        if (seenFile.path !== "")
            seenFile.setText("1\n");
    }
    FileView {
        id: seenFile
        path: (svc.pluginApi && svc.pluginApi.stateDir) ? svc.pluginApi.stateDir + "/trigger-seen" : ""
        printErrors: false
        onLoaded: svc.triggerSeen = true
    }

    // ---- look and options (the Customize page; see Prefs.qml) ---------------
    Prefs {
        id: prefs
        dir: (svc.pluginApi && svc.pluginApi.stateDir) ? svc.pluginApi.stateDir : ""
    }
    readonly property string themeId: prefs.themeId
    readonly property var look: prefs.look
    readonly property var hidden: prefs.hidden
    function setTheme(id) { prefs.setTheme(id); }
    function isHidden(key) { return prefs.isHidden(key); }
    function setHidden(key, off) { prefs.setHidden(key, off); }
    function showAll() { prefs.showAll(); }
    function _visible(list, kind) {
        return (list || []).filter(it => !svc.isHidden(M.itemKey(svc.category,
            { kind: kind, id: it.id, all: it.all === true })));
    }

    // ---- state the views read ----------------------------------------------
    // doctor: "checking" until the first answer, then "ok" or "error"
    property string doctorState: "checking"
    property string doctorError: ""
    property string doctorFix: ""

    property var files: []          // absolute paths the actions apply to
    property var allPaths: []       // every dropped path: what Archive and Copy path take
    property var skipped: []        // dropped items of another kind, or not files
    property string category: ""
    property var convertActions: [] // [{id, label, hint}]
    property var toolActions: []    // [{id, label}]
    property var editorActions: []  // [{id, label}]
    property string filesError: ""
    readonly property bool loadingActions: svc._actionsActive

    readonly property bool busy: svc._jobActive
    property string busyLabel: ""
    property var result: null       // {ok, title, detail, good, outs} or {ok:false, error}
    property string notice: ""      // short line: "Crop opened in its own window", "Moved to Trash"

    // Resolved on every call, never held in a binding: a binding on pluginDir
    // can still be "" when the first call fires, and a Process with an empty
    // program never exits (the bug kotoba hit).
    function binPath() {
        return (pluginApi && pluginApi.pluginDir) ? pluginApi.pluginDir + "/bin/utsuri" : "";
    }
    function baseArgs() {
        return [binPath(), "--engine", svc.engineDir, "--output", svc.outputMode, "--ocr-lang", svc.ocrLang];
    }
    function _ready() {
        return binPath() !== "";
    }

    // ---- actions the views call --------------------------------------------
    function checkEngine() {
        if (!_ready())
            return;
        if (svc._doctorActive) {
            svc._doctorAgain = true;   // e.g. engineDir changed mid-check: re-run on exit
            return;
        }
        svc._doctorActive = true;
        doctorProc.command = [binPath(), "--engine", svc.engineDir, "doctor"];
        doctorTimeout.restart();
        doctorProc.running = true;
    }

    function setFiles(paths) {
        if (!paths || paths.length === 0)
            return;
        if (svc._jobActive) {
            svc.notice = "Busy with " + svc.busyLabel.replace("…", "") + ". Wait or cancel, then drop again.";
            return;
        }
        svc.result = null;
        svc.notice = "";
        svc.filesError = "";
        svc.files = paths;
        svc.allPaths = paths;
        svc.skipped = [];
        svc.category = "";
        svc.convertActions = [];
        svc.toolActions = [];
        svc.editorActions = [];
        if (svc.doctorState !== "ok")
            checkEngine();
        if (!_ready())
            return;
        if (svc._actionsActive) {
            svc._pendingFiles = paths;   // started from onExited; the stale reply is dropped
            actionsProc.signal(15);
            return;
        }
        _runActions(paths);
    }

    function clear() {
        if (svc._jobActive) {
            svc.notice = "Busy. Wait or cancel first.";
            return;
        }
        svc._pendingFiles = null;
        svc.files = [];
        svc.allPaths = [];
        svc.skipped = [];
        svc.category = "";
        svc.convertActions = [];
        svc.toolActions = [];
        svc.editorActions = [];
        svc.filesError = "";
        svc.result = null;
        svc.notice = "";
    }

    function convertTo(target, label) {
        _start(["convert", "--to", target], "Converting to " + (label || target) + "…", false);
    }

    function runTool(id, label, all) {
        _start(["tool", id], (label || id) + "…", false, all === true);
    }

    function openEditor(id, label) {
        if (!_ready() || svc.files.length === 0)
            return;
        // Detached: the editor is its own window and process; it survives a
        // shell reload and announces its result with a notification.
        Quickshell.execDetached(baseArgs().concat(["editor", id]).concat(svc.files));
        svc.notice = (label || id) + " opened in its own window";
        if (svc.pluginApi && svc.pluginApi.closePanel)
            svc.pluginApi.closePanel();
    }

    function undo() {
        if (!svc.result || !svc.result.ok || !svc.result.outs || svc.result.outs.length === 0)
            return;
        _start(["trash"].concat(svc.result.outs), "Moving to Trash…", true);
    }

    function openResult() {
        if (svc.result && svc.result.ok && svc.result.outs && svc.result.outs.length > 0)
            Quickshell.execDetached(["xdg-open", svc.result.outs[0]]);
    }

    function revealResult() {
        if (!_ready() || !svc.result || !svc.result.ok || !svc.result.outs || svc.result.outs.length === 0)
            return;
        Quickshell.execDetached([binPath(), "--engine", svc.engineDir, "reveal", svc.result.outs[0]]);
    }

    function cancel() {
        _stop("Cancelled. If a file was being written, check its folder for a partial copy.");
    }

    // ---- process plumbing --------------------------------------------------
    property bool _doctorActive: false
    property bool _doctorAgain: false
    property bool _actionsActive: false
    property var _pendingFiles: null
    property bool _jobActive: false
    property bool _jobIsUndo: false
    property bool _cancelled: false

    function _runActions(paths) {
        svc._actionsActive = true;
        actionsProc.command = baseArgs().concat(["actions"]).concat(paths);
        actionsTimeout.restart();
        actionsProc.running = true;
    }

    function _start(args, label, isUndo, all) {
        if (!_ready() || svc._jobActive)
            return;
        if (!isUndo && svc.files.length === 0)
            return;
        svc._jobActive = true;
        svc._jobIsUndo = isUndo;
        svc._cancelled = false;
        svc.busyLabel = label;
        svc.notice = "";
        if (!isUndo)
            svc.result = null;
        job.command = baseArgs().concat(args).concat(isUndo ? [] : all ? svc.allPaths : svc.files);
        watchdog.restart();
        job.running = true;
    }

    // SIGTERM lets the engine unwind; a C call (PyMuPDF, Pillow) that ignores it
    // gets SIGKILL after 4 s; if no exit ever arrives, the guard frees the panel.
    function _stop(message) {
        if (!svc._jobActive)
            return;
        svc._cancelled = true;
        svc.result = { ok: false, error: message };
        job.signal(15);
        killTimer.restart();
    }
    Timer {
        id: killTimer
        interval: 4000
        onTriggered: {
            if (!svc._jobActive)
                return;
            job.signal(9);
            stuckGuard.restart();
        }
    }
    Timer {
        id: stuckGuard
        interval: 8000
        onTriggered: svc._jobActive = false
    }

    // One JSON line, or null when the reply is missing (StdioCollector can
    // lose the race with onExited, so an empty reply is never a state).
    function _parse(raw) {
        const text = (raw || "").trim();
        if (text.length === 0)
            return null;
        try {
            const lines = text.split("\n").filter(l => l.trim().length > 0);
            return JSON.parse(lines[lines.length - 1]);
        } catch (e) {
            return { ok: false, error: "Unreadable reply from bin/utsuri" };
        }
    }

    property string _doctorOut: ""
    property int _doctorRetries: 0
    Process {
        id: doctorProc
        stdout: StdioCollector { id: doctorCol; onStreamFinished: svc._doctorOut = text }
        onExited: (code) => {
            doctorTimeout.stop();
            svc._doctorActive = false;
            const d = svc._parse(doctorCol.text || svc._doctorOut);
            svc._doctorOut = "";
            if (svc._doctorAgain) {
                svc._doctorAgain = false;
                Qt.callLater(svc.checkEngine);   // that answer was for the old engineDir
                return;
            }
            if (!d) {
                // read-only, so a retry is safe
                if (svc._doctorRetries++ < 2) {
                    doctorRetry.restart();
                } else {
                    svc.doctorState = "error";
                    svc.doctorError = "bin/utsuri gave no answer (exit " + code + ")";
                    svc.doctorFix = "~/Documents/ryoku-plugins/utsuri/bin/utsuri doctor";
                }
                return;
            }
            svc._doctorRetries = 0;
            if (d.heif !== undefined)
                svc._heif = !!d.heif;
            svc.doctorState = d.ok ? "ok" : "error";
            svc.doctorError = d.ok ? "" : (d.error || "Engine check failed");
            svc.doctorFix = d.ok ? "" : (d.fix || "");
        }
    }
    Timer { id: doctorRetry; interval: 800; onTriggered: svc.checkEngine() }
    Timer { id: doctorTimeout; interval: 30000; onTriggered: doctorProc.signal(9) }

    property string _actionsOut: ""
    Process {
        id: actionsProc
        stdout: StdioCollector { id: actionsCol; onStreamFinished: svc._actionsOut = text }
        onExited: (code) => {
            actionsTimeout.stop();
            svc._actionsActive = false;
            const d = svc._parse(actionsCol.text || svc._actionsOut);
            svc._actionsOut = "";
            if (svc._pendingFiles) {
                const next = svc._pendingFiles;
                svc._pendingFiles = null;
                svc._runActions(next);           // a newer drop wins; this reply is stale
                return;
            }
            if (!d) {
                svc.filesError = "bin/utsuri gave no answer (exit " + code + "). Drop the files again.";
                return;
            }
            if (!d.ok) {
                svc.filesError = d.error || "Can't read these files";
                svc.files = [];
                return;
            }
            svc.files = d.files || [];
            svc.allPaths = d.all || svc.files;
            svc.skipped = d.skipped || [];
            svc.category = d.category || "";
            svc.convertActions = svc._visible(d.convert, "convert");
            svc.toolActions = svc._visible(d.tools, "tool");
            svc.editorActions = svc._visible(d.editors, "editor");
        }
    }
    Timer { id: actionsTimeout; interval: 60000; onTriggered: actionsProc.signal(9) }

    property string _jobOut: ""
    Process {
        id: job
        stdout: StdioCollector { id: jobCol; onStreamFinished: svc._jobOut = text }
        onExited: (code) => {
            watchdog.stop();
            killTimer.stop();
            stuckGuard.stop();
            svc._jobActive = false;
            const d = svc._parse(jobCol.text || svc._jobOut);
            svc._jobOut = "";
            if (svc._cancelled)
                return;   // _stop already wrote the result
            // A write is never retried: a missing reply might still have written a file.
            if (!d) {
                svc.result = { ok: false, error: "No reply from Utsuri (exit " + code + "). Check the folder before retrying." };
                return;
            }
            if (svc._jobIsUndo) {
                svc.notice = d.ok ? "Moved to Trash" : (d.error || "Undo failed");
                if (d.ok)
                    svc.result = null;
                return;
            }
            svc.result = d;
        }
    }

    // A job running past ten minutes is stuck, not slow.
    Timer {
        id: watchdog
        interval: 60 * 60 * 1000   // a long video encode is legitimate
        onTriggered: svc._stop("Stopped after 10 minutes with no answer")
    }

    // ---- the radial menu (Shift while dragging), its jobs and result cards ----
    property bool _heif: true

    RadialMenu {
        id: radial
        heif: svc._heif
        look: svc.look
        hidden: svc.hidden
        onActivated: (item, files) => svc.runFromMenu(item, files)
    }

    // ---- Oumu (optional) -------------------------------------------------------
    // Oumu, a writing assistant, listens on a socket in the runtime directory for
    // "translate\n<text>" and opens its Translate panel. No program is run: when
    // Oumu is not running the socket refuses, and the card says how to get Oumu.
    readonly property string _oumuSock: (Quickshell.env("XDG_RUNTIME_DIR") || "/nonexistent") + "/oumu.sock"
    readonly property string _oumuMissing: "Translate needs the Oumu app. Install it from github.com/CratusGod/oumu, or start it if you have it, then try again."
    property string _oumuQueued: ""

    Socket {
        id: oumu
        path: svc._oumuSock
        onConnectionStateChanged: {
            if (!connected)
                return;
            if (svc._oumuQueued !== "") {
                write(svc._oumuQueued);
                flush();
                svc._oumuQueued = "";
            }
            connected = false;
        }
        onError: (socketError) => {
            if (svc._oumuQueued !== "") {
                svc._oumuQueued = "";
                toastStack.done(-1, { ok: false, error: svc._oumuMissing });
            }
        }
    }

    function _sendToOumu(text) {
        svc._oumuQueued = "translate\n" + text;
        oumu.connected = true;
    }

    CustomizeWindow {
        id: customizeWin
        svc: svc
    }

    Toasts {
        id: toastStack
        screen: radial.screen
        binPath: svc.binPath()
        engineDir: svc.engineDir
        look: svc.look
        onUndoRequested: (cid, outs) => svc._undoCard(cid, outs)
    }

    // Hyprland's trigger (user.lua) and the editors call these.
    IpcHandler {
        target: "utsuri"
        function shift(x: int, y: int): void { svc._sawTrigger(); radial.shift(x, y); }
        function release(): void { radial.release(); }
        function close(): void { radial.close(); }
        function editorResult(json: string): void { svc._editorResult(json); }
        function customize(): void { customizeWin.toggle(radial.screen); }
    }

    Component { id: jobComp; JobRunner { } }

    // radial.py's working labels (app.run_item)
    readonly property var _toolVerbs: ({ compress: "Compressing…", split: "Splitting…", rotate: "Rotating…",
                                         extract: "Extracting…", merge: "Merging…", zip: "Zipping…",
                                         "tar-gz": "Archiving…", "tar-xz": "Archiving…", ocr: "Reading text…",
                                         copy: "Copying…", "copy-path": "Copying…",
                                         "batch-webp": "Converting images…", "batch-jpg": "Converting images…",
                                         "batch-compress": "Compressing images…", numbers: "Numbering pages…",
                                         gray: "Converting to grayscale…", flatten: "Flattening…",
                                         halves: "Splitting…", chapters: "Splitting by bookmarks…",
                                         searchable: "Recognising text…" })

    function runFromMenu(item, files) {
        if (!files || files.length === 0)
            return;
        // Dragged text: needs neither the engine nor a file.
        if (item.kind === "oumu") {
            _sendToOumu(files[0]);
            return;
        }
        if (item.kind === "text") {
            if (item.id === "copy") {
                Quickshell.execDetached(["wl-copy", "--", files[0]]);
                toastStack.done(-1, { ok: true, title: "Copied" });
            }
            return;
        }
        if (!_ready())
            return;
        if (item.kind === "editor") {
            Quickshell.execDetached(baseArgs().concat(["editor", item.id]).concat(files));
            return;
        }
        if (svc.doctorState === "error") {
            toastStack.done(-1, { ok: false, error: svc.doctorError + (svc.doctorFix ? ". Fix: " + svc.doctorFix : "") });
            return;
        }
        const isConvert = item.kind === "convert";
        const args = isConvert ? ["convert", "--to", item.id] : ["tool", item.id];
        const working = isConvert
            ? (item.id === "PDF" && files.length > 1 ? "Combining " + files.length + " images…" : "Converting to " + item.id + "…")
            : (svc._toolVerbs[item.id] || item.label + "…");
        const name = files.length === 1 ? files[0].slice(files[0].lastIndexOf("/") + 1) : files.length + " files";
        _runJob(baseArgs().concat(args).concat(files), working, name, -1);
    }

    // A spinner card appears only if the job takes longer than 150 ms (app.submit).
    function _runJob(command, working, name, cid) {
        const job = jobComp.createObject(svc, { command: command });
        const state = { cid: cid };
        job.slow.connect(() => {
            if (state.cid < 0)
                state.cid = toastStack.working(working, name);
        });
        job.finished.connect((reply) => toastStack.done(state.cid, reply));
        job.start();
    }

    function _undoCard(cid, outs) {
        if (!_ready())
            return;
        const job = jobComp.createObject(svc, { command: [binPath(), "--engine", svc.engineDir, "trash"].concat(outs) });
        job.finished.connect((reply) => {
            if (reply && reply.ok) {
                const n = reply.trashed || 0;
                toastStack.info(cid, "Undone", "Moved " + n + " file" + (n === 1 ? "" : "s") + " to the Trash");
            } else {
                toastStack.done(cid, { ok: false, error: (reply && reply.error) || "Undo failed" });
            }
        });
        job.start();
    }

    function _editorResult(json) {
        let d = null;
        try {
            d = JSON.parse(json);
        } catch (e) {
            return;
        }
        if (d && (d.ok === false || (d.outs && d.outs.length > 0)))
            toastStack.done(-1, d);
    }

    // Re-check the engine whenever its location changes in settings.
    onEngineDirChanged: {
        svc.doctorState = "checking";
        svc._doctorRetries = 0;
        Qt.callLater(svc.checkEngine);
    }
    onPluginApiChanged: Qt.callLater(svc.checkEngine)
}
