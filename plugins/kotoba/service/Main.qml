pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// The plugin's logic: owns the card, the countdown and every call into
// bin/kotoba. No UI lives here. The host loads one instance and hands it to the
// view as pluginApi.mainInstance.
//
// Every call passes an argv array, never a shell string (R9), and the CLI is the
// only thing that touches disk - it writes solely under stateDir (R8).
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property bool ready: !!pluginApi && !!pluginApi.pluginDir

    // ---- settings, each read behind its default (R5) ----------------------

    function _num(key, fallback) {
        const v = settings ? settings[key] : undefined;
        const n = Number(v);
        return (v === undefined || v === null || isNaN(n)) ? fallback : n;
    }
    function _bool(key, fallback) {
        const v = settings ? settings[key] : undefined;
        if (v === undefined || v === null) return fallback;
        return v === true || v === "true" || v === 1 || v === "1";
    }
    function _str(key, fallback) {
        const v = settings ? settings[key] : undefined;
        return (v === undefined || v === null || v === "") ? fallback : String(v);
    }

    readonly property int intervalMin: Math.max(1, Math.min(120, Math.round(_num("intervalMin", 10))))
    readonly property bool autoAdvance: _bool("autoAdvance", false)
    readonly property bool showRomaji: _bool("showRomaji", true)
    readonly property bool showFurigana: _bool("showFurigana", true)
    readonly property real fontScale: Math.max(0.8, Math.min(1.6, _num("fontScale", 1.0)))
    readonly property bool showIntervals: _bool("showIntervals", true)
    // Off by default: a plugin that starts sending desktop notifications the
    // moment it updates would be rude.
    readonly property bool notify: _bool("notify", false)
    readonly property string decksDir: _str("decksDir", "")

    // Nothing is fetched until this is switched on. Default false (R11: the
    // README says exactly what goes over the wire and to which host).
    readonly property bool online: _bool("online", false)
    readonly property string dictPack: _str("dictPack", "basic")

    readonly property string scriptCsv: {
        const out = [];
        if (_bool("scriptHiragana", true)) out.push("hiragana");
        if (_bool("scriptKatakana", true)) out.push("katakana");
        if (_bool("scriptKanji", true)) out.push("kanji");
        return out.join(",");
    }

    // A kana-drill answer IS romaji, so with romaji off the type is dropped
    // rather than shown unanswerable.
    readonly property string typeCsv: {
        const out = [];
        if (_bool("typeRecognition", true)) out.push("recog");
        if (_bool("typeReading", true)) out.push("reading");
        if (_bool("typeRecall", false)) out.push("recall");
        if (_bool("typeKana", true) && svc.showRomaji) out.push("kana");
        return out.join(",");
    }

    // ---- live state -------------------------------------------------------

    // init | question | revealed | waiting | caught-up | empty | error
    property string phase: "init"
    property var card: null
    property string reason: ""
    property string errorText: ""

    property int dueCount: 0
    property int newCount: 0
    property int totalCount: 0
    property int reviewsToday: 0
    property int reviewsTotal: 0

    // The first handful of cards carry a hint; after that the tile is quiet.
    readonly property bool firstRun: svc.reviewsTotal < 5

    // What undo would put back. Comes from stats, so the chip is still correct
    // after a shell reload rather than only within one session.
    property var undoInfo: null
    readonly property bool canUndo: !!svc.undoInfo
    readonly property string undoLabel: {
        if (!svc.undoInfo)
            return "";
        const names = { "1": "Again", "2": "Hard", "3": "Good", "4": "Easy" };
        return svc.undoInfo.jp + "  \u00b7  " + (names[svc.undoInfo.rating] || "");
    }

    // The id of the notification we last posted, so each new toast REPLACES it
    // instead of stacking another entry in the tray. At a one-minute interval
    // that is the difference between one notification and sixty an hour.
    property int notifyId: 0
    property int _lastNotifiedCard: -1
    property real nextDueIn: 0      // seconds until the next scheduled card
    property real nextCardIn: 0     // seconds until the timer offers a new card

    // Attribution is derived from the decks actually loaded, never hardcoded:
    // showing an EDRDG credit with only CC0 kana decks loaded would be a lie,
    // and omitting it once JMdict-derived cards are present would breach the
    // CC BY-SA terms. See PROVENANCE.md.
    property var deckList: []
    readonly property string attribution: {
        const seen = [];
        for (const d of svc.deckList) {
            if (!d || !d.notes || d.license === "CC0-1.0")
                continue;
            const line = (d.source && d.source.length > 0 ? d.source : d.name)
                + " \u00b7 " + d.license;
            if (seen.indexOf(line) < 0)
                seen.push(line);
        }
        return seen.join("   ");
    }

    // dictionary
    property bool dictReady: false
    property int dictEntries: 0
    property string dictPackInstalled: ""
    property bool dictBusy: false

    // lookup
    property bool lookupBusy: false
    property string lookupResult: ""
    property string lookupError: ""
    property var lookupHits: []
    property string lookupWord: ""

    // Resolved on every call, NOT held in a binding.
    //
    // `ready` and a `cmd` binding both derive from pluginApi.pluginDir, and QML
    // does not define which updates first. onReadyChanged could therefore fire
    // while cmd was still "", starting a Process with an empty program that
    // never emits exited() - which left initProc.running stuck true, and the
    // reload() guard then blocked every retry forever. The tile sat on
    // "Loading decks" while its timers kept ticking.
    function binPath() {
        return (pluginApi && pluginApi.pluginDir)
            ? pluginApi.pluginDir + "/bin/kotoba" : "";
    }

    // ---- actions the view calls ------------------------------------------

    function reveal() {
        if (svc.phase === "question")
            svc.phase = "revealed";
    }

    function grade(rating) {
        if (svc.phase !== "revealed" || !svc.card || gradeProc.running)
            return;
        const c = svc.binPath();
        if (!c) return;
        gradeProc.command = [c, "grade", "--card", "" + svc.card.id,
                             "--rating", "" + rating];
        gradeProc.running = true;
    }

    function undo() {
        if (!svc.ready || !svc.canUndo || undoProc.running)
            return;
        const c = svc.binPath();
        if (!c) return;
        undoProc.command = [c, "undo"];
        undoProc.running = true;
    }

    function sendToast() {
        if (!svc.ready || !svc.notify || notifyProc.running)
            return;
        // Deliberately carries NO Japanese: the toast must not spoil the card.
        const body = svc.dueCount > 0
            ? "A new word is ready  \u00b7  " + svc.dueCount + " due"
            : "A new word is ready";
        const args = ["notify-send", "-a", "Kotoba", "-u", "low", "-t", "6000", "-p"];
        if (svc.notifyId > 0)
            args.push("-r", "" + svc.notifyId);
        args.push("Kotoba", body);
        notifyProc.command = args;
        notifyProc.running = true;
    }

    // Explicit user request: bypass the pacing interval once, then restart it
    // cleanly from this moment rather than resuming a part-spent countdown.
    function reviewNow() {
        if (!svc.ready)
            return;
        svc.nextCardIn = svc.intervalMin * 60;
        svc.loadNext();
    }

    function skip() {
        svc.loadNext();
    }

    function loadNext() {
        if (!svc.ready || nextProc.running)
            return;
        const c = svc.binPath();
        if (!c) return;
        nextProc.command = [c, "next", "--scripts", svc.scriptCsv,
                            "--types", svc.typeCsv];
        nextProc.running = true;
    }

    function refreshStats() {
        if (!svc.ready || statsProc.running)
            return;
        const c = svc.binPath();
        if (!c) return;
        statsProc.command = [c, "stats", "--scripts", svc.scriptCsv,
                             "--types", svc.typeCsv];
        statsProc.running = true;
    }

    function checkDict() {
        if (!svc.ready || dictStatusProc.running)
            return;
        const c = svc.binPath();
        if (!c) return;
        dictStatusProc.command = [c, "dict-status"];
        dictStatusProc.running = true;
    }

    // The only command that touches the network, and only on an explicit tap
    // with `online` already on.
    function fetchDict() {
        if (!svc.ready || !svc.online || dictFetchProc.running)
            return;
        const c = svc.binPath();
        if (!c) return;
        svc.dictBusy = true;
        dictFetchProc.command = [c, "dict-fetch", "--pack", svc.dictPack];
        dictFetchProc.running = true;
    }

    // Offline: queries the imported pack, never the network.
    function lookup(word) {
        if (!svc.ready || !word || lookupProc.running)
            return;
        svc.lookupWord = word;
        svc.lookupBusy = true;
        svc.lookupError = "";
        svc.lookupResult = "";
        const c = svc.binPath();
        if (!c) return;
        lookupProc.command = [c, "lookup", "--word", word];
        lookupProc.running = true;
    }

    function saveWord(word) {
        if (!svc.ready || !word || saveProc.running)
            return;
        if (svc.decksDir.length === 0) {
            svc.lookupError = "set a deck folder in Ryoku Hub first";
            return;
        }
        const c = svc.binPath();
        if (!c) return;
        saveProc.command = [c, "save", "--word", word,
                            "--decks-dir", svc.decksDir];
        saveProc.running = true;
    }

    function refreshDecks() {
        if (!svc.ready || decksProc.running)
            return;
        const c = svc.binPath();
        if (!c) return;
        decksProc.command = [c, "decks"];
        decksProc.running = true;
    }

    function reload() {
        if (!svc.ready || initProc.running)
            return;
        const c = svc.binPath();
        if (!c) return;
        svc.phase = "init";
        initProc.command = svc.decksDir.length > 0
            ? [c, "init", "--decks-dir", svc.decksDir]
            : [c, "init"];
        initProc.running = true;
    }

    // ---- process plumbing -------------------------------------------------

    // Returns null when there is nothing to parse. It used to return {} for an
    // empty reply, and {} reads as "no card, no reason" - which nextProc then
    // turned into "All caught up". An empty reply means the reply is MISSING
    // (StdioCollector can lose the race with onExited), not that the queue is
    // finished, so it must be a retry, never a state.
    function _parse(raw) {
        const text = (raw || "").trim();
        if (text.length === 0)
            return null;
        try {
            const line = text.split("\n").filter(l => l.trim().length > 0).pop();
            if (!line)
                return null;
            return JSON.parse(line);
        } catch (e) {
            return { ok: false, error: "unreadable reply from bin/kotoba" };
        }
    }

    property string _initOut: ""
    Process {
        id: initProc
        stdout: StdioCollector { id: initCol; onStreamFinished: svc._initOut = text }
        onExited: {
            const d = svc._parse(initCol.text || svc._initOut);
            svc._initOut = "";
            if (!d) { svc.reload(); return; }
            if (d.ok === false) {
                svc.errorText = d.error || "could not load decks";
                svc.phase = "error";
                return;
            }
            svc.totalCount = d.cards || 0;
            svc.loadNext();
            svc.refreshStats();
            svc.refreshDecks();
            svc.checkDict();
        }
    }

    property int _nextRetries: 0
    Timer {
        id: retryNext
        interval: 1500
        repeat: false
        onTriggered: svc.loadNext()
    }

    property string _nextOut: ""
    Process {
        id: nextProc
        stdout: StdioCollector { id: nextCol; onStreamFinished: svc._nextOut = text }
        onExited: {
            const d = svc._parse(nextCol.text || svc._nextOut);
            svc._nextOut = "";
            if (!d) {
                // reply lost - ask again shortly rather than inventing a state
                svc._nextRetries += 1;
                if (svc._nextRetries <= 5) {
                    retryNext.restart();
                } else {
                    svc.errorText = "no reply from bin/kotoba";
                    svc.phase = "error";
                }
                return;
            }
            svc._nextRetries = 0;
            if (d.ok === false) {
                svc.errorText = d.error || "could not pick a card";
                svc.phase = "error";
                return;
            }
            svc.reason = d.reason || "";
            if (d.card) {
                // only toast when the card actually changed, so re-picking the
                // same card after a settings change stays silent
                const changed = d.card.id !== svc._lastNotifiedCard;
                svc.card = d.card;
                svc.phase = "question";
                if (changed) {
                    svc._lastNotifiedCard = d.card.id;
                    svc.sendToast();
                }
                svc.nextCardIn = svc.intervalMin * 60;
            } else {
                svc.card = null;
                svc.nextDueIn = d.next_due
                    ? Math.max(0, d.next_due - (Date.now() / 1000))
                    : 0;
                svc.phase = (d.reason === "empty") ? "empty" : "caught-up";

                // STRICT PACING: the interval is a promise. A card due in five
                // minutes waits for the user's interval like any other; the
                // tile never decides on its own to interrupt sooner. The
                // "review now" button is how you ask for one early.
                svc.nextCardIn = svc.intervalMin * 60;
            }
            cardTimer.restart();
        }
    }

    property string _gradeOut: ""
    Process {
        id: gradeProc
        stdout: StdioCollector { id: gradeCol; onStreamFinished: svc._gradeOut = text }
        onExited: {
            const d = svc._parse(gradeCol.text || svc._gradeOut);
            svc._gradeOut = "";
            if (!d) { svc.refreshStats(); return; }
            if (d.ok === false) {
                svc.errorText = d.error || "could not save that answer";
                svc.phase = "error";
                return;
            }
            svc.refreshStats();
            if (svc.autoAdvance) {
                svc.loadNext();
            } else {
                svc.card = null;
                svc.phase = "waiting";
                svc.nextCardIn = svc.intervalMin * 60;
                cardTimer.restart();
            }
        }
    }

    property string _undoOut: ""
    Process {
        id: undoProc
        stdout: StdioCollector { id: undoCol; onStreamFinished: svc._undoOut = text }
        onExited: {
            const d = svc._parse(undoCol.text || svc._undoOut);
            svc._undoOut = "";
            if (!d) { svc.refreshStats(); return; }
            if (d.ok === false) {
                svc.errorText = d.error || "could not undo";
                return;
            }
            svc.undoInfo = null;
            // Show the restored card straight away so it can be re-graded.
            svc.loadNext();
            svc.refreshStats();
        }
    }

    // `notify-send -p` prints the new notification id; keep it so the next
    // toast can replace this one rather than accumulate.
    property string _notifyOut: ""
    Process {
        id: notifyProc
        stdout: StdioCollector { id: notifyCol; onStreamFinished: svc._notifyOut = text }
        onExited: {
            const n = parseInt((notifyCol.text || svc._notifyOut || "").trim(), 10);
            svc._notifyOut = "";
            if (!isNaN(n) && n > 0)
                svc.notifyId = n;
        }
    }

    property string _statsOut: ""
    Process {
        id: statsProc
        stdout: StdioCollector { id: statsCol; onStreamFinished: svc._statsOut = text }
        onExited: {
            const d = svc._parse(statsCol.text || svc._statsOut);
            svc._statsOut = "";
            if (!d) { /* stats will run again on its timer */; return; }
            if (d.ok === false)
                return;
            svc.dueCount = d.due || 0;
            svc.newCount = d.new || 0;
            svc.totalCount = d.total || 0;
            svc.reviewsToday = d.reviews_today || 0;
            svc.reviewsTotal = d.reviews_total || 0;
            svc.undoInfo = d.undo || null;

            // No self-correction here. The stale-phase bug it worked around is
            // fixed properly in _parse(); pulling a card the moment one came
            // due would override the user's interval, which is the whole point
            // of strict pacing.
            svc.nextDueIn = d.next_due_in_seconds || 0;
        }
    }

    property string _decksOut: ""
    Process {
        id: decksProc
        stdout: StdioCollector { id: decksCol; onStreamFinished: svc._decksOut = text }
        onExited: {
            const d = svc._parse(decksCol.text || svc._decksOut);
            svc._decksOut = "";
            if (!d) { /* cosmetic only */; return; }
            svc.deckList = Array.isArray(d.decks) ? d.decks : [];
        }
    }

    property string _dictOut: ""
    Process {
        id: dictStatusProc
        stdout: StdioCollector { id: dictStatusCol; onStreamFinished: svc._dictOut = text }
        onExited: {
            const d = svc._parse(dictStatusCol.text || svc._dictOut);
            svc._dictOut = "";
            if (!d) { /* checked again on next init */; return; }
            svc.dictReady = d.installed === true;
            svc.dictEntries = d.entries || 0;
            svc.dictPackInstalled = d.pack || "";
        }
    }

    property string _fetchOut: ""
    Process {
        id: dictFetchProc
        stdout: StdioCollector { id: dictFetchCol; onStreamFinished: svc._fetchOut = text }
        onExited: {
            const d = svc._parse(dictFetchCol.text || svc._fetchOut);
            svc._fetchOut = "";
            if (!d) { svc.checkDict(); return; }
            svc.dictBusy = false;
            if (d.ok === false)
                svc.lookupError = d.error || "could not install the dictionary";
            svc.checkDict();
        }
    }

    property string _lookupOut: ""
    Process {
        id: lookupProc
        stdout: StdioCollector { id: lookupCol; onStreamFinished: svc._lookupOut = text }
        onExited: {
            const d = svc._parse(lookupCol.text || svc._lookupOut);
            svc._lookupOut = "";
            if (!d) { /* user can retry */; return; }
            svc.lookupBusy = false;
            if (d.ok === false) {
                svc.lookupError = d.error || "lookup failed";
                svc.lookupHits = [];
                return;
            }
            svc.lookupHits = Array.isArray(d.results) ? d.results : [];
            if (svc.lookupHits.length === 0) {
                svc.lookupResult = "";
                svc.lookupError = "no match for " + d.word;
            } else {
                const h = svc.lookupHits[0];
                svc.lookupError = "";
                svc.lookupResult = h.jp + "  " + h.kana + "  \u00b7  " + h.en;
            }
        }
    }

    property string _saveOut: ""
    Process {
        id: saveProc
        stdout: StdioCollector { id: saveCol; onStreamFinished: svc._saveOut = text }
        onExited: {
            const d = svc._parse(saveCol.text || svc._saveOut);
            svc._saveOut = "";
            if (!d) { svc.refreshStats(); return; }
            if (d.ok === false) {
                svc.lookupError = d.error || "could not save";
                return;
            }
            svc.lookupResult = d.added
                ? "saved \u2713  " + d.total + " in your deck"
                : "already saved";
            svc.reload();
        }
    }

    // ---- timers -----------------------------------------------------------

    // The card clock. Only advances past a card the user has finished with;
    // an unanswered question is never swept away underneath them.
    Timer {
        id: cardTimer
        interval: 1000
        running: svc.ready
        repeat: true
        onTriggered: {
            if (svc.nextCardIn > 0)
                svc.nextCardIn -= 1;
            if (svc.nextDueIn > 0)
                svc.nextDueIn -= 1;
            if (svc.nextCardIn > 0)
                return;
            if (svc.phase === "waiting" || svc.phase === "caught-up" || svc.phase === "empty")
                svc.loadNext();
            else
                svc.nextCardIn = svc.intervalMin * 60;
        }
    }

    // Nothing should sit on "Loading decks". If it does, a Process was started
    // that never reported back, and its `running` flag is now blocking every
    // retry. Clear the flags and try again rather than stranding the tile.
    Timer {
        id: stuckWatchdog
        interval: 8000
        running: svc.ready && svc.phase === "init"
        repeat: true
        property int attempts: 0
        onTriggered: {
            if (svc.phase !== "init") {
                attempts = 0;
                return;
            }
            attempts += 1;
            if (attempts > 6) {
                svc.errorText = "bin/kotoba is not responding";
                svc.phase = "error";
                return;
            }
            initProc.running = false;
            nextProc.running = false;
            svc.reload();
        }
    }
    onPhaseChanged: if (phase !== "init") stuckWatchdog.attempts = 0

    // Keep the due counter honest while the user is away from the desktop.
    Timer {
        interval: 60000
        running: svc.ready
        repeat: true
        onTriggered: svc.refreshStats()
    }

    // First run, and again whenever the deck folder setting changes.
    onReadyChanged: if (ready) svc.reload()
    onDecksDirChanged: if (ready) svc.reload()

    // A filter change can invalidate the card on screen, so re-pick.
    onScriptCsvChanged: if (ready && phase !== "init") svc.loadNext()
    onTypeCsvChanged: if (ready && phase !== "init") svc.loadNext()
}
