pragma Singleton
pragma ComponentBehavior: Bound

import ".."
import "../modules/common"
import "../modules/common/models"
import "../modules/common/functions"
import "."
import QtQuick
import Quickshell
import Quickshell.Io
import shell.services as HostServices
import Ryoku.Ui.Singletons as RyokuUi

// The launcher engine, trimmed from the barstyle's LauncherSearch to the nine ported providers: apps (with frecency), calculator (qalc), clipboard and emojis (hosted panels via prefix), windows (Ryoku Wm facade), commands, web search (BrowserSites), file search (fd) and file content (ripgrep).
Singleton {
    id: root

    property string query: ""
    property string processConfirmKey: ""
    readonly property int browserSitesRevision: BrowserSites.revision
    // Persistent owns user-created aliases. Config remains the boot-time
    // fallback and compatibility mirror, but must not be the canonical source
    // once states.json is ready.
    readonly property var configuredAliases: {
        const userAliases = Array.from((Persistent.ready
            ? Persistent.states.search.aliases
            : Config.options.search.aliases) ?? []);
        return userAliases;
    }
    readonly property bool alwaysListAppsEnabled: Config.options.search.alwaysListApps

    onBrowserSitesRevisionChanged: root._scheduleResultsUpdate()
    onConfiguredAliasesChanged: root._scheduleResultsUpdate()

    // The result under the cursor, published by the list for the hero row.
    property var selectedResult: null

    // External tools. Probed once at startup: a missing binary degrades its
    // provider to "no results" instead of erroring per keystroke.
    property bool qalcAvailable: false
    property bool fdAvailable: false
    property bool rgAvailable: false

    Component.onCompleted: {
        root._probeBinaries();
        root._scheduleResultsUpdate();
    }

    function _probeBinaries() {
        binaryProbe.queue = [["qalc", v => root.qalcAvailable = v], ["fd", v => root.fdAvailable = v], ["rg", v => root.rgAvailable = v]];
        binaryProbe.runNext();
    }

    // One probe at a time: `command -v` per external tool, callback when done.
    Process {
        id: binaryProbe
        property var queue: []
        property var current: null

        function runNext() {
            if (binaryProbe.queue.length === 0) {
                binaryProbe.current = null;
                return;
            }
            binaryProbe.current = binaryProbe.queue.shift();
            binaryProbe.command = ["sh", "-c", "command -v " + binaryProbe.current[0] + " >/dev/null 2>&1"];
            binaryProbe.running = true;
        }

        onExited: function(exitCode, exitStatus) {
            if (binaryProbe.current && binaryProbe.current[1])
                binaryProbe.current[1](exitCode === 0);
            binaryProbe.runNext();
        }
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                closeTeardownTimer.stop();
                coldPurgeTimer.stop();
                // `query` is commonly already empty, so opening Search does not
                // emit onQueryChanged. Refresh the idle result set explicitly;
                // otherwise it can retain the empty result computed at boot.
                root._scheduleResultsUpdate();
            } else {
                closeTeardownTimer.restart();
            }
        }
    }

    // Closing tears the results down once the surface has gone, not as it
    // starts to go. Reopening inside the window cancels the teardown.
    Timer {
        id: closeTeardownTimer
        interval: 750
        repeat: false
        onTriggered: {
            if (GlobalStates.overviewOpen)
                return;
            root.rememberQuery(root.query);
            root.query = "";
            root.selectedResult = null;
            root.clearResults();
            coldPurgeTimer.restart();
        }
    }

    // The indexes behind the results stay warm between sessions and are
    // released only once Search has been left alone for a while.
    Timer {
        id: coldPurgeTimer
        interval: 5 * 60 * 1000
        repeat: false
        onTriggered: {
            if (root.hasResultConsumer)
                return;
            root.purgeWarmCaches();
        }
    }

    function purgeWarmCaches(): void {
        root.appResultCache = ({});
        root._publishedByKey = ({});
        Qt.callLater(root.collectReleasedResults);
    }

    function clearResults() {
        // Invalidate callbacks before stopping processes: termination can emit
        // their final output. Nothing from the old query may repopulate caches.
        root._fileSearchGeneration++;
        root._contentSearchGeneration++;
        nonAppResultsTimer.stop();
        fileSearchDebounce.stop();
        contentSearchDebounce.stop();
        contentPublishTimer.stop();
        mathProc.pendingExpression = "";
        mathProc.running = false;
        fileProc.running = false;
        contentProc.running = false;
        fileProc.pending = [];
        contentProc.pending = [];
        root.results = [];
        root.fileResults = [];
        root.allFileResults = [];
        root.contentResults = [];
        root._fileQuery = "";
        root._contentQuery = "";
        root._fileQueryPrefixed = false;
        root.mathResult = "";
        root.mathExpression = "";
        root.selectedResult = null;
        root.processConfirmKey = "";
        root.confirmKey = "";
        Qt.callLater(root.collectReleasedResults);
    }

    function collectReleasedResults(): void {
        if (!root.hasResultConsumer && typeof gc === "function")
            gc();
    }

    function enabledUtilityPrefixes(): var {
        const prefixes = Config.options.search.prefix;
        const values = [prefixes.action, prefixes.app];
        const modules = Config.options.search.modules;
        if (modules.fileSearch) values.push(prefixes.fileSearch);
        if (modules.fileContent) values.push(prefixes.fileContent);
        if (modules.math) values.push(prefixes.math);
        if (modules.shellCommand) values.push(prefixes.shellCommand);
        if (modules.webSearch) values.push(prefixes.webSearch);
        if (modules.windowSearch) values.push(prefixes.windowSearch);
        return values.filter(value => String(value ?? "").length > 0);
    }

    function ensurePrefix(prefix) {
        const knownPrefixes = SearchPanelRegistry.activePrefixes.concat(root.enabledUtilityPrefixes());
        if (knownPrefixes.some(existing => root.query.startsWith(existing))) {
            root.query = prefix + root.query.slice(1);
        } else {
            root.query = prefix + root.query;
        }
    }

    function normalizedAlias(value): string {
        return String(value ?? "").trim().toLowerCase();
    }

    // Starts a desktop entry through the host's AppLaunch so terminal apps
    // open in the user's terminal and the desktop's crash handler stays out
    // of the app's environment.
    function launchApplication(app): bool {
        if (!app)
            return false;
        AppUsage.recordLaunch(app.id);
        HostServices.AppLaunch.run(app, null);
        return true;
    }

    function aliasAvailable(entry): bool {
        const type = String(entry?.type ?? "");
        const target = String(entry?.target ?? "").trim();
        if (target.length === 0)
            return false;
        if (type === "app")
            return !!DesktopEntries.byId(target);
        if (type === "folder" || type === "command")
            return true;
        if (type !== "builtin")
            return false;
        const panel = SearchPanelRegistry.byId(target);
        if (panel)
            return panel.enabled();
        return target === "math" && Config.options.search.modules.math;
    }

    function executeAlias(entry): bool {
        if (!root.aliasAvailable(entry))
            return false;
        const type = String(entry?.type ?? "");
        const target = String(entry?.target ?? "").trim();
        if (type === "app")
            return root.launchApplication(DesktopEntries.byId(target));
        if (type === "folder") {
            Quickshell.execDetached(["xdg-open", target]);
            return false;
        }
        if (type === "command") {
            Quickshell.execDetached(["bash", "-c", target]);
            return false;
        }
        const panel = SearchPanelRegistry.byId(target);
        if (panel) {
            root.query = "";
            GlobalStates.openSearchPanel(panel.id);
            return true;
        }
        if (target === "math") {
            root.query = Config.options.search.prefix.math;
            return true;
        }
        return false;
    }

    function runCommandQuery(queryText: string) {
        let command = StringUtils.cleanPrefix(String(queryText ?? ""), Config.options.search.prefix.shellCommand).replace("file://", "");
        if (command.length === 0)
            return;
        Quickshell.execDetached(["bash", "-c", command.startsWith("sudo")
            ? `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(command)}'`
            : command]);
    }

    function openWebSearch(queryText: string) {
        const query = StringUtils.cleanPrefix(String(queryText ?? ""), Config.options.search.prefix.webSearch).trim();
        if (query.length === 0)
            return;
        let searchTerms = query;
        for (const site of Config.options.search.excludedSites)
            searchTerms += ` -site:${site}`;
        Qt.openUrlExternally(Config.options.search.engineBaseUrl + encodeURIComponent(searchTerms));
    }

    function askAiQuery(queryText: string) {
        // The AI chat panel is not part of this port; the empty state keeps
        // no Ask AI chip, so this only exists for the shared fallback path.
    }

    // The ported surface keeps a Connections handler for this; the launcher
    // has no settings window, so the signal stays and nobody answers it.
    signal requestOpenSettings

    function queryUsesPrefix(value) {
        const prefixes = SearchPanelRegistry.activePrefixes.concat(root.enabledUtilityPrefixes());
        return prefixes.some(prefix => String(value ?? "").startsWith(prefix));
    }

    // Application matching. Primary fuzzy pass over the desktop entries; the
    // typo tier (Myers bit-parallel edit distance) runs only when the primary
    // pass found nothing.
    function matchApplications(query: string): var {
        const primary = AppSearch.fuzzyQuery(query);
        const settings = Config.options.search.typoTolerance;
        const typosEnabled = settings?.enable === true;
        if (!typosEnabled || query.length === 0 || primary.length > 0)
            return primary;

        const seenIds = new Set();
        for (let i = 0; i < primary.length; i++)
            seenIds.add(primary[i].id);
        const extra = [];
        for (const entry of AppSearch.typoQuery(query)) {
            if (seenIds.has(entry.id))
                continue;
            seenIds.add(entry.id);
            extra.push(entry);
        }
        return primary.concat(extra);
    }

    function isMathQuery(expr) {
        if (!Config.options.search.modules.math)
            return false;
        const text = StringUtils.cleanPrefix(String(expr ?? ""), Config.options.search.prefix.math).trim();
        if (text.length === 0)
            return false;
        // Either an explicit math prefix, or a bare arithmetic expression.
        if (String(expr ?? "").startsWith(Config.options.search.prefix.math))
            return true;
        return /^[\d\s\+\-\*\/\(\)%\.,]+$/.test(text) && /[\+\-\*\/%]/.test(text)
            || /(\d|\))\s*(to|in)\s+\S+/.test(text);
    }

    // What people type, rewritten into what qalc parses.
    function normalizeMathExpression(expr: string): string {
        let text = String(expr ?? "").trim();
        const prefixMath = Config.options.search.prefix.math;
        if (prefixMath && text.startsWith(prefixMath))
            text = text.slice(prefixMath.length).trim();
        text = text.replace(/^hoje\b/i, "today").replace(/^agora\b/i, "now")
            .replace(/^amanh[aã]\b/i, "tomorrow").replace(/^ontem\b/i, "yesterday");
        text = text.replace(/(\d)\s*%\s+(?:of|de|do|da)\s+/gi, "$1% * ");
        const conversion = text.match(/^(.*\S)\s+(?:to|in|para|em|->)\s+(-?)(\S+)$/i);
        if (conversion) {
            const target = conversion[3];
            const namedFormat = /^(hex|bin|oct|base|bases|roman|fraction|time|utc|calendars?|factors|partial|optimal|prefix)$/i.test(target);
            text = `${conversion[1]} to ${namedFormat ? conversion[2] : "-"}${target}`;
        }
        return text;
    }

    function isCurrencyExpression(expr: string): bool {
        const text = String(expr ?? "");
        return /\b[A-Z]{3}\b/.test(text)
            || /[$€£¥₿]|\b(usd|brl|eur|gbp|jpy|btc|cad|aud|chf|ars|dollars?|euros?|reais|real|pounds?|yen)\b/i.test(text);
    }

    function recordCalculation(expression: string, result: string): void {
        const expressionText = String(expression ?? "").trim();
        const value = String(result ?? "").trim();
        if (value.length === 0 || !Persistent.ready)
            return;
        const kept = Array.from(Persistent.states.search.calculatorHistory ?? [])
            .filter(entry => String(entry?.expression ?? "") !== expressionText);
        kept.unshift({ expression: expressionText, result: value, time: Date.now() });
        Persistent.states.search.calculatorHistory = kept.slice(0, Math.max(1, Config.options.search.calculator.historyMaxItems));
    }

    function removeCalculation(index: int): void {
        const history = Array.from(Persistent.states.search.calculatorHistory ?? []);
        history.splice(index, 1);
        Persistent.states.search.calculatorHistory = history;
        root._scheduleResultsUpdate();
    }

    // The math prefix alone ("=") lists what was copied from the calculator.
    function calculatorHistoryResults(): var {
        const history = Array.from(Persistent.states.search.calculatorHistory ?? []);
        const rows = history.map((entry, index) => resultComp.createObject(null, {
            key: "math:history:" + String(entry?.time ?? index),
            name: String(entry?.result ?? ""),
            comment: String(entry?.expression ?? "") + " · " + Qt.formatDateTime(new Date(Number(entry?.time ?? 0)), Qt.locale().dateTimeFormat(Locale.ShortFormat)),
            type: Translation.tr("Calculator history"),
            verb: Translation.tr("Copy"),
            iconName: "history",
            iconType: LauncherSearchResult.IconType.Material,
            fontType: LauncherSearchResult.FontType.Monospace,
            execute: () => {
                Quickshell.clipboardText = String(entry?.result ?? "");
            },
            actions: [resultComp.createObject(null, {
                    name: Translation.tr("Edit expression"),
                    iconName: "edit",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        root.query = String(Config.options.search.prefix.math) + String(entry?.expression ?? "");
                    }
                }), resultComp.createObject(null, {
                    name: Translation.tr("Remove from history"),
                    iconName: "delete",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => root.removeCalculation(index)
                })]
        }));
        if (rows.length > 0) {
            rows.push(resultComp.createObject(null, {
                key: "math:history:clear",
                name: Translation.tr("Clear calculator history"),
                type: Translation.tr("Calculator history"),
                verb: Translation.tr("Clear"),
                iconName: "delete_sweep",
                iconType: LauncherSearchResult.IconType.Material,
                keepOverviewOpen: true,
                execute: () => {
                    Persistent.states.search.calculatorHistory = [];
                    root._scheduleResultsUpdate();
                }
            }));
        }
        return rows;
    }

    // Instantly evaluate simple arithmetic using JS — no qalc needed.
    // Only allows digits, basic operators, parens, dots, spaces — safe subset.
    // Shunting-yard replacement for the old eval() quick-math fallback.
