pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Engine.js" as Engine
import "../content"

// service/Main.qml is the plugin's logic: no UI. One instance is shared by
// every mounted view through pluginApi.mainInstance, so they always read the
// same live state. The arithmetic itself lives in Engine.js, a pure module
// with no QML dependency; this file only holds state and wires settings (R5).
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    function setting(k, def) {
        var s = svc.settings;
        if (!s || s[k] === undefined || s[k] === null || s[k] === "") return def;
        return s[k];
    }
    function boolSetting(k, def) {
        var v = svc.setting(k, def);
        if (typeof v === "boolean") return v;
        return v === "true" ? true : (v === "false" ? false : !!def);
    }

    // Settings are validated here: a hand-edited or stale value falls back
    // to the default instead of reaching the views.
    function choiceSetting(k, options, def) {
        var v = svc.setting(k, def);
        return options.indexOf(v) >= 0 ? v : def;
    }
    function intSetting(k, def, lo, hi) {
        var v = Number(svc.setting(k, def));
        if (!isFinite(v)) v = def;
        return Math.max(lo, Math.min(hi, Math.round(v)));
    }

    // --- view state: mode, angle unit, base, keypad, shortcut panel.
    // The Hub settings are the DEFAULTS. Changing one inside the calculator
    // is remembered in state.json (never saveSetting -- see setLayout) as
    // { value, setting }: the value chosen, plus the Hub default it was
    // chosen against. It applies only while that default is unchanged, so
    // picking a new default in the Hub resets it -- live and on the next
    // start -- with no ordering race between settings and state loading.
    readonly property var baseOptions: ({ "hex": 16, "dec": 10, "oct": 8, "bin": 2 })
    readonly property string defLayout: choiceSetting("layout", ["basic", "scientific", "programmer"], "basic")
    readonly property string defAngleMode: choiceSetting("angleMode", ["deg", "rad"], "deg")
    readonly property int defBase: baseOptions[choiceSetting("base", ["hex", "dec", "oct", "bin"], "dec")]
    readonly property bool defKeypad: boolSetting("showKeypad", false)
    readonly property bool defHints: boolSetting("showHints", true)
    property var overrides: ({})    // name -> { value, setting }; see persist()
    // A changed Hub default kills the matching override now (liveOverrides),
    // not only at the next calculator change. Only once state is ready:
    // settings arriving at startup must not queue a save ahead of the load.
    // Pruned in memory too, not only in the file: otherwise flipping a
    // toggle default away and back revives the old choice (the keypad switch
    // in the Hub then seemed to do nothing on its second flip).
    function defaultChanged() {
        if (svc.settings) svc.overrides = svc.liveOverrides();
        if (svc.canPersist) svc.persist();
    }
    onDefLayoutChanged: svc.defaultChanged()
    onDefAngleModeChanged: svc.defaultChanged()
    onDefBaseChanged: svc.defaultChanged()
    onDefKeypadChanged: svc.defaultChanged()
    onDefHintsChanged: svc.defaultChanged()
    function overridden(name, def) {
        var o = svc.overrides[name];
        return (o && o.setting === def) ? o.value : def;
    }
    function defaultFor(name) {
        return name === "layout" ? svc.defLayout : name === "angleMode" ? svc.defAngleMode
             : name === "base" ? svc.defBase : name === "keypad" ? svc.defKeypad : svc.defHints;
    }
    // Overrides whose Hub default has since changed are dead: dropped when
    // saving, so switching the default away and back later can't revive an
    // old choice. Only once the shell's settings are in -- before that the
    // defaults are this file's fallbacks and would drop live entries.
    function liveOverrides() {
        if (!svc.settings) return svc.overrides;
        var o = {};
        for (var name in svc.overrides)
            if (svc.overrides[name].setting === svc.defaultFor(name)) o[name] = svc.overrides[name];
        return o;
    }
    function setOverride(name, value) {
        var o = Object.assign({}, svc.overrides);
        var def = svc.defaultFor(name);
        if (value === def) delete o[name];
        else o[name] = { value: value, setting: def };
        svc.overrides = o;
        svc.persist();
    }

    readonly property string layout: overridden("layout", defLayout)
    readonly property bool programmer: layout === "programmer"
    readonly property bool showKeypad: overridden("keypad", defKeypad)
    readonly property bool showHints: overridden("hints", defHints)
    readonly property string angleMode: overridden("angleMode", defAngleMode)
    readonly property bool thousandsSeparator: boolSetting("thousandsSeparator", true)
    readonly property int precision: intSetting("precision", 10, 0, 15)
    readonly property int historySize: intSetting("historySize", 50, 0, 200)
    // Lowering the setting (to 0 = keep none) trims the tape now, not only
    // at the next result.
    onHistorySizeChanged: if (svc.history.length > svc.historySize) {
        svc.history = svc.trimHistory(svc.history);
        svc.persist();
    }
    // The newest historySize entries; none at all when historySize is 0.
    function trimHistory(h) {
        if (svc.historySize <= 0) return [];
        return h.length > svc.historySize ? h.slice(h.length - svc.historySize) : h;
    }

    property string expression: ""
    property string preview: ""
    property real previewValue: 0
    property bool previewValid: false
    property string errorText: ""
    property real lastAnswer: 0
    property bool justEvaluated: false
    property var history: []        // [{expr, result, input}], oldest first
    property int historyCursor: -1  // -1 = not currently browsing history
    property real memory: 0
    property bool hasMemory: false
    property var vars: ({})         // user variables from "name = expr"
    readonly property int base: overridden("base", defBase) // 2 / 8 / 10 / 16; programmer mode only
    readonly property int activeBase: programmer ? base : 10
    // The last result as written back into the input, so chaining keeps its
    // full precision (see Engine.normalizeCtx "carry").
    property var carry: null

    function ctx() {
        return { angleMode: svc.angleMode, ans: svc.lastAnswer, vars: svc.vars,
                 programmer: svc.programmer, base: svc.base, carry: svc.carry };
    }
    function fmt(v) {
        return Engine.format(v, { precision: svc.precision, thousands: svc.thousandsSeparator, base: svc.activeBase });
    }
    function inputText(v) { return Engine.toInput(v, { precision: svc.precision, base: svc.activeBase }); }
    function currentValue() { return svc.previewValid ? svc.previewValue : svc.lastAnswer; }
    function formatIn(v, b) { return Engine.format(v, { precision: svc.precision, thousands: false, base: b }); }
    function groupDigits(str, size) { return Engine.groupDigits(str, size, " "); }

    // A character that begins a new value: typed right after a result it
    // starts a fresh expression instead of being glued onto the result.
    // Operators ("+", "*", "^", "%", "!") still continue from the result.
    function startsFresh(ch) { return /^[0-9.a-zA-Z_(∞π]/.test(ch || ""); }

    function updatePreview() {
        svc.errorText = "";
        if (svc.expression.trim().length === 0) {
            svc.preview = ""; svc.previewValid = false;
            return;
        }
        try {
            var r = Engine.evaluateStatement(svc.expression, svc.ctx());
            svc.previewValue = r.value;
            svc.previewValid = true;
            svc.preview = (r.name ? r.name + " = " : "") + svc.fmt(r.value);
        } catch (e) {
            svc.previewValid = false;
            svc.preview = "";
        }
    }

    function setExpression(text) {
        svc.expression = text;
        svc.justEvaluated = false;
        svc.historyCursor = -1;
        svc.updatePreview();
    }

    function typeToken(token) {
        if (svc.justEvaluated && svc.startsFresh(token)) svc.expression = token;
        else svc.expression = svc.expression + token;
        svc.justEvaluated = false;
        svc.historyCursor = -1;
        svc.updatePreview();
    }

    function backspace() {
        if (svc.expression.length > 0) svc.expression = svc.expression.slice(0, -1);
        svc.justEvaluated = false;
        svc.updatePreview();
    }
    function clearEntry() {
        svc.expression = "";
        svc.errorText = "";
        svc.preview = "";
        svc.previewValid = false;
        svc.justEvaluated = false;
        svc.carry = null;
    }
    function clearAll() {
        svc.clearEntry();
        svc.lastAnswer = 0;
        svc.historyCursor = -1;
    }
    function clearHistory() {
        svc.history = [];
        svc.historyCursor = -1;
        svc.persist();
    }

    function evaluate() {
        if (svc.expression.trim().length === 0) return false;
        try {
            var r = Engine.evaluateStatement(svc.expression, svc.ctx());
            var v = r.value;
            var input = svc.inputText(v);
            var entry = { expr: svc.expression, result: (r.name ? r.name + " = " : "") + svc.fmt(v), input: input };
            // The value itself, so inserting this result later is written in
            // the base active then, not the one it was computed in.
            if (isFinite(v)) entry.value = v;
            svc.history = svc.trimHistory(svc.history.concat([entry]));
            if (r.name) {
                var nv = Object.assign({}, svc.vars);
                nv[r.name] = v;
                svc.vars = nv;
            }
            svc.lastAnswer = v;
            svc.carry = { text: input, value: v };
            svc.expression = input;
            svc.preview = "";
            svc.previewValid = false;
            svc.errorText = "";
            svc.justEvaluated = true;
            svc.historyCursor = -1;
            svc.persist();
            return true;
        } catch (e) {
            svc.errorText = String(e.message || e);
            return false;
        }
    }

    function historyUp() {
        if (svc.history.length === 0) return;
        if (svc.historyCursor === -1) svc.historyCursor = svc.history.length - 1;
        else if (svc.historyCursor > 0) svc.historyCursor -= 1;
        svc.expression = svc.history[svc.historyCursor].expr;
        svc.justEvaluated = false;
        svc.updatePreview();
    }
    function historyDown() {
        if (svc.historyCursor === -1) return;
        if (svc.historyCursor < svc.history.length - 1) {
            svc.historyCursor += 1;
            svc.expression = svc.history[svc.historyCursor].expr;
        } else {
            svc.historyCursor = -1;
            svc.expression = "";
        }
        svc.justEvaluated = false;
        svc.updatePreview();
    }
    // Insert a history entry's result at the end of the expression (or in
    // place of a just-shown result).
    function useHistoryResult(index) {
        var e = svc.history[index];
        if (!e) return;
        var t = e.input !== undefined ? e.input : e.result;
        if (typeof e.value === "number" && isFinite(e.value)) t = svc.inputText(e.value);
        else if (e.input !== undefined) {
            // Entries saved before `value` existed: their input text is
            // always valid DEC (other bases carry a 0x/0o/0b prefix).
            try { t = svc.inputText(Engine.evaluate(e.input, {})); } catch (err) {}
        }
        if (t.length > 0) svc.typeToken(t);
    }

    function memAdd() { svc.memory += svc.currentValue(); svc.hasMemory = true; svc.persist(); }
    function memSub() { svc.memory -= svc.currentValue(); svc.hasMemory = true; svc.persist(); }
    function memRecall() { svc.typeToken(svc.inputText(svc.memory)); }
    function memClear() { svc.memory = 0; svc.hasMemory = false; svc.persist(); }

    // Switching mode, angle, base, keypad or shortcut panel from inside the
    // calculator NEVER calls pluginApi.saveSetting(). It did once, and
    // switching modes froze the whole popout/panel solid, Escape included --
    // no coredump, no QML error in the logs, the UI thread itself just never
    // came back. The settings write reloads this very plugin's component tree
    // (both host files watch the plugin settings and rebuild on change),
    // which can re-enter while the click handler that triggered it is still
    // on the stack. These choices go to state.json instead (setOverride), a
    // file only this service writes, which reloads nothing.
    function setLayout(v) {
        if (v === svc.layout || ["basic", "scientific", "programmer"].indexOf(v) < 0) return;
        svc.setOverride("layout", v);
        svc.rerenderResult();
    }
    function cycleLayout() {
        var order = ["basic", "scientific", "programmer"];
        svc.setLayout(order[(order.indexOf(svc.layout) + 1) % order.length]);
    }
    function toggleAngleMode() {
        svc.setOverride("angleMode", svc.angleMode === "deg" ? "rad" : "deg");
        svc.updatePreview();
    }
    function toggleKeypad() { svc.setOverride("keypad", !svc.showKeypad); }
    function toggleHints() { svc.setOverride("hints", !svc.showHints); }
    // Ctrl+B: the mode's secondary switch -- base in Programmer, angle unit
    // in Scientific; nothing in Basic.
    function toggleSecondary() {
        if (svc.programmer) svc.cycleBase();
        else if (svc.layout === "scientific") svc.toggleAngleMode();
    }
    function setBase(b) {
        if (b === svc.base || [2, 8, 10, 16].indexOf(b) < 0) return;
        svc.setOverride("base", b);
        svc.rerenderResult();
    }
    function cycleBase() {
        var order = [16, 10, 8, 2];
        svc.setBase(order[(order.indexOf(svc.base) + 1) % order.length]);
    }
    // After a mode/base switch, a result still sitting in the input is
    // re-written in the new notation; anything else is re-previewed as typed.
    function rerenderResult() {
        if (svc.justEvaluated) {
            var v = svc.programmer ? (Math.trunc(svc.lastAnswer) | 0) : svc.lastAnswer;
            var input = svc.inputText(v);
            svc.carry = { text: input, value: v };
            svc.expression = input;
            svc.justEvaluated = true;
        } else {
            svc.updatePreview();
        }
    }

    // --- clipboard. "--" ends wl-copy's own options, so a negative result
    // ("-5") is copied rather than parsed as a flag.
    Process { id: copyProc }
    function copyText(text) {
        if (!text || text.length === 0) return;
        copyProc.command = ["wl-copy", "--", text];
        copyProc.running = true;
    }
    function copyResult() {
        var text = Engine.toInput(svc.currentValue(), { precision: svc.precision, base: svc.activeBase });
        svc.copyText(text);
    }
    // Ctrl+Shift+C: the whole calculation, "expr = result".
    function copyCalculation() {
        if (svc.previewValid) {
            svc.copyText(svc.expression.trim() + " = " + svc.inputText(svc.previewValue));
        } else if (svc.history.length > 0) {
            var e = svc.history[svc.history.length - 1];
            svc.copyText(e.expr.trim() + " = " + (e.input !== undefined ? e.input : e.result));
        }
    }

    // --- persistence: history, variables and memory survive a shell
    // restart in $XDG_STATE_HOME/ryoku/plugins/quickcalc/state.json
    // (R8). The bar host passes pluginApi.stateDir (and creates it); the
    // framePopout host passes neither, so the same path is derived here and
    // created with mkdir -p.
    readonly property string stateDir: (svc.pluginApi && svc.pluginApi.stateDir)
        ? svc.pluginApi.stateDir
        : ((Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/plugins/quickcalc")
    property bool stateDirReady: false
    property bool loadingState: false
    // Saving waits for both the state dir (mkdir) and the first read of
    // state.json -- writing before that read would replace the saved tape
    // with this session's. A save asked for earlier is kept pending and
    // written as soon as both are done, never dropped.
    property bool stateLoaded: false
    property bool persistPending: false
    readonly property bool canPersist: stateDirReady && stateLoaded
    onCanPersistChanged: if (svc.canPersist && svc.persistPending) svc.persist()

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", svc.stateDir]
        onExited: (exitCode) => { svc.stateDirReady = exitCode === 0; }
    }
    Component.onCompleted: mkdirProc.running = true

    FileView {
        id: stateFile
        path: svc.stateDir + "/state.json"
        // Not watched: this service is the file's only writer, and reloading
        // on its own writes raced quick toggles -- a late reload of an older
        // write rolled showHints (or history) back. Read once at startup.
        atomicWrites: true
        printErrors: false
        onLoaded: { svc.loadState(text()); svc.stateLoaded = true; }
        // No file yet (first run) or unreadable: nothing to merge.
        onLoadFailed: svc.stateLoaded = true
    }

    function loadState(text) {
        var data;
        try { data = JSON.parse(text); } catch (e) { return; }
        if (!data || typeof data !== "object") return;
        svc.loadingState = true;
        try { svc.applyState(data); } catch (e) {}
        // Always cleared: a throw that left it set used to switch persistence
        // off for the rest of the session.
        svc.loadingState = false;
    }
    function applyState(data) {
        if (Array.isArray(data.history)) {
            var h = data.history.filter(function (e) {
                return e && typeof e.expr === "string" && typeof e.result === "string"
                    && (e.input === undefined || typeof e.input === "string")
                    && (e.value === undefined || e.value === null || typeof e.value === "number");
            });
            // Anything computed before the file finished loading follows
            // the saved tape instead of being replaced by it.
            svc.history = svc.trimHistory(h.concat(svc.history));
        }
        if (data.vars && typeof data.vars === "object") {
            var v = {};
            // Only names the engine could have assigned; "__proto__" as a key
            // would throw (or swap the object's prototype) instead of storing.
            for (var k in data.vars)
                if (/^[a-z_][a-z0-9_]*$/.test(k) && k !== "__proto__" && typeof data.vars[k] === "number")
                    v[k] = data.vars[k];
            svc.vars = Object.assign(v, svc.vars); // this session's assignments win
        }
        // A change made this session before the load (persistPending) wins.
        if (!svc.persistPending && typeof data.memory === "number") { svc.memory = data.memory; svc.hasMemory = !!data.hasMemory; }
        var ov = {};
        if (data.overrides && typeof data.overrides === "object") {
            var valid = {
                layout: function (x) { return ["basic", "scientific", "programmer"].indexOf(x) >= 0; },
                angleMode: function (x) { return x === "deg" || x === "rad"; },
                base: function (x) { return [2, 8, 10, 16].indexOf(x) >= 0; },
                keypad: function (x) { return typeof x === "boolean"; },
                hints: function (x) { return typeof x === "boolean"; }
            };
            for (var name in valid) {
                var o = data.overrides[name];
                if (o && typeof o === "object" && valid[name](o.value) && valid[name](o.setting))
                    ov[name] = { value: o.value, setting: o.setting };
            }
        } else if (typeof data.showHints === "boolean" && data.showHints !== svc.defHints) {
            // state.json from before overrides: it kept only showHints, which
            // had no Hub default then (it was always on).
            ov.hints = { value: data.showHints, setting: true };
        }
        svc.overrides = Object.assign(ov, svc.overrides); // this session's changes win
    }

    function persist() {
        if (svc.loadingState) return;
        if (!svc.canPersist) { svc.persistPending = true; return; }
        svc.persistPending = false;
        // JSON has no Infinity; such a variable or memory simply isn't kept.
        var v = {};
        for (var k in svc.vars) if (isFinite(svc.vars[k])) v[k] = svc.vars[k];
        stateFile.setText(JSON.stringify({
            version: 1,
            history: svc.historySize > 0 ? svc.history : [],
            vars: v,
            memory: isFinite(svc.memory) ? svc.memory : 0,
            hasMemory: svc.hasMemory && isFinite(svc.memory),
            overrides: svc.liveOverrides()
        }));
    }

    // --- the two placements.
    //
    // Bar (topbarGlyph): the glyph opens content/Panel.qml under it, through
    // the host-provided pluginApi.togglePanel().
    //
    // Frame popout (framePopout): used as the FLOATING WINDOW placement. The
    // shell's own frame popout docked to an edge is a hover popout -- opened
    // by keybind it closes ~2.5 s after the pointer leaves it, which no
    // plugin can switch off -- so the calculator instead opens in its own
    // layer surface (content/FloatingWindow.qml), positioned where the
    // Hub's drag-and-drop popout placer says (read below). The shell's frame
    // popout itself only ever shows a small "open" button (Widget.qml).
    //
    // One keybind for both, answered by the plugin itself (`ryoku-shell
    // plugin <id>` reaches frame popouts only):
    //
    //   qs -c shell ipc call quickcalc toggle
    readonly property bool onBar: !!(svc.pluginApi && typeof svc.pluginApi.togglePanel === "function")
    function toggle() {
        if (svc.onBar) svc.pluginApi.togglePanel();
        else svc.windowOpen = !svc.windowOpen;
    }

    property bool windowOpen: false
    function openWindow() { svc.windowOpen = true; }
    function closeWindow() { svc.windowOpen = false; }
    function close() { svc.closeWindow(); }

    // The floating window's position is this plugin's own framePopout
    // placement (edge: left/right/top/bottom/center, align: start/center/
    // end), as the Hub's drag-and-drop placer sets it. pluginApi does not
    // carry the placement, so content/Widget.qml -- mounted inside the
    // frame-popout host -- reports what that host resolved (see
    // setPlacement callers there). Until it does, the window is centred.
    property string placeEdge: "center"
    property string placeAlign: "center"
    function setPlacement(edge, align) {
        var edges = ["left", "right", "top", "bottom", "center"];
        var aligns = ["start", "center", "end"];
        svc.placeEdge = edges.indexOf(edge) >= 0 ? edge : "center";
        svc.placeAlign = aligns.indexOf(align) >= 0 ? align : "center";
    }

    LazyLoader {
        active: svc.windowOpen
        FloatingWindow { service: svc }
    }

    IpcHandler {
        target: "quickcalc"
        function toggle(): void { svc.toggle(); }
    }
}