// Same grammar: numbers, + - * / % parens, unary minus.
function __imiArithEvaluate(expr) {
    const tokens = [];
    let i = 0;
    while (i < expr.length) {
        const c = expr[i];
        if (c === " ") { i++; continue; }
        if (/[0-9.]/.test(c)) {
            let j = i;
            while (j < expr.length && /[0-9.]/.test(expr[j])) j++;
            tokens.push({ t: "num", v: parseFloat(expr.slice(i, j)) });
            i = j;
            continue;
        }
        if ("+-*/%()".indexOf(c) !== -1) {
            tokens.push({ t: c });
            i++;
            continue;
        }
        return null;
    }
    const prec = { "+": 1, "-": 1, "*": 2, "/": 2, "%": 2 };
    const out = [];
    const ops = [];
    let prevWasValue = false;
    for (const tok of tokens) {
        if (tok.t === "num") {
            out.push(tok.v);
            prevWasValue = true;
        } else if (tok.t === "(") {
            ops.push(tok);
            prevWasValue = false;
        } else if (tok.t === ")") {
            while (ops.length > 0 && ops[ops.length - 1].t !== "(")
                out.push(ops.pop().t);
            if (ops.length === 0) return null;
            ops.pop();
            prevWasValue = true;
        } else {
            // unary minus: value position start or after operator/open paren
            if (tok.t === "-" && !prevWasValue) {
                out.push(0);
                prevWasValue = true;
            }
            while (ops.length > 0 && prec[ops[ops.length - 1].t] >= prec[tok.t])
                out.push(ops.pop().t);
            ops.push(tok);
            prevWasValue = false;
        }
    }
    while (ops.length > 0) {
        if (ops[ops.length - 1].t === "(") return null;
        out.push(ops.pop().t);
    }
    const st = [];
    for (const t of out) {
        if (typeof t === "number") { st.push(t); continue; }
        if (st.length < 2) return null;
        const b = st.pop(), a = st.pop();
        if (t === "+") st.push(a + b);
        else if (t === "-") st.push(a - b);
        else if (t === "*") st.push(a * b);
        else if (t === "/") st.push(a / b);
        else if (t === "%") st.push(a % b);
    }
    return st.length === 1 && isFinite(st[0]) ? st[0] : null;
}

function jsEvalMath(expr) {
        expr = expr.trim();
        const prefixMath = Config.options.search.prefix.math;
        if (prefixMath && expr.startsWith(prefixMath))
            expr = expr.slice(prefixMath.length).trim();
        const isSafe = /^[\d\s\+\-\*\/\.\(\)%]+$/.test(expr);
        const hasOp = /[\+\-\*\/\%]/.test(expr);
        if (!isSafe || !hasOp)
            return null;
        const result = __imiArithEvaluate(expr);
        return result === null ? null : String(result);
    }



    property string mathExpression: ""

    Process {
        id: mathProc
        property string pendingExpression: ""
        function calculateExpression(expression) {
            if (!root.qalcAvailable)
                return;
            const normalized = root.normalizeMathExpression(expression);
            mathProc.running = false;
            mathProc.pendingExpression = normalized;
            const command = ["qalc", "-t"];
            // qalc answers from its last cached rates, however old. `-e`
            // fetches fresh ones first (about two seconds), so it is only paid
            // once a day, by the first currency conversion.
            const ratesAge = Date.now() - Number(Persistent.states.search.exchangeRatesUpdatedAt ?? 0);
            if (Config.options.search.calculator.updateExchangeRates && Persistent.ready
                    && root.isCurrencyExpression(normalized) && ratesAge > 24 * 60 * 60 * 1000) {
                command.push("-e");
                Persistent.states.search.exchangeRatesUpdatedAt = Date.now();
            }
            command.push(normalized);
            mathProc.command = command;
            mathProc.running = true;
        }
        stdout: StdioCollector {
            id: mathCollector
            onStreamFinished: {
                if (!root.hasResultConsumer || mathProc.pendingExpression.length === 0
                        || mathProc.pendingExpression !== root.normalizeMathExpression(root.query))
                    return;
                const r = mathCollector.text.trim();
                // qalc echoes back text it could not evaluate; that is no answer.
                if (r.length === 0 || r === mathProc.pendingExpression)
                    return;
                // A real conversion answers in the unit that was asked for: the
                // result names it or ends in its abbreviation.
                const conversion = mathProc.pendingExpression.match(/\sto\s+-?(\S+)$/);
                if (conversion) {
                    const target = conversion[1].toLowerCase();
                    const resultUnit = String(r.match(/([^\d\s.,+\-−×]+)\s*$/)?.[1] ?? "").toLowerCase();
                    const cleanUnit = resultUnit.replace(/[°º]/g, "");
                    const currencySign = /[$€£¥₺₹₽₩₿¢]/;
                    const isCurrency = (root.isCurrencyExpression(target) || /^[a-z]{3}$/i.test(target)) && currencySign.test(r);
                    const namesTarget = r.toLowerCase().includes(target)
                        || (resultUnit.length > 0 && target.startsWith(resultUnit))
                        || (cleanUnit.length > 0 && target.startsWith(cleanUnit))
                        || isCurrency;
                    if (!namesTarget)
                        return;
                }
                root.mathExpression = mathProc.pendingExpression;
                root.mathResult = r;
            }
        }
    }

    // ========== File search ==========
    //
    // The one provider that shells out and walks a directory tree. The query
    // queues a walk, the rest of the results render immediately, and the list
    // simply grows when files arrive.
    property var fileResults: []
    property var allFileResults: []
    property string _fileQuery: ""
    property bool _fileQueryPrefixed: false
    property int _fileSearchGeneration: 0
    readonly property string fileSearchQuery: root._fileQuery

    readonly property bool fileSearchInlineEnabled: Config.options.search.modules.fileSearch
        && (Config.options.search.fileSearch?.inlineResults ?? false)

    // Never worth walking from "/": virtual and volatile trees.
    readonly property var systemExcludedDirectories: ["/proc", "/sys", "/dev", "/run", "/tmp", "/var/tmp",
        "/var/cache", "/var/log", "/var/lib/flatpak", "/var/lib/containers", "/var/lib/docker",
        "/snap", "/nix", "/lost+found", "/boot"]

    // Where file and content walks start. Defaults to the home directory.
    function fileSearchRoot(): string {
        const configured = String(Config.options.search.fileSearchDirectory ?? "");
        return configured.length > 0 ? configured : FileUtils.trimFileProtocol(Directories.home);
    }

    function queryIsFileSearchPrefixed(query: string): bool {
        const prefix = String(Config.options.search.prefix.fileSearch ?? "");
        return Config.options.search.modules.fileSearch && prefix.length > 0 && query.startsWith(prefix);
    }

    // The expression the walk should run for, or "" for "do not walk".
    function fileSearchExpression(query: string): string {
        if (root.queryIsFileSearchPrefixed(query))
            return query.slice(String(Config.options.search.prefix.fileSearch).length).trim();
        if (!root.fileSearchInlineEnabled)
            return "";
        if (root.queryUsesPrefix(query) || root.isMathQuery(query))
            return "";
        return query.trim();
    }

    // fd's traversal order is not relevance order, so ordering is rebuilt here:
    // hits in the entry's own name first, shallow beats deep.
    function rankFilePaths(paths, query, limit): var {
        const tokens = String(query).toLowerCase().split(/\s+/).filter(token => token.length > 0);
        if (tokens.length === 0)
            return limit > 0 ? paths.slice(0, limit) : paths.slice();

        const scored = [];
        for (let i = 0; i < paths.length; i++) {
            const path = paths[i];
            const trimmed = path.endsWith("/") ? path.slice(0, -1) : path;
            const base = trimmed.slice(trimmed.lastIndexOf("/") + 1).toLowerCase();

            let matchedInName = 0;
            for (let t = 0; t < tokens.length; t++) {
                if (base.indexOf(tokens[t]) !== -1)
                    matchedInName++;
            }

            let score = matchedInName * 200;
            if (matchedInName === tokens.length)
                score += 300;
            if (base.startsWith(tokens[0]))
                score += 200;
            if (base === tokens.join(" "))
                score += 400;
            score -= trimmed.split("/").length * 8;
            score -= base.length;

            scored.push({
                path: path,
                score: score
            });
        }
        scored.sort((a, b) => b.score - a.score);

        const ranked = [];
        const count = limit > 0 ? Math.min(scored.length, limit) : scored.length;
        for (let i = 0; i < count; i++)
            ranked.push(scored[i].path);
        return ranked;
    }

    function shortenHomePath(path: string): string {
        const home = FileUtils.trimFileProtocol(Directories.home);
        if (home.length > 0 && path.startsWith(home))
            return "~" + path.slice(home.length);
        return path;
    }

    // Symbol per file kind, consulted for every file row of every update.
    readonly property var fileIconsByExtension: {
        const groups = [
            ["image", ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tif", "tiff", "svg", "svgz", "ico", "avif", "heic", "heif", "psd", "xcf", "raw", "cr2", "nef", "dng"]],
            ["movie", ["mp4", "mkv", "webm", "mov", "avi", "flv", "wmv", "m4v", "mpg", "mpeg", "3gp", "ogv", "ts", "m2ts"]],
            ["music_note", ["mp3", "flac", "wav", "ogg", "opus", "m4a", "aac", "wma", "aiff", "mid", "midi"]],
            ["picture_as_pdf", ["pdf"]],
            ["folder_zip", ["zip", "tar", "gz", "bz2", "xz", "zst", "7z", "rar", "tgz", "txz", "tbz", "lz4", "iso", "img", "dmg"]],
            ["article", ["doc", "docx", "odt", "rtf", "pages"]],
            ["table", ["xls", "xlsx", "ods", "csv", "tsv", "numbers"]],
            ["slideshow", ["ppt", "pptx", "odp", "key"]],
            ["description", ["txt", "md", "rst", "org", "log", "adoc", "tex", "nfo"]],
            ["code", ["qml", "js", "mjs", "cjs", "jsx", "ts", "tsx", "py", "rs", "go", "c", "h", "cpp", "hpp", "cc", "cxx", "java", "kt", "kts", "swift", "rb", "php", "lua", "pl", "sh", "bash", "zsh", "fish", "vim", "el", "scm", "hs", "ml", "ex", "exs", "dart", "scala", "r", "css", "scss", "html", "htm", "vue", "svelte"]],
            ["data_object", ["json", "jsonc", "yaml", "yml", "toml", "ini", "conf", "cfg", "xml", "plist", "env", "properties"]],
            ["database", ["db", "sqlite", "sqlite3", "sql", "parquet"]],
            ["font_download", ["ttf", "otf", "woff", "woff2", "ttc", "pfb"]],
            ["menu_book", ["epub", "mobi", "azw3", "djvu", "fb2", "cbz", "cbr"]],
            ["deployed_code", ["appimage", "exe", "msi", "deb", "rpm", "pkg", "apk", "flatpakref", "snap", "blend", "obj", "stl", "fbx", "gltf", "glb"]],
            ["subtitles", ["srt", "vtt", "ass", "ssa", "sub"]],
            ["key", ["pem", "crt", "cer", "gpg", "asc", "kdbx", "p12", "pub"]],
            ["hard_drive", ["qcow2", "vdi", "vmdk", "vhd", "vhdx"]],
            ["difference", ["patch", "diff"]],
            ["launch", ["desktop"]],
            ["science", ["ipynb"]],
            ["downloading", ["torrent"]]
        ];
        const map = ({});
        for (let g = 0; g < groups.length; g++) {
            const icon = groups[g][0];
            const extensions = groups[g][1];
            for (let e = 0; e < extensions.length; e++)
                map[extensions[e]] = icon;
        }
        return map;
    }

    // Formats Qt can decode for the row thumbnail. Deliberately narrower than
    // the icon map: an extension we cannot draw must fall back to its symbol.
    readonly property var previewableExtensions: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tif", "tiff", "svg", "ico"]

    function fileExtensionOf(name: string): string {
        const dot = String(name).lastIndexOf(".");
        return dot > 0 ? String(name).slice(dot + 1).toLowerCase() : "";
    }

    function fileResultIcon(name: string, isDirectory: bool): string {
        if (isDirectory)
            return "folder";
        return root.fileIconsByExtension[root.fileExtensionOf(name)] ?? "draft";
    }

    // Path to draw in the row's icon slot, or "" to use the symbol.
    function fileResultPreview(path: string, isDirectory: bool): string {
        if (isDirectory || Config.options.search.blurFileSearchResultPreviews)
            return "";
        return root.previewableExtensions.indexOf(root.fileExtensionOf(path)) !== -1 ? path : "";
    }

    Timer {
        id: fileSearchDebounce
        // The rest of the results are already on screen by the time this fires,
        // and a burst of keystrokes starts one walk instead of one per letter.
        interval: 200
        repeat: false
        onTriggered: fileProc.searchFiles(root._fileQuery, root._fileSearchGeneration)
    }

    Process {
        id: fileProc
        property int activeSearchGeneration: 0
        property var pending: []

        // Whitespace-separated tokens become an ordered "contains" pattern, so
        // "project logo" finds "Project - Logo.png". Every token is regex
        // escaped: the query is user text, not a pattern.
        function searchPattern(expression) {
            return String(expression).trim().split(/\s+/)
                .filter(token => token.length > 0)
                .map(token => token.replace(/[.*+?^${}()|[\]\\\/-]/g, "\\$&"))
                .join(".*");
        }

        function searchFiles(expression, generation) {
            if (!root.fdAvailable)
                return;
            const pattern = fileProc.searchPattern(expression);
            if (pattern.length === 0)
                return;
            const settings = Config.options.search.fileSearch;
            // Completeness matters before ranking: capping fd makes exact
            // matches disappear simply because unrelated paths were emitted
            // first. Threads still bound the desktop impact.
            const command = ["fd", "--color", "never", "--absolute-path"];
            const threads = Math.max(0, settings?.threads ?? 4);
            if (threads > 0)
                command.push("--threads", String(threads));
            // An explicit prefixed query is allowed to reach as deep as it likes.
            const maxDepth = root._fileQueryPrefixed ? 0 : Math.max(0, settings?.maxDepth ?? 0);
            if (maxDepth > 0)
                command.push("--max-depth", String(maxDepth));
            if (settings?.includeHidden === true)
                command.push("--hidden");
            const excluded = settings?.excludedDirectories ?? [];
            for (let i = 0; i < excluded.length; i++) {
                const directory = String(excluded[i] ?? "");
                if (directory.length > 0)
                    command.push("--exclude", directory);
            }
            const directory = root.fileSearchRoot();
            if (directory === "/") {
                for (const systemDirectory of root.systemExcludedDirectories)
                    command.push("--exclude", systemDirectory);
            }
            command.push(pattern, directory);

            fileProc.running = false;
            fileProc.pending = [];
            fileProc.activeSearchGeneration = generation;
            fileProc.command = command;
            fileProc.running = true;
        }

        stdout: SplitParser {
            onRead: line => {
                if (fileProc.activeSearchGeneration === root._fileSearchGeneration && line.length > 0)
                    fileProc.pending.push(line);
            }
        }

        onExited: {
            if (fileProc.activeSearchGeneration !== root._fileSearchGeneration)
                return;
            const lines = fileProc.pending;
            fileProc.pending = [];
            const settings = Config.options.search.fileSearch;
            root.allFileResults = root.rankFilePaths(lines, root._fileQuery, 0);
            const limit = root._fileQueryPrefixed
                ? root.allFileResults.length
                : Math.max(1, settings?.maxResults ?? 8);
            const next = root.allFileResults.slice(0, limit);
            if (next.length !== root.fileResults.length
                    || next.some((path, index) => path !== root.fileResults[index]))
                root.fileResults = next;
        }
    }

    // ========== File content search ==========
    //
    // ripgrep, prefix-only: reading file contents costs far more than fd's
    // name walk, so an ordinary query never starts it. Matches stream in,
    // are published in small batches, and the walk is stopped at the cap.
    property var contentResults: []
    property string _contentQuery: ""
    property int _contentSearchGeneration: 0

    function queryIsContentSearchPrefixed(query: string): bool {
        const prefix = String(Config.options.search.prefix.fileContent ?? "");
        return Config.options.search.modules.fileContent && prefix.length > 0 && String(query ?? "").startsWith(prefix);
    }

    function contentSearchExpression(query: string): string {
        if (!root.queryIsContentSearchPrefixed(query))
            return "";
        return query.slice(String(Config.options.search.prefix.fileContent).length).trim();
    }

    function createContentResult(match): var {
        const path = String(match.path);
        const separator = path.lastIndexOf("/");
        const displayName = path.slice(separator + 1);
        const parent = separator > 0 ? path.slice(0, separator) : "/";
        const lineText = String(match.text ?? "");
        return resultComp.createObject(null, {
            key: "fcontent:" + path + ":" + match.line,
            type: Translation.tr("File"),
            name: displayName,
            comment: Translation.tr("%1 · line %2: %3").arg(root.shortenHomePath(parent)).arg(String(match.line)).arg(lineText),
            category: "filepath",
            filePath: path,
            verb: Translation.tr("Open"),
            iconName: root.fileResultIcon(displayName, false),
            iconType: LauncherSearchResult.IconType.Material,
            fallbackIconName: root.fileResultIcon(displayName, false),
            execute: () => {
                Quickshell.execDetached(["xdg-open", path]);
            },
            actions: [resultComp.createObject(null, {
                    name: Translation.tr("Copy matching line"),
                    iconName: "format_quote",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Quickshell.clipboardText = lineText;
                    }
                }), resultComp.createObject(null, {
                    name: Translation.tr("Copy path"),
                    iconName: "content_copy",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Quickshell.clipboardText = path;
                    }
                }), resultComp.createObject(null, {
                    name: Translation.tr("Open folder"),
                    iconName: "folder_open",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Quickshell.execDetached(["xdg-open", parent]);
                    }
                })]
        });
    }

    Timer {
        id: contentSearchDebounce
        interval: 300
        repeat: false
        onTriggered: contentProc.searchContent(root._contentQuery, root._contentSearchGeneration)
    }

    // Publishing per line would rebuild the whole result list per match.
    Timer {
        id: contentPublishTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (contentProc.activeSearchGeneration === root._contentSearchGeneration)
                root.contentResults = contentProc.pending.slice();
        }
    }

    Process {
        id: contentProc
        property int activeSearchGeneration: 0
        property var pending: []
        // A unit separator never appears in a path, unlike the default ":".
        readonly property string fieldSeparator: "\u001f"

        function searchContent(expression, generation) {
            if (!root.rgAvailable)
                return;
            const text = String(expression ?? "").trim();
            if (text.length === 0)
                return;
            const settings = Config.options.search.fileContent;
            const command = ["rg", "--color", "never", "--no-heading", "--with-filename", "--line-number",
                "--field-match-separator", contentProc.fieldSeparator,
                "--max-count", "1", "--max-columns", "240", "--max-columns-preview",
                "--smart-case", "--fixed-strings",
                "--max-filesize", Math.max(1, settings.maxFileSizeMb) + "M"];
            const threads = Math.max(0, Config.options.search.fileSearch?.threads ?? 4);
            if (threads > 0)
                command.push("--threads", String(threads));
            const excluded = Config.options.search.fileSearch?.excludedDirectories ?? [];
            for (let i = 0; i < excluded.length; i++) {
                const directory = String(excluded[i] ?? "");
                if (directory.length > 0)
                    command.push("--glob", "!" + directory);
            }
            // `--` keeps a query that starts with "-" from being read as a flag.
            command.push("--", text, root.fileSearchRoot());

            contentProc.running = false;
            contentProc.pending = [];
            contentProc.activeSearchGeneration = generation;
            contentProc.command = command;
            contentProc.running = true;
        }

        stdout: SplitParser {
            onRead: line => {
                if (contentProc.activeSearchGeneration !== root._contentSearchGeneration)
                    return;
                const limit = Math.max(1, Config.options.search.fileContent.maxResults);
                if (contentProc.pending.length >= limit)
                    return;
                const first = line.indexOf(contentProc.fieldSeparator);
                const second = first >= 0 ? line.indexOf(contentProc.fieldSeparator, first + 1) : -1;
                if (second < 0)
                    return;
                contentProc.pending.push({
                    path: line.slice(0, first),
                    line: Number(line.slice(first + 1, second)),
                    text: line.slice(second + 1).trim()
                });
                if (contentProc.pending.length >= limit)
                    contentProc.running = false;
                if (!contentPublishTimer.running)
                    contentPublishTimer.start();
            }
        }

        onExited: {
            if (contentProc.activeSearchGeneration === root._contentSearchGeneration)
                contentPublishTimer.restart();
        }
    }

    // ========== Window Search ==========
    //
    // Over the host's Wm facade: one window list on every compositor, and
    // focus/close actions that ride the shell daemon. No compositor-specific
    // service anywhere.
    function getWindowResults(searchString) {
        const windows = RyokuUi.Wm.windows || [];
        if (searchString === "")
            return windows;
        const lower = searchString.toLowerCase();
        return windows.filter(w => {
            const title = (w.title || "").toLowerCase();
            const appId = (w.appId || "").toLowerCase();
            return title.includes(lower) || appId.includes(lower);
        });
    }

    function appResultKey(app) {
        return "app:" + (app && app.id ? app.id : "");
    }

    // Application rows depend only on their desktop entry, and that list
    // changes on a rescan — not on a keystroke. Sharing the objects also lets
    // the result list's diff reuse an unchanged row without rebinding it.
    property var appResultCache: ({})

    Connections {
        target: AppSearch
        function onListChanged() {
            root.appResultCache = ({});
            // Desktop entries are populated asynchronously. An empty query has
            // no keystroke to trigger another pass, so publish the newly ready
            // catalogue immediately for always-list-apps mode.
            root._scheduleResultsUpdate();
        }
    }

    function createBrowserSiteResult(site: var): var {
        const url = String(site?.url ?? "");
        const title = String(site?.title || site?.host || url);
        const siteSource = String(site?.source ?? (site?.bookmarked === true ? "favorite" : "suggested"));
        // The completed index already carries every cache hit. Prefer that
        // immutable value so a result is never published between the `sites`
        // and `faviconSources` property updates.
        const indexedFavicon = String(site?.favicon ?? "");
        const favicon = indexedFavicon.startsWith("file://")
            ? indexedFavicon
            : BrowserSites.faviconFor(site);
        const tabCount = Math.max(1, Number(site?.tabCount ?? 1));
        const detail = siteSource === "open" && tabCount > 1
            ? String(tabCount) + " " + Translation.tr("open tabs") + " • " + url
            : url;
        const actions = [
            resultComp.createObject(null, {
                name: Translation.tr("Copy URL"),
                iconName: "link",
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => Quickshell.clipboardText = url
            }),
            resultComp.createObject(null, {
                name: Translation.tr("Copy title"),
                iconName: "content_copy",
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => Quickshell.clipboardText = title
            })
        ];
        if (BrowserSites.privateBrowsingSupported) {
            actions.push(resultComp.createObject(null, {
                name: Translation.tr("Open in private window"),
                iconName: "visibility_off",
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => BrowserSites.openPrivateWindow(url)
            }));
        }
        return resultComp.createObject(null, {
            key: "site:" + url,
            name: title,
            comment: detail,
            type: siteSource === "open"
                ? Translation.tr("Open tab")
                : (siteSource === "favorite"
                    ? Translation.tr("Favorite")
                    : Translation.tr("Suggested")),
            verb: Translation.tr("Open"),
            iconName: favicon.length > 0 ? favicon : "public",
            iconType: favicon.length > 0
                ? LauncherSearchResult.IconType.Image
                : LauncherSearchResult.IconType.Material,
            fallbackIconName: siteSource === "open"
                ? "tab"
                : (siteSource === "favorite" ? "bookmark" : "history"),
            siteSource: siteSource,
            pinnable: false,
            execute: () => Qt.openUrlExternally(url),
            actions: actions
        });
    }

    // Continuation rows. Built at the point of use: all of them used to be
    // allocated on every keystroke and then thrown away on the common path.
    function createCommandResultObject(): var {
        const query = root.query;
        return resultComp.createObject(null, {
            key: "cmd:shell",
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.shellCommand).replace("file://", ""),
            verb: Translation.tr("Run"),
            type: Translation.tr("Command"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'terminal',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => root.runCommandQuery(query)
        });
    }

    function createWebSearchResultObject(): var {
        const query = root.query;
        return resultComp.createObject(null, {
            key: "web:search",
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch),
            verb: Translation.tr("Search"),
            type: Translation.tr("Web search"),
            iconName: 'travel_explore',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => root.openWebSearch(query)
        });
    }

    function createAppResultObject(entry) {
        const cached = root.appResultCache[entry.id];
        if (cached)
            return cached;
        const result = root.buildAppResultObject(entry);
        root.appResultCache[entry.id] = result;
        return result;
    }

    function buildAppResultObject(entry) {
        return resultComp.createObject(null, {
            key: root.appResultKey(entry),
            type: Translation.tr("App"),
            id: entry.id,
            name: entry.name,
            iconName: AppSearch.entryIcon(entry),
            iconType: LauncherSearchResult.IconType.System,
            verb: Translation.tr("Open"),
            execute: () => root.launchApplication(entry),
            comment: entry.comment,
            runInTerminal: entry.runInTerminal,
            genericName: entry.genericName,
            keywords: entry.keywords,
            actions: entry.actions.map(action => {
                return resultComp.createObject(null, {
                    name: action.name,
                    iconName: action.icon,
                    iconType: LauncherSearchResult.IconType.System,
                    execute: () => HostServices.AppLaunch.run(entry, action)
                });
            })
        });
    }

    function searchPanelMatches(queryText: string): var {
        const terms = String(queryText ?? "").trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
        if (terms.length === 0)
            return [];
        return SearchPanelRegistry.enabledPanels.filter(panel => {
            const searchable = [panel.id, panel.label, ...(panel.keywords ?? [])]
                .join(" ").toLocaleLowerCase();
            return terms.every(term => searchable.includes(term));
        });
    }

    function createSearchPanelResult(panel, fallbackFlag) {
        const isFallback = fallbackFlag === true;
        return resultComp.createObject(null, {
            key: (isFallback ? "fallback:panel:" : "panel:") + panel.id,
            name: panel.label,
            iconName: panel.icon,
            iconType: LauncherSearchResult.IconType.Material,
            type: Translation.tr("Search panel"),
            verb: Translation.tr("Open"),
            comment: Translation.tr("Search tools"),
            panelId: panel.id,
            isFallback: isFallback,
            keepOverviewOpen: true,
            execute: () => {
                root.query = "";
                root.recordPanelUse(panel.id);
                GlobalStates.openSearchPanel(panel.id);
            }
        });
    }

    function rememberQuery(value) {
        if (!Persistent.ready)
            return;
        const query = String(value ?? "").trim();
        if (query.length === 0)
            return;
        const prior = Array.from(Persistent.states.search.recentQueries ?? []).filter(item => item !== query);
        Persistent.states.search.recentQueries = [query].concat(prior).slice(0, 50);
    }

    function recentQuery(offset) {
        const entries = Array.from(Persistent.states.search.recentQueries ?? []);
        return offset >= 0 && offset < entries.length ? String(entries[offset]) : "";
    }

    function recordPanelUse(panelId) {
        if (!Persistent.ready)
            return;
        const rows = Array.from(Persistent.states.search.panelUsage ?? []);
        const id = String(panelId ?? "");
        const previous = rows.find(row => String(row?.id ?? "") === id) ?? ({ id: id, count: 0 });
        const next = rows.filter(row => String(row?.id ?? "") !== id);
        next.unshift({ id: id, count: Number(previous.count ?? 0) + 1, usedAt: Date.now() });
        Persistent.states.search.panelUsage = next.slice(0, 64);
    }

    function toggleFavorite(result) {
        if (!result?.pinnable || !result?.key || !Persistent.ready)
            return false;
        const key = String(result.key);
        if (!/^(app:|panel:)/.test(key))
            return false;
        const prior = Array.from(Persistent.states.search.pinnedEntries ?? []);
        Persistent.states.search.pinnedEntries = prior.includes(key)
            ? prior.filter(entry => entry !== key)
            : [key].concat(prior).slice(0, 24);
        return true;
    }

    function favoriteResults() {
        const results = [];
        for (const key of Array.from(Persistent.states.search.pinnedEntries ?? [])) {
            if (key.startsWith("app:")) {
                const app = DesktopEntries.byId(key.slice(4));
                if (app)
                    results.push(root.createAppResultObject(app));
                continue;
            }
            if (key.startsWith("panel:")) {
                const panel = SearchPanelRegistry.byId(key.slice(6));
                if (panel?.enabled())
                    results.push(root.createSearchPanelResult(panel));
                continue;
            }
        }
        return results.map(result => Object.assign({}, result, { pinned: true, type: Translation.tr("Favorite") }));
    }

    // ========== Result keybinds ==========
    //
    // Ctrl+letter shortcuts the user binds to any result from its More actions.
    readonly property var resultKeybinds: Persistent.ready ? Array.from(Persistent.states.search.resultKeybinds ?? []) : []
    readonly property bool resultKeybindsEnabled: Config.options.search.resultKeybinds?.enable ?? true

    function keybindableKey(result): string {
        let key = String(result?.key ?? "");
        if (key.startsWith("suggested:"))
            key = key.slice("suggested:".length);
        // Rows whose value changes with every query cannot be summoned later.
        if (key.length === 0 || result?.isFallback === true || /^(math:|fallback:|clip:|cmd:shell|web:search|ai:ask)/.test(key))
            return "";
        return key;
    }

    // Ctrl+K and Ctrl+P act on Search itself; A, C, V, X and Z edit the query.
    function reservedKeybindLetters(): var {
        const reserved = ["a", "c", "k", "p", "v", "x", "z"];
        for (const binding of Array.from(Config.options.search.keybindings ?? [])) {
            const actionId = String(binding?.actionId ?? "");
            const match = String(binding?.shortcut ?? "").replace(/\s+/g, "").toLowerCase().match(/^(?:ctrl|control)\+([a-z])$/);
            if (match && (actionId === "actions" || actionId === "favorite") && reserved.indexOf(match[1]) === -1)
                reserved.push(match[1]);
        }
        return reserved;
    }

    function keybindForKey(key: string): var {
        return root.resultKeybinds.find(binding => String(binding?.key ?? "") === key) ?? null;
    }

    function keybindForLetter(letter: string): var {
        const wanted = String(letter ?? "").toLowerCase();
        return root.resultKeybinds.find(binding => String(binding?.letter ?? "") === wanted) ?? null;
    }

    function setResultKeybind(result, letter: string): bool {
        const key = root.keybindableKey(result);
        const wanted = String(letter ?? "").toLowerCase();
        if (!Persistent.ready || key.length === 0 || !/^[a-z]$/.test(wanted) || root.reservedKeybindLetters().indexOf(wanted) !== -1)
            return false;
        // One letter per result and one result per letter: rebinding replaces both.
        const kept = root.resultKeybinds.filter(binding => binding?.key !== key && binding?.letter !== wanted);
        kept.push({
            letter: wanted,
            key: key,
            name: String(result?.name ?? ""),
            type: String(result?.type ?? ""),
            iconName: String(result?.iconName ?? ""),
            iconType: Number(result?.iconType ?? 0),
            filePath: String(result?.filePath ?? ""),
            query: String(root.query ?? "")
        });
        Persistent.states.search.resultKeybinds = kept.sort((a, b) => String(a.letter).localeCompare(String(b.letter)));
        return true;
    }

    function removeResultKeybind(letter: string): void {
        if (!Persistent.ready)
            return;
        const wanted = String(letter ?? "").toLowerCase();
        Persistent.states.search.resultKeybinds = root.resultKeybinds.filter(binding => binding?.letter !== wanted);
    }

    function resolveResultKeybind(binding): var {
        const key = String(binding?.key ?? "");
        if (key.startsWith("app:")) {
            const app = DesktopEntries.byId(key.slice(4));
            return app ? root.createAppResultObject(app) : null;
        }
        if (key.startsWith("panel:")) {
            const panel = SearchPanelRegistry.byId(key.slice(6));
            return panel?.enabled() ? root.createSearchPanelResult(panel) : null;
        }
        const filePath = String(binding?.filePath ?? "");
        if (filePath.length > 0 && /^(fsearch:|fcontent:|file:)/.test(key)) {
            return resultComp.createObject(null, {
                key: key,
                name: String(binding?.name ?? filePath),
                filePath: filePath,
                execute: () => {
                    Quickshell.execDetached(["xdg-open", filePath]);
                }
            });
        }
        root.query = String(binding?.query ?? "");
        return root._computeResults().find(result => root.keybindableKey(result) === key) ?? null;
    }

    function runResultKeybind(letter: string): bool {
        if (!root.resultKeybindsEnabled)
            return false;
        const binding = root.keybindForLetter(letter);
        if (!binding)
            return false;
        const previousQuery = root.query;
        const result = root.resolveResultKeybind(binding);
        if (!result) {
            root.query = previousQuery;
            Quickshell.execDetached(["notify-send", "-a", "Shell", Translation.tr("Search keybind"),
                Translation.tr("Ctrl+%1 points to “%2”, which is no longer available").arg(String(binding.letter).toUpperCase()).arg(String(binding.name ?? ""))]);
            return true;
        }
        SearchResultActions.build(result, {})[0].execute();
        // Rows that keep Search open (panels) must not leave the lookup query
        // behind in the field. Panels clear it themselves.
        if (GlobalStates.overviewOpen && root.query !== previousQuery && !String(binding.key).startsWith("panel:"))
            root.query = previousQuery;
        return true;
    }

    // ========== Aliases from results ==========
    //
    // More actions → Add alias writes the same { alias, type, target } entries
    // for the result kinds an alias can open: apps, Search panels and folders.
    function aliasTargetFor(result): var {
        const key = root.keybindableKey(result);
        if (key.startsWith("app:"))
            return { type: "app", target: key.slice(4) };
        if (key.startsWith("panel:"))
            return { type: "builtin", target: key.slice(6) };
        const filePath = String(result?.filePath ?? "");
        const isDirectory = String(result?.type ?? "") === Translation.tr("Directory") || key.endsWith("/");
        if (isDirectory && filePath.length > 0)
            return { type: "folder", target: filePath };
        return null;
    }

    function aliasMatchesTarget(entry, target): bool {
        return String(entry?.type ?? "") === target.type && String(entry?.target ?? "") === target.target;
    }

    function aliasForResult(result): var {
        const target = root.aliasTargetFor(result);
        if (!target)
            return null;
        return root.configuredAliases.find(entry => root.aliasMatchesTarget(entry, target)) ?? null;
    }

    function writeAliases(aliases): void {
        if (Persistent.ready)
            Persistent.states.search.aliases = aliases;
        if (Config.ready)
            Config.options.search.aliases = aliases;
    }

    /** Returns "" once saved; otherwise the reason it was not. */
    function saveAliasForResult(result, aliasText: string): string {
        const target = root.aliasTargetFor(result);
        const alias = String(aliasText ?? "").trim();
        if (!target)
            return Translation.tr("This result cannot have an alias");
        if (alias.length === 0)
            return Translation.tr("Type an alias first");
        if (/\s/.test(alias))
            return Translation.tr("An alias is a single word");
        if (root.queryUsesPrefix(alias))
            return Translation.tr("“%1” starts with a Search prefix").arg(alias);
        const normalized = root.normalizedAlias(alias);
        const clash = root.configuredAliases.find(entry => root.normalizedAlias(entry?.alias) === normalized && !root.aliasMatchesTarget(entry, target));
        if (clash)
            return Translation.tr("“%1” already opens %2").arg(alias).arg(String(clash.target ?? ""));
        // One alias per target: saving again renames it.
        const kept = root.configuredAliases.filter(entry => !root.aliasMatchesTarget(entry, target));
        kept.push({ alias: alias, type: target.type, target: target.target });
        root.writeAliases(kept);
        return "";
    }

    function removeAliasForResult(result): void {
        const target = root.aliasTargetFor(result);
        if (target)
            root.writeAliases(root.configuredAliases.filter(entry => !root.aliasMatchesTarget(entry, target)));
    }

    Timer {
        id: nonAppResultsTimer
        interval: Math.max(150, Config.options.search.nonAppResultDelay)
        onTriggered: {
            let expr = root.query;
            if (expr.startsWith(Config.options.search.prefix.math))
                expr = expr.slice(Config.options.search.prefix.math.length);
            mathProc.calculateExpression(expr);
        }
    }

    onQueryChanged: {
        root.selectedResult = null;
        root.processConfirmKey = "";
        root._fileSearchGeneration++;
        nonAppResultsTimer.stop();
        contentPublishTimer.stop();
        mathProc.pendingExpression = "";
        fileProc.pending = [];
        contentProc.pending = [];
        fileProc.running = false;
        mathProc.running = false;

        // Files are the slow lane: a process launch and a filesystem walk. The
        // walk is queued, never run from the keystroke itself.
        const fileExpression = root.fileSearchExpression(root.query);
        root._fileQueryPrefixed = root.queryIsFileSearchPrefixed(root.query);
        const fileMinimum = root._fileQueryPrefixed
            ? 2
            : Math.max(2, Config.options.search.fileSearch?.minimumQueryLength ?? 3);
        if (fileExpression.length >= fileMinimum) {
            if (root._fileQuery !== fileExpression) {
                if (root.fileResults.length > 0)
                    root.fileResults = [];
                if (root.allFileResults.length > 0)
                    root.allFileResults = [];
            }
            root._fileQuery = fileExpression;
            fileSearchDebounce.restart();
        } else {
            fileSearchDebounce.stop();
            root._fileQuery = "";
            if (root.fileResults.length > 0)
                root.fileResults = [];
            if (root.allFileResults.length > 0)
                root.allFileResults = [];
        }

        // Content search follows the same queue-and-cancel shape as files.
        root._contentSearchGeneration++;
        contentProc.running = false;
        const contentExpression = root.contentSearchExpression(root.query);
        if (contentExpression.length >= Math.max(2, Config.options.search.fileContent.minimumQueryLength)) {
            if (root._contentQuery !== contentExpression && root.contentResults.length > 0)
                root.contentResults = [];
            root._contentQuery = contentExpression;
            contentSearchDebounce.restart();
        } else {
            contentSearchDebounce.stop();
            root._contentQuery = "";
            if (root.contentResults.length > 0)
                root.contentResults = [];
        }

        if (!root.isMathQuery(root.query)) {
            root.mathResult = "";
        } else {
            // Try instant JS eval first for simple arithmetic
            const instant = root.jsEvalMath(root.query);
            if (instant !== null) {
                root.mathExpression = root.normalizeMathExpression(root.query);
                root.mathResult = instant;
            } else {
                root.mathResult = "";
                nonAppResultsTimer.restart();
            }
        }
        root.confirmKey = "";

        root._scheduleResultsUpdate();
    }

    // The expression the visible math result answers, for its row and history.
    property string mathResult: ""
    property string confirmKey: ""

    property var results: []
    property bool _resultsUpdateQueued: false

    // Whether anything is actually going to read the next result set.
    readonly property bool hasResultConsumer: GlobalStates.overviewOpen || root.query.length > 0

    function _scheduleResultsUpdate() {
        if (root._resultsUpdateQueued)
            return;

        root._resultsUpdateQueued = true;
        Qt.callLater(function () {
            root._resultsUpdateQueued = false;
            if (root.hasResultConsumer) {
                root.results = root._reuseUnchangedResults(root._computeResults());
            }
        });
    }

    // The last published set, by key, so the next one can be compared to it.
    property var _publishedByKey: ({})

    // Fields a row is drawn from, or acts on.
    readonly property var comparedResultFields: ["type", "name", "comment", "verb", "iconName",
        "iconType", "fallbackIconName", "fontType", "category", "rawValue", "filePath", "panelId",
        "siteSource", "feedbackText", "controlKind", "controlValue", "id", "isMath", "isBuiltin",
        "isAlias", "isFallback", "keepOverviewOpen", "pinned", "pinnable", "blurImage", "shown",
        "runInTerminal", "genericName"]

    function _resultsEquivalent(left, right): bool {
        const fields = root.comparedResultFields;
        for (let i = 0; i < fields.length; i++) {
            if (left[fields[i]] !== right[fields[i]])
                return false;
        }
        const leftActions = left.actions ?? [];
        const rightActions = right.actions ?? [];
        if (leftActions.length !== rightActions.length)
            return false;
        for (let i = 0; i < leftActions.length; i++) {
            if (leftActions[i]?.name !== rightActions[i]?.name
                    || leftActions[i]?.iconName !== rightActions[i]?.iconName)
                return false;
        }
        return true;
    }

    // Keep the previous object for every row that did not actually change,
    // so the list diff rebinds no delegate for a row that is the same.
    function _reuseUnchangedResults(next): var {
        const previous = root._publishedByKey;
        const byKey = ({});
        for (let i = 0; i < next.length; i++) {
            const candidate = next[i];
            if (!candidate)
                continue;
            const key = String(candidate.key ?? "");
            if (key.length === 0)
                continue;
            const existing = previous[key];
            // Application rows are already shared out of `appResultCache`, so
            // the previous pass can hand back the very object being offered.
            if (existing && existing !== candidate && root._resultsEquivalent(existing, candidate))
                next[i] = existing;
            byKey[key] = next[i];
        }
        root._publishedByKey = byKey;
        return next;
    }

    // Re-schedule when reactive sources (other than query) change
    onMathResultChanged: _scheduleResultsUpdate()
    onFileResultsChanged: _scheduleResultsUpdate()
    onContentResultsChanged: _scheduleResultsUpdate()

    // The idle Search home screen: aliases, every app, the registered panels
    // and a short frecency strip, built out of the same result shapes a typed
    // query uses so one ListView renders both.
    function _computeIdleSuggestions(): var {
        const cfg = Config.options.search.suggestions;
        let result = [];

        if (cfg.showAliases) {
            for (const entry of root.configuredAliases) {
                if (!root.aliasAvailable(entry))
                    continue;
                const panel = entry.type === "builtin" ? SearchPanelRegistry.byId(entry.target) : null;
                // App icons are system icon-theme names, not Material Symbol
                // glyphs — the two IconType values are not interchangeable.
                const isAppAlias = entry.type === "app";
                const icon = panel?.icon
                    ?? (isAppAlias ? (DesktopEntries.byId(entry.target)?.icon ?? "apps")
                        : entry.type === "folder" ? "folder"
                        : entry.type === "command" ? "terminal" : "label");
                result.push(resultComp.createObject(null, {
                    key: "alias:" + String(entry.alias ?? ""),
                    name: entry.alias ?? "",
                    comment: panel?.label ?? entry.target ?? "",
                    type: Translation.tr("Alias"),
                    iconName: icon,
                    iconType: isAppAlias ? LauncherSearchResult.IconType.System : LauncherSearchResult.IconType.Material,
                    isAlias: true,
                    keepOverviewOpen: entry.type === "folder" || entry.type === "builtin",
                    execute: () => root.executeAlias(entry)
                }));
            }
        }

        if (cfg.showApps) {
            for (const app of AppSearch.list)
                result.push(root.createAppResultObject(app));
        }

        if (cfg.showPanels) {
            for (const panel of SearchPanelRegistry.enabledPanels)
                result.push(root.createSearchPanelResult(panel));
        }

        if (cfg.showFrecency) {
            const cap = Math.max(2, cfg.maxSuggestionsPerSection ?? 5);
            const candidates = [];
            for (const fav of root.favoriteResults())
                candidates.push({ score: Number.POSITIVE_INFINITY, ref: fav });
            for (const app of AppSearch.list) {
                const score = AppUsage.getScore(app.id);
                if (score > 0)
                    candidates.push({ score, ref: root.createAppResultObject(app) });
            }
            if (Persistent.ready) {
                for (const row of Array.from(Persistent.states.search.panelUsage ?? [])) {
                    const panel = SearchPanelRegistry.byId(String(row?.id ?? ""));
                    if (panel?.enabled())
                        candidates.push({ score: Number(row?.count ?? 0), ref: root.createSearchPanelResult(panel) });
                }
            }
            candidates.sort((a, b) => b.score - a.score);

            const seenKeys = new Set();
            const suggested = [];
            for (const candidate of candidates) {
                const key = String(candidate.ref?.key ?? "");
                if (key.length === 0 || seenKeys.has(key))
                    continue;
                seenKeys.add(key);
                suggested.push(Object.assign({}, candidate.ref, { key: "suggested:" + key }));
                if (suggested.length >= cap)
                    break;
            }
            result = suggested.concat(result);
        }

        return result;
    }

    function _computeResults() {
        let _apps = AppSearch.list; // Keep reference for reactive tracking (unused directly)

        ////////////////// Empty query //////////////////
        if (root.query === "") {
            if (Config.options.search.alwaysListApps) {
                const appResultObjects = AppSearch.fuzzyQuery("").slice(0, 60).map(entry => root.createAppResultObject(entry));
                return appResultObjects;
            }

            if (Config.options.search.suggestions.enable)
                return root._computeIdleSuggestions();

            return [];
        }

        ///////////// Prefix-owned modes ///////////////
        // The clipboard and emoji prefixes resolve to their hosted panels,
        // which read their own sources; building result rows here would only
        // be hidden behind them.
        if (Config.options.search.modules.clipboard && root.query.startsWith(Config.options.search.prefix.clipboard)) {
            return [];
        }
        if (Config.options.search.modules.emojis.enable && root.query.startsWith(Config.options.search.prefix.emojis)) {
            return [];
        }
        if (Config.options.search.modules.windowSearch && root.query.startsWith(Config.options.search.prefix.windowSearch)) {
            const searchString = root.query.slice(Config.options.search.prefix.windowSearch.length);
            const windows = getWindowResults(searchString);
            return windows.map(w => {
                return resultComp.createObject(null, {
                    key: "win:" + (w.id ?? w.title ?? w.appId),
                    name: w.title || w.appId || "Unknown",
                    type: Translation.tr("Window"),
                    verb: Translation.tr("Focus"),
                    iconName: AppSearch.guessIcon(w.appId || ""),
                    iconType: LauncherSearchResult.IconType.System,
                    comment: `${w.appId || ""} — ${w.workspace || ""}`,
                    execute: () => {
                        RyokuUi.Wm.focusWindow(w.id);
                    },
                    actions: [resultComp.createObject(null, {
                            name: Translation.tr("Close"),
                            iconName: "close",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                RyokuUi.Wm.closeWindow(w.id);
                            }
                        }), resultComp.createObject(null, {
                            name: Translation.tr("Copy title"),
                            iconName: "content_copy",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Quickshell.clipboardText = w.title || w.appId || "";
                            }
                        })]
                });
            }).filter(Boolean);
        }

        ////////////////// Init ///////////////////
        const queryLower = root.query.toLowerCase();
        const queryTrimmed = root.query.trim();
        const queryTrimmedLower = queryTrimmed.toLowerCase();
        const queryHasPrefix = root.queryUsesPrefix(root.query);

        const mathResultObject = root.mathResult ? resultComp.createObject(null, {
            key: "math:" + root.mathResult,
            name: root.mathResult,
            verb: Translation.tr("Copy"),
            type: Translation.tr("Math result"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'calculate',
            iconType: LauncherSearchResult.IconType.Material,
            isMath: true,
            comment: root.mathExpression,
            // Captured now: running the row closes Search first, and the
            // query reset that follows clears `mathResult` before this runs.
            execute: ((result, expression) => () => {
                Quickshell.clipboardText = result;
                root.recordCalculation(expression, result);
            })(root.mathResult, root.mathExpression)
        }) : null;

        const fileResultsObject = !Config.options.search.modules.fileSearch ? [] : root.fileResults.map(entry => {
            // fd already marks directories with a trailing separator, so the
            // type comes back for free — no stat, no second process.
            const isDirectory = entry.endsWith("/");
            const path = isDirectory ? entry.slice(0, -1) : entry;
            const separator = path.lastIndexOf("/");
            const displayName = separator >= 0 ? path.slice(separator + 1) : path;
            const parent = separator > 0 ? path.slice(0, separator) : "/";
            const preview = root.fileResultPreview(path, isDirectory);
            return resultComp.createObject(null, {
                key: "fsearch:" + entry,
                // "Directory" is the type SearchItem keys its folder actions off.
                type: isDirectory ? Translation.tr("Directory") : Translation.tr("File"),
                name: displayName,
                comment: root.shortenHomePath(parent),
                category: "filepath",
                filePath: path,
                verb: Translation.tr("Open"),
                iconName: preview.length > 0 ? preview : root.fileResultIcon(displayName, isDirectory),
                iconType: preview.length > 0 ? LauncherSearchResult.IconType.Image : LauncherSearchResult.IconType.Material,
                fallbackIconName: root.fileResultIcon(displayName, isDirectory),
                execute: () => {
                    Quickshell.execDetached(["xdg-open", path]);
                },
                actions: [resultComp.createObject(null, {
                        name: Translation.tr("Copy path"),
                        iconName: "content_copy",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.clipboardText = path;
                        }
                    }), resultComp.createObject(null, {
                        name: isDirectory ? Translation.tr("Open in file manager") : Translation.tr("Open folder"),
                        iconName: "folder_open",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached(["xdg-open", isDirectory ? path : parent]);
                        }
                    })]
            });
        });

        // `,` is an explicit request for files. Without this the prefix is fed
        // to the app fuzzy matcher too, and unrelated apps bury the file rows.
        if (root.queryIsFileSearchPrefixed(root.query))
            return fileResultsObject;
        if (root.queryIsContentSearchPrefixed(root.query))
            return root.contentResults.map(match => root.createContentResult(match));
        if (Config.options.search.modules.math && queryTrimmed === String(Config.options.search.prefix.math))
            return root.calculatorHistoryResults();

        const appQuery = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.app);
        const appResultObjects = root.matchApplications(appQuery).slice(0, 60).map(entry => root.createAppResultObject(entry));
        const browserSiteSearchActive = !queryHasPrefix;
        const browserSiteResultObjects = browserSiteSearchActive
            ? BrowserSites.matchSites(root.query).map(site => root.createBrowserSiteResult(site))
            : [];

        //////// Prioritized by prefix /////////
        let result = [];

        if (queryTrimmed.length === 0)
            result = result.concat(root.favoriteResults());

        // App/Folder/Command Aliases
        const aliases = root.configuredAliases;
        const normalizedAliasQuery = root.normalizedAlias(root.query);
        const aliasObjects = aliases.map(entry => {
            if (normalizedAliasQuery.length > 0
                    && root.normalizedAlias(entry?.alias) === normalizedAliasQuery
                    && root.aliasAvailable(entry)) {
                if (entry.type === "app") {
                    const app = DesktopEntries.byId(entry.target);
                    if (app) {
                        return resultComp.createObject(null, {
                            key: root.appResultKey(app),
                            id: app.id,
                            name: app.name,
                            iconName: app.icon,
                            iconType: LauncherSearchResult.IconType.System,
                            verb: Translation.tr("Open"),
                            type: Translation.tr("App Alias"),
                            isAlias: true,
                            execute: () => root.executeAlias(entry)
                        });
                    }
                } else if (entry.type === "folder") {
                    return resultComp.createObject(null, {
                        key: "alias:" + entry.alias,
                        name: entry.target,
                        iconName: "folder",
                        iconType: LauncherSearchResult.IconType.Material,
                        verb: Translation.tr("Open"),
                        type: Translation.tr("Folder Alias"),
                        isAlias: true,
                        comment: entry.target,
                        execute: () => root.executeAlias(entry)
                    });
                } else if (entry.type === "command") {
                    return resultComp.createObject(null, {
                        key: "alias:" + entry.alias,
                        name: entry.target,
                        iconName: "terminal",
                        iconType: LauncherSearchResult.IconType.Material,
                        verb: Translation.tr("Run"),
                        type: Translation.tr("Command Alias"),
                        isAlias: true,
                        execute: () => root.executeAlias(entry)
                    });
                } else if (entry.type === "builtin") {
                    let icon = "explore";
                    let typeName = Translation.tr("Mode");
                    let name = entry.target;
                    const registeredPanel = SearchPanelRegistry.byId(entry.target);

                    if (registeredPanel) {
                        icon = registeredPanel.icon;
                        name = registeredPanel.label;
                        typeName = Translation.tr("Search panel");
                    } else if (entry.target === "math") {
                        icon = "calculate";
                        name = Translation.tr("Calculator");
                    }

                    return resultComp.createObject(null, {
                        key: "mock:" + entry.target,
                        name: name,
                        iconName: icon,
                        iconType: LauncherSearchResult.IconType.Material,
                        verb: Translation.tr("Open"),
                        type: typeName,
                        comment: Translation.tr("Alias: ") + entry.alias,
                        isBuiltin: true,
                        isAlias: true,
                        execute: () => root.executeAlias(entry)
                    });
                }
            }
            return null;
        }).filter(Boolean);
        result = result.concat(aliasObjects);

        const isMath = root.isMathQuery(root.query);
        const startsWithShellCommandPrefix = Config.options.search.modules.shellCommand
            && root.query.startsWith(Config.options.search.prefix.shellCommand);
        const startsWithWebSearchPrefix = Config.options.search.modules.webSearch
            && root.query.startsWith(Config.options.search.prefix.webSearch);

        if (isMath && mathResultObject) {
            result.push(mathResultObject);
        } else if (startsWithShellCommandPrefix) {
            result.push(root.createCommandResultObject());
        } else if (startsWithWebSearchPrefix) {
            result.push(root.createWebSearchResultObject());
        }

        //////////////// Files /////////////////
        result = result.concat(fileResultsObject);

        //////////////// Apps //////////////////
        result = result.concat(appResultObjects);

        //////////////// Sites //////////////////
        result = result.concat(browserSiteResultObjects);

        // Panels with no prefix stay discoverable through explicit, compact
        // rows; their query is preserved as the panel's own filter.
        if (queryTrimmed.length >= 2) {
            for (const panel of root.searchPanelMatches(root.query))
                result.push(root.createSearchPanelResult(panel));
        }

        ////////// Module shortcuts ////////////
        // Typing a mode name shows a shortcut to switch to it, unless its
        // prefix is owned by a registered panel (those resolve themselves).
        if (queryLower.length >= 2) {
            const owned = SearchPanelRegistry.activePrefixes;
            const shortcuts = [
                { names: ["clipboard", "clip", "paste"], prefix: Config.options.search.prefix.clipboard, label: Translation.tr("Clipboard"), icon: "content_paste", enabled: () => Config.options.search.modules.clipboard },
                { names: ["emoji", "emojis", "emoticon"], prefix: Config.options.search.prefix.emojis, label: Translation.tr("Emojis"), icon: "mood", enabled: () => Config.options.search.modules.emojis.enable },
                { names: ["window", "windows"], prefix: Config.options.search.prefix.windowSearch, label: Translation.tr("Window Search"), icon: "select_window", enabled: () => Config.options.search.modules.windowSearch },
                { names: ["math", "calc", "calculator"], prefix: Config.options.search.prefix.math, label: Translation.tr("Calculator"), icon: "calculate", enabled: () => Config.options.search.modules.math },
                { names: ["command", "commands", "terminal", "shell"], prefix: Config.options.search.prefix.shellCommand, label: Translation.tr("Shell Command"), icon: "terminal", enabled: () => Config.options.search.modules.shellCommand },
                { names: ["file", "files"], prefix: Config.options.search.prefix.fileSearch, label: Translation.tr("File search"), icon: "folder_open", enabled: () => Config.options.search.modules.fileSearch },
                { names: ["web", "search the web"], prefix: Config.options.search.prefix.webSearch, label: Translation.tr("Web search"), icon: "travel_explore", enabled: () => Config.options.search.modules.webSearch }
            ];
            for (const mod of shortcuts) {
                if (!mod.enabled() || owned.indexOf(mod.prefix) !== -1)
                    continue;
                if (!mod.names.some(n => n.startsWith(queryLower)))
                    continue;
                result.push(resultComp.createObject(null, {
                    key: "shortcut:" + mod.label,
                    name: mod.label,
                    type: Translation.tr("Built-in"),
                    verb: Translation.tr("Switch"),
                    iconName: mod.icon,
                    iconType: LauncherSearchResult.IconType.Material,
                    isBuiltin: true,
                    execute: () => {
                        root.query = mod.prefix;
                    }
                }));
            }
        }

        /// Command and web continuations ///
        // The normal Search keeps these as its final section even when other
        // classes matched: a sentence may be both an app/file match and a
        // web question, and a command name may resemble an installed app.
        // Explicit prefixes own their result set and must not receive this pair.
        const showNormalContinuations = Config.options.search.prefix.showDefaultActionsWithoutPrefix
            && queryTrimmed.length > 0
            && !queryHasPrefix;
        if (showNormalContinuations) {
            if (Config.options.search.modules.shellCommand && !startsWithShellCommandPrefix)
                result.push(root.createCommandResultObject());
            if (Config.options.search.modules.webSearch && !startsWithWebSearchPrefix)
                result.push(root.createWebSearchResultObject());
        }

        // Filter out duplicate original apps/folders/commands if an alias is shown.
        const normalizedActiveAliasQuery = root.normalizedAlias(root.query);
        const activeAliases = root.configuredAliases.filter(entry => normalizedActiveAliasQuery.length > 0
            && root.normalizedAlias(entry?.alias) === normalizedActiveAliasQuery);
        const activeAppAliasIds = new Set(activeAliases
            .filter(alias => alias.type === "app")
            .map(alias => {
                const app = DesktopEntries.byId(alias.target);
                return app ? app.id : alias.target;
            }));

        if (activeAliases.length > 0) {
            result = result.filter(item => {
                if (!item || !item.key)
                    return false;
                for (const alias of activeAliases) {
                    if (alias.type === "app" && item.isAlias !== true && item.key.startsWith("app:") && activeAppAliasIds.has(item.key.slice(4)))
                        return false;
                    if (alias.type === "folder" && item.key.startsWith("fsearch:")) {
                        const filePath = item.filePath || "";
                        const homePath = FileUtils.trimFileProtocol(Directories.home);
                        const targetNormalized = alias.target.startsWith("/") ? alias.target : alias.target.startsWith("~") ? alias.target.replace("~", homePath) : homePath + "/" + alias.target;
                        const cleanFilePath = filePath.replace(/\/+$/, "");
                        const cleanTarget = targetNormalized.replace(/\/+$/, "");
                        if (cleanFilePath.length > 0 && cleanFilePath === cleanTarget)
                            return false;
                    }
                }
                return true;
            });
        }

        return result;
    }

    function createResult(properties) {
        return {
            key: properties.key || "",
            type: properties.type || "",
            fontType: properties.fontType !== undefined ? properties.fontType : LauncherSearchResult.FontType.Normal,
            name: properties.name || "",
            rawValue: properties.rawValue || "",
            iconName: properties.iconName || "",
            iconType: properties.iconType !== undefined ? properties.iconType : LauncherSearchResult.IconType.None,
            verb: properties.verb || "",
            blurImage: !!properties.blurImage,
            pinned: !!properties.pinned,
            execute: properties.execute || (() => {
                    print("Not implemented");
                }),
            actions: properties.actions || [],
            id: properties.id || "",
            shown: properties.shown !== undefined ? properties.shown : true,
            comment: properties.comment || "",
            runInTerminal: !!properties.runInTerminal,
            genericName: properties.genericName || "",
            keywords: properties.keywords || [],
            isMath: !!properties.isMath,
            isBuiltin: !!properties.isBuiltin,
            isAlias: !!properties.isAlias,
            isFallback: !!properties.isFallback,
            keepOverviewOpen: !!properties.keepOverviewOpen,
            requiresConfirmation: !!properties.requiresConfirmation,
            controlKind: properties.controlKind || "",
            controlValue: properties.controlValue ?? null,
            panelId: properties.panelId || "",
            pinnable: properties.pinnable !== undefined ? properties.pinnable : true,
            matchTerms: properties.matchTerms || [],
            category: properties.category || properties.type || "",
            settingRef: properties.settingRef ?? null,
            keyHints: properties.keyHints ?? [],
            feedbackText: properties.feedbackText || "",
            filePath: properties.filePath || "",
            fallbackIconName: properties.fallbackIconName || "",
            siteSource: properties.siteSource || ""
        };
    }

    readonly property var resultComp: {
        "createObject": function (parent, properties) {
            return root.createResult(properties);
        }
    }
}
