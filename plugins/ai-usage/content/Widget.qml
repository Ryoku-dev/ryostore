import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// content/Widget.qml — the DETAIL surface of ai-usage.
//
// Host: framePopout (density "full"). The shell DRAWS the popout body
// (Popout.qml -> bodyBlob: BlobRect with Theme.radiusWindow and the theme's
// border), so THIS FILE DRAWS NO FRAME AND NO BACKGROUND. Drawing our own on top
// stacked TWO frames: since our radius (20) was smaller than the host's, the
// opaque corner invaded the area the shell had rounded — the "square corner /
// opaque background" the real smoke test called out.
//
// Rules this file obeys:
//   R4    — only QtQuick + Ryoku.PluginKit{,.Singletons}; nothing outside the folder.
//   R5    — settings read through pluginApi.pluginSettings BEHIND a default.
//   R8    — nothing is written here: the collector is pure stdout.
//   Tactical — JetBrains Mono tracked caps ONLY in short telemetry (cooldown,
//           percentage, metric label); one live accent per screen; no bounce
//           (only short OutExpo); no emoji.
//   stale/error NEVER by colour alone — always with a word (contrast is legibility).
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "full"
    property real s: 1
    property real widthBudget: 0
    // Total height this item may occupy, in the same scaled pixels as
    // `widthBudget`. The host does not pass one today (measured on ryoku 1.0.9:
    // `PluginPopouts.qml` only sets `widthBudget`), so 0 means "derive it from
    // the screen". It exists so a host — or a test — can state the limit
    // instead of the view guessing it.
    property real heightBudget: 0


    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var model: service ? service.model : null
    readonly property var primaryProvider: model ? model.primary : null
    readonly property var secondaryProviders: model && model.secondary ? model.secondary : []

    // The pills the grid actually draws. `maxSecondary` is enforced by the
    // collector (it limits the list BEFORE serializing, so `model.secondary` is
    // usually already cut), but the view applies it too: the guarantee "at most N
    // pills" must not depend on which producer handed us the model. Without this,
    // a model from any other source made the grid draw more pills than the
    // setting allows while the header counted a different number.
    readonly property int maxSecondaryCount: {
        var v = cfg ? Number(cfg.maxSecondary) : NaN;
        // Same rule as the service's `maxSecondary`, character for character:
        // a negative value is NOT "zero" — it falls back to the default 6, the
        // same way a non-numeric one does. The service clamps before the argv,
        // so a mismatch here would show a number the collector never produced
        // (measured: `-2` rendered 0 pills instead of 6).
        return (isFinite(v) && v >= 0) ? Math.min(v, 12) : 6;
    }
    readonly property var visibleSecondaries: {
        var all = root.secondaryProviders;
        if (!all) return [];
        var n = root.maxSecondaryCount;
        return all.length > n ? all.slice(0, n) : all;
    }
    readonly property int totalSecondary: {
        var n = model ? Number(model.total_providers) : NaN;
        return isFinite(n) ? Math.max(0, n - (primaryProvider ? 1 : 0)) : secondaryProviders.length;
    }
    readonly property string lastError: service ? service.lastError : ""
    readonly property string errorKind: service ? (service.errorKind || "") : ""

    // The numbers on screen come from an earlier read, and the LATEST read failed.
    // Keeping the last good model is deliberate (a transient failure must not blank
    // the panel), but showing it silently would be the lie the previous version was
    // trying to avoid. This property is what makes keeping it honest: it drives a
    // visible warning and a warning-coloured footer.
    readonly property bool staleData: root.errorKind !== "" && root.primaryProvider !== null

    // R5: always behind a default.
    readonly property var cfg: pluginApi ? pluginApi.pluginSettings : null
    readonly property int pad: {
        var v = cfg ? Number(cfg.padding) : NaN;
        return isFinite(v) ? Math.max(0, Math.min(32, Math.round(v))) : 12;
    }
    readonly property int gap: {
        var v = cfg ? Number(cfg.gap) : NaN;
        return isFinite(v) ? Math.max(2, Math.min(24, Math.round(v))) : 6;
    }
    readonly property bool showSecondary: cfg ? cfg.showSecondaries !== false : true

    // ---- type scale -----------------------------------------------------------
    // SEVEN steps lived between 7.5 and 10, most of them 0.5px apart. At a glance
    // 7.5 / 8 / 8.5 / 9 / 9.5 / 10 are the same weight, so the panel had no
    // hierarchy at all: the provider name, the quota label, the value and the
    // helper prose all read as one block. That is what "esperava um layout um
    // pouco mais distribuído" describes (Att2, 2026-10-29).
    //
    // Five ROLES, each a visible step apart (ratio ~1.15 minimum, which is what
    // survives a 1x display):
    //   display  the provider name — the one thing the eye should find first
    //   title    a section marker (OUTROS PROVEDORES)
    //   value    the reading that carries a number (the % outside a bar)
    //   body     quota labels and the three readings — the working text
    //   meta     timestamps, counts, footer prose — the smallest, still legible
    //
    // Every step multiplies `s`, so the ratios survive the user's scaling.
    readonly property real fsDisplay: 15 * s
    readonly property real fsTitle: 10 * s
    readonly property real fsValue: 11 * s
    readonly property real fsBody: 9 * s
    readonly property real fsMeta: 8 * s
    // There is deliberately NO half-step between `meta` and `body`. An earlier
    // revision had `fsReading: 8.5` for the three readings, which reproduced the
    // exact defect this scale exists to remove: 0.5px is not a step, it is noise
    // (measured: meta 8 / reading 8.5, ratio 1.06 — indistinguishable).
    // The three readings ARE body text; they share `fsBody`.
    readonly property bool showDetail: cfg ? cfg.showMetricDetail !== false : true
    readonly property string secondaryLabelMode: {
        var mode = cfg && cfg.secondaryLabel ? String(cfg.secondaryLabel) : "name";
        return ["name", "short", "plan"].indexOf(mode) >= 0 ? mode : "name";
    }
    // Slight indent of each secondary's block: the separator line sits flush left
    // and the content steps in, so the eye does not read every provider as one
    // line. Small on purpose — it is breathing room, not a new hierarchy.
    readonly property real secondaryIndent: 8 * s

    readonly property color accentColor: {
        var mode = cfg && cfg.accent ? String(cfg.accent) : "wallpaper";
        if (mode === "brand") return Theme.sun;
        if (mode === "mono") return Theme.cream;
        return Theme.accent;
    }

    // ---- i18n ---------------------------------------------------------------
    // The plugin CANNOT use Ryoku's I18n: R4 rejects `import Ryoku.Ui`
    // (plugin_audit.go:228, "internal-import") and I18n lives under
    // Ryoku.Ui.Singletons; PluginKit does not re-export it. Reading the shell's own config file to
    // learn the shell's language is ALSO blocked (R5, plugin_audit.go:428, even
    // for a read). So the plugin carries its own catalogue, read from
    // `pluginApi.pluginDir` — a field the host exposes (docs/plugins.md:285).
    //
    // Source-string-as-key, the same contract as Ryoku's own I18n: a missing key
    // returns the ENGLISH key itself, never "" and never "TODO". The UI can never
    // break because a translation is incomplete.
    // English is the DEFAULT and the source of truth (decision R3-v1). "auto" is
    // available for whoever wants the UI to follow the session locale, but it is
    // not the default: a plugin's language should not silently depend on the
    // machine it happens to run on.
    readonly property string languageSetting: {
        var v = cfg && cfg.language ? String(cfg.language) : "en";
        return ["auto", "en", "es", "fr", "pt", "pt_BR"].indexOf(v) >= 0 ? v : "en";
    }

    // "auto" derives from Qt.locale(), which DOES work inside a plugin (measured:
    // returned "pt_BR" in an offline harness). `pt_BR` keeps its region; any
    // other locale falls back to the part before the underscore; an unknown
    // language resolves to English.
    readonly property string language: {
        if (root.languageSetting !== "auto") return root.languageSetting;
        var name = String(Qt.locale().name || "");
        if (name === "") return "en";
        var full = name.replace("-", "_");
        if (full.toLowerCase() === "pt_br") return "pt_BR";
        var base = full.split("_")[0].toLowerCase();
        return ["en", "es", "fr", "pt"].indexOf(base) >= 0 ? base : "en";
    }

    // The catalogue for the active language. Kept in a property so the whole view
    // re-evaluates when the language changes — no restart, no manual reload.
    property var catalogue: ({})

    FileView {
        id: catalogueFile
        path: root.pluginApi && root.pluginApi.pluginDir
              ? root.pluginApi.pluginDir + "/content/i18n/" + root.language + ".json"
              : ""
        watchChanges: false
        onLoaded: {
            try {
                root.catalogue = JSON.parse(catalogueFile.text());
            } catch (e) {
                // A malformed catalogue degrades to English rather than blanking
                // the UI: the keys ARE the English strings.
                console.log("ai-usage: could not parse " + path + ": " + e);
                root.catalogue = ({});
            }
        }
        onLoadFailed: (e) => { root.catalogue = ({}); }
    }

    // Translate a source string. `%1` is the only substitution used (counts and
    // times), kept because translators often need to reorder it.
    // Translate a source string. `%1`, `%2`… are positional substitutions, kept
    // because translators often need to reorder them. Extra arguments are ignored
    // when the string has no placeholder, so a partial translation never leaves a
    // literal `%2` on screen.
    function tr(key, arg1, arg2, arg3) {
        var s = root.catalogue ? root.catalogue[key] : null;
        if (s === null || s === undefined || s === "") s = key;
        s = String(s);
        var args = [arg1, arg2, arg3];
        for (var i = 0; i < args.length; i++) {
            if (args[i] === undefined || args[i] === null) continue;
            var token = "%" + (i + 1);
            if (s.indexOf(token) >= 0) s = s.split(token).join(String(args[i]));
        }
        return s;
    }

    // The countdown has to tick: Timer in the VIEW, not in the service — it only
    // exists when the host mounts the surface.
    //
    // CRITICAL: `now` is a REPAINT TRIGGER, not a time source. The timer bumps it
    // so that bindings depending on `epoch` re-evaluate once a second; `epoch`
    // itself reads the real clock. Adding the two — `Date.now()/1000 + now`, which
    // is what this was until 2026-10-28 — makes time advance TWICE as fast:
    // measured 3.2 real seconds produced 6.0 seconds of `epoch`. That poisoned
    // every countdown, elapsed percentage, pace, next-reset and data-age reading.
    property int now: 0
    Timer { interval: 1000; running: root.active; repeat: true; onTriggered: root.now++ }
    readonly property real epoch: {
        var tick = root.now;          // dependency: forces re-evaluation each second
        return Date.now() / 1000;     // the actual clock, read fresh
    }

    // ---- reset time formatting (T23) ---------------------------------------
    // ONE convention for every reset in the UI, so the same datum never appears
    // in four shapes (`3h 22m`, `3H18`, `4D56`, `5D` all did):
    //   3h 22min · 4d 56min · 5d        plus the exact clock when it helps:
    //   · Hoje, 18:33 / Amanhã, 09:10 / 12/nov, 14:00
    //
    // `resetParts` is PURE — no locale, no translation, no `root` state except
    // nothing at all. That is what makes it testable in isolation; the localised
    // composition happens in `resetLabel` below.
    function resetParts(resetAt, nowEpoch) {
        if (resetAt === null || resetAt === undefined || resetAt === "") return { valid: false };
        var target = Date.parse(resetAt) / 1000;
        if (!isFinite(target)) return { valid: false };
        var nowS = Number(nowEpoch);
        if (!isFinite(nowS)) return { valid: false };
        var s = Math.max(0, Math.round(target - nowS));
        var days = Math.floor(s / 86400);
        var hours = Math.floor((s % 86400) / 3600);
        var minutes = Math.floor((s % 3600) / 60);
        var relative;
        if (s < 60) {
            relative = "now";
        } else if (s < 3600) {
            relative = minutes + "min";
        } else if (s < 86400) {
            // Always BOTH parts inside a day: "3h 22min", never a bare "3h".
            relative = hours + "h " + minutes + "min";
        } else {
            // Past a day: days + the LARGEST non-zero remainder unit. This is
            // what the owner's own example demands — `4d 56min` (days + minutes)
            // is two units, which rule 2 allows; `4d 0h` would lose the 56
            // minutes and `4d 0h 56min` would be three units, which rule 2
            // forbids. So: hours when there are any, otherwise minutes, otherwise
            // nothing.
            if (hours === 0 && minutes === 0) relative = days + "d";
            else if (hours === 0) relative = days + "d " + minutes + "min";
            else relative = days + "d " + hours + "h";
        }
        return { valid: true, seconds: s, days: days, hours: hours,
                 minutes: minutes, relative: relative };
    }

    // Calendar position of the reset, for the exact-clock suffix. Pure as well.
    // `daysAhead` is a CALENDAR distance (today = 0, tomorrow = 1), not an
    // elapsed-time distance: a reset in 3h may still be "tomorrow" at 23:00.
    function resetClockParts(resetAt, nowEpoch) {
        if (resetAt === null || resetAt === undefined || resetAt === "") return { valid: false };
        var t = new Date(resetAt);
        if (isNaN(t.getTime())) return { valid: false };
        var nowS = Number(nowEpoch);
        if (!isFinite(nowS)) return { valid: false };
        var n = new Date(nowS * 1000);
        var dayA = new Date(n.getFullYear(), n.getMonth(), n.getDate());
        var dayB = new Date(t.getFullYear(), t.getMonth(), t.getDate());
        return {
            valid: true,
            daysAhead: Math.round((dayB - dayA) / 86400000),
            hours: t.getHours(),
            minutes: t.getMinutes(),
            day: t.getDate(),
            month: t.getMonth()
        };
    }

    // ---- footer: freshness, manual refresh, missing data (T30) -------------
    // "Updated 2 min ago" answers a question the bars cannot: is what I am looking
    // at current? It ages while the popout is open because `root.now` ticks (the
    // same Timer that drives the reset countdowns).
    //
    // It reports OUR reading (`lastSuccessEpoch` from the service), not the
    // upstream's `fetched_at`: a report collected hours ago but read a minute ago
    // is a FRESH reading of old data, and saying otherwise would misplace the
    // blame. Provider-level staleness is already shown per provider.
    readonly property real dataAgeSeconds: {
        var t = service ? Number(service.lastSuccessEpoch) : 0;
        if (!isFinite(t) || t <= 0) return -1;
        return Math.max(0, root.epoch - t);
    }

    // Age in the T23 vocabulary: "now", "22min", "3h 22min", "4d 56min". Written
    // here rather than reusing `resetParts` because that function saturates a PAST
    // target at zero — feeding it a past instant returns "now" for any age, which
    // is exactly the bug this comment prevents from coming back.
    function ageText(seconds) {
        var s = Number(seconds);
        if (!isFinite(s) || s < 0) return "";
        s = Math.round(s);
        if (s < 60) return "now";
        var days = Math.floor(s / 86400);
        var hours = Math.floor((s % 86400) / 3600);
        var minutes = Math.floor((s % 3600) / 60);
        if (s < 3600) return minutes + "min";
        if (s < 86400) return hours + "h " + minutes + "min";
        if (hours === 0 && minutes === 0) return days + "d";
        if (hours === 0) return days + "d " + minutes + "min";
        return days + "d " + hours + "h";
    }

    readonly property int troubledProviders: model ? Number(model.with_issues || 0) : 0
    readonly property bool loading: service ? service.loading === true : false

    // The service mounts ONCE and persists; only the view is remounted when the
    // popout opens. So `refresh()` in the service's Component.onCompleted fires
    // on shell start, not on open — reopening showed the model from up to a whole
    // poll interval ago (external review, 2026-10-28). Asking here, on mount,
    // makes "reopening re-reads" true.
    //
    // Guarded: only when the surface is actually ACTIVE and the data is older than
    // a short grace, so a host that remounts the view repeatedly cannot start a
    // collection storm.
    readonly property int reopenRefreshAfter: 30

    Component.onCompleted: {
        if (!root.active) return;
        if (root.service && (root.dataAgeSeconds < 0 || root.dataAgeSeconds > root.reopenRefreshAfter))
            root.requestRefresh();
    }

    onActiveChanged: {
        if (!root.active) return;
        if (root.service && (root.dataAgeSeconds < 0 || root.dataAgeSeconds > root.reopenRefreshAfter))
            root.requestRefresh();
    }

    function requestRefresh() {
        if (!service) return;
        if (typeof service.refresh === "function") service.refresh();
    }

    // ---- layout: grid of pills + one drawer (T33-T39) ----------------------
    // There is ONE format now. The expanded/compact pair is gone: it needed two
    // stacked buttons and a `+N more` chip the owner did not recognise as a
    // control (Att1, 2026-10-29). The grid gives height back; the drawer pays for
    // it with detail on demand.
    readonly property int columns: {
        var v = cfg ? Number(cfg.columns) : NaN;
        if (!isFinite(v)) return 2;
        return Math.max(2, Math.min(4, Math.round(v)));
    }

    // Width of ONE pill before scaling, and the popout width that results.
    // Measured 2026-10-29: contentWidth was 406 at s=1, so two 197px pills plus
    // the 6px gap fit exactly; three do not. Hence the derivation, and hence
    // `implicitWidth` being a FUNCTION of `columns` — PluginPopouts.qml:172-188
    // uses the content's implicitWidth when the placement does not fix `width`,
    // which is the case in the placement this was developed against.
    readonly property real pillTargetWidth: 197
    // Corner radius shared by the pills, so the grid speaks the same shape
    // language as the popout card they sit in. 8 matches the shell's
    // `radiusWidget`, which is what the popout body uses; see the Pill's radius
    // for why it cannot be imported.
    readonly property real pillCorner: 8
    readonly property real baseWidth: 2 * pad + root.columns * root.pillTargetWidth
                                        + (root.columns - 1) * gap + 25

    // Direction the drawer opens. `down` is the default: it is the only one that
    // cannot collide with the popout's width budget.
    readonly property string drawerDirection: {
        var v = cfg && cfg.drawerDirection ? String(cfg.drawerDirection) : "down";
        return ["down", "left", "right"].indexOf(v) >= 0 ? v : "down";
    }

    // Ceiling of the drawer, in the unscaled units the manifest uses.
    // TWO terms (T32 spike): the setting, capped by a fraction of the tallest
    // screen. `Quickshell.screens` was measured to work INSIDE a plugin
    // (harness: screens=1, 800x800), but it can be empty offscreen, so the
    // setting alone is the fallback.
    readonly property int drawerMaxHeightSetting: {
        var v = cfg ? Number(cfg.drawerMaxHeight) : NaN;
        if (!isFinite(v)) return 320;
        return Math.max(160, Math.min(480, Math.round(v)));
    }
    readonly property real screenHeight: {
        var list = Quickshell.screens;
        if (!list || !list.length) return 0;
        var best = 0;
        for (var i = 0; i < list.length; i++) {
            var h = list[i] ? Number(list[i].height) : NaN;
            if (isFinite(h) && h > best) best = h;
        }
        return best;
    }
    // The drawer may never claim more than 60% of the screen. With no screen
    // information the setting alone decides — a deterministic fallback beats a
    // guess (the harness runs offscreen at 800x800).
    readonly property real drawerMaxHeight: {
        var want = root.drawerMaxHeightSetting * root.s;
        var capByScreen = root.screenHeight > 0 ? root.screenHeight * 0.6 : 0;
        return capByScreen > 0 ? Math.min(want, capByScreen) : want;
    }

    // ---- `down` drawer vs. the screen (R5: T48, T49) -------------------------
    // The host sizes the popout to this item's implicit height, centres it and
    // CLIPS what does not fit (`Popout.qml`: `bodyClip.clip: true`), with no
    // height passed in. A `down` drawer that only ever adds height therefore
    // pushed the footer and half of `Collapse` off the screen on a popout that
    // already filled it (owner's smoke, 2026-11-10: closed popout at ~92% of
    // the usable height).
    //
    // The screen this item is on, not the tallest one: with monitors of
    // different heights the tallest would promise room that is not there.
    readonly property real ownScreenHeight: {
        var h = Number(Screen.height);
        return (isFinite(h) && h > 0) ? h : root.screenHeight;
    }
    // What the host keeps for itself, top and bottom: its own 16*s inset around
    // the content plus the bar/frame band. Measured on the real shell
    // (2026-11-17, s = 1.926, 1280 px screen): the band ends 51 px from the
    // edge, i.e. ~26.5*s. 28*s clears it by about 3 px a side; a first try at
    // 32*s was safe but cost this very popout its only metric row.
    readonly property real hostChromeHeight: 2 * (16 + 28) * root.s
    // 0 = unknown: with no budget and no screen there is nothing to clamp to,
    // and the configured ceiling alone decides (same fallback as above).
    readonly property real heightLimit: root.heightBudget > 0 ? root.heightBudget
        : (root.ownScreenHeight > 0
           ? Math.max(0, root.ownScreenHeight - root.hostChromeHeight) : 0)
    // Height of everything that is NOT the drawer. Built from positions above
    // and below the grid on purpose: reading `col.implicitHeight` here would
    // feed the drawer's own height back into its limit.
    readonly property real closedHeight: 2 * root.padY + pillsArea.y + pillGrid.implicitHeight
        + (footer.visible ? col.spacing + footer.height : 0)
    // Free height under the grid. Negative when the closed popout is already
    // taller than the limit.
    readonly property real downRoom: root.heightLimit > 0
        ? root.heightLimit - root.closedHeight : Infinity
    // What a `down` drawer always needs: name, status line, the `+N more`
    // counter and `Collapse`. Below this it could not even say what it cut.
    readonly property real drawerRowGap: 4 * root.s
    readonly property real drawerDownFixedHeight: 20 * root.s
        + drawerTitleMeasure.implicitHeight + root.drawerRowGap
        + drawerMetaMeasure.implicitHeight + root.drawerRowGap
        + 22 * root.s
    readonly property real drawerDownMinHeight: root.drawerDownFixedHeight
        + drawerMetaMeasure.implicitHeight + root.drawerRowGap
    // Ceiling of a `down` drawer. When the room under the grid is not enough
    // the drawer does not grow the popout past the screen: it rises from the
    // base instead (it is opaque and anchored there), over the grid and, if it
    // needs more, over what sits above the grid — so the footer and `Collapse`
    // stay where they were and opening it never makes the popout taller than a
    // closed one that fitted.
    //
    // It is NOT limited to the grid's own height. That was tried first and
    // measured on the owner's shell (2026-11-17): grid + room came to 200 px,
    // one metric plus the counter needs 219, so the drawer could only ever say
    // `+2 more`. A detail panel that shows no detail is worse than one that
    // covers the primary for as long as it is open.
    readonly property real drawerDownCeiling: {
        var space = pillsArea.y + pillGrid.implicitHeight + Math.max(0, root.downRoom);
        return Math.max(root.drawerDownMinHeight, Math.min(root.drawerMaxHeight, space));
    }

    // Which secondary the drawer shows. EMPTY STRING = closed. The key is the
    // provider's FULL id including the account (`openai@work`), never the grid
    // index: after a poll the same cell can hold another provider, and carrying
    // the drawer over would attribute one vendor's numbers to another.
    property string openDrawerId: ""

    function isDrawerOpen(provider) {
        return provider !== null && provider !== undefined
            && root.openDrawerId !== "" && String(provider.id) === root.openDrawerId;
    }

    function toggleDrawer(provider) {
        if (!provider) return;
        var id = String(provider.id);
        // Accordion: opening one closes the previous. Decided by the owner on
        // 2026-10-29 — the popout has no height clamp of its own (T32 measured
        // `bodyClip.clip: true`, which TRUNCATES silently), so several drawers at
        // once would lose content with no warning.
        root.openDrawerId = (root.openDrawerId === id) ? "" : id;
    }

    function closeDrawer() {
        root.openDrawerId = "";
    }

    // Which metric a provider leads with: the highest percentage, tie-broken by
    // report order (first wins), exactly like the collector's `headline_metric`.
    // A metric without a percentage cannot win — it has no magnitude to compare,
    // and picking it would be a guess.
    function leadingMetric(metrics) {
        if (!metrics || metrics.length === 0) return null;
        var best = null, bestPct = -1;
        for (var i = 0; i < metrics.length; i++) {
            var m = metrics[i];
            if (!m) continue;
            var p = m.percent;
            if (p === null || p === undefined || !isFinite(Number(p))) continue;
            if (Number(p) > bestPct) { bestPct = Number(p); best = m; }
        }
        // No metric has a percentage: fall back to the first, so the provider is
        // never blank. The caller draws it without a bar.
        return best !== null ? best : metrics[0];
    }

    // ---- drawer: what fits, and what gets cut (T37) -------------------------
    // The drawer does NOT scroll — the owner vetoed it ("senão realmente é sinal
    // que está carregando muita informação num painel de acompanhamento rápido",
    // 2026-10-29). Content past the ceiling is cut at the TAIL and announced as
    // `+N more`, in inert text.
    //
    // The cut has to be computed BEFORE drawing: T32 measured `bodyClip.clip:
    // true` on the host, so content past the screen is truncated SILENTLY and
    // leaning on the host would hide quotas with no warning at all.
    //
    // Row heights derive from the type scale, not from guessing: one metric block
    // is its label line, the meter, and its reset line, separated by the gap.
    readonly property real drawerMetricBlockHeight:
        (root.fsBody + 3 * root.s) + Math.max(5 * root.s, root.fsValue)
        + (root.fsMeta + 4 * root.s)
    // Name + status line at the top of the drawer, always reserved.
    readonly property real drawerHeaderHeight: root.fsTitle + root.fsMeta + 8 * root.s
    // How many whole metric blocks fit under the ceiling.
    readonly property int drawerMetricBudget: {
        var room = root.drawerMaxHeight - root.drawerHeaderHeight;
        if (room <= 0) return 0;
        return Math.max(0, Math.floor(room / Math.max(1, root.drawerMetricBlockHeight)));
    }

    // The metrics the drawer draws, leading one first, plus how many were cut.
    function drawerSlice(provider) {
        if (!provider || !provider.metrics) return { metrics: [], omitted: 0 };
        var lead = root.leadingMetric(provider.metrics);
        var ordered = [];
        if (lead !== null) ordered.push(lead);
        for (var i = 0; i < provider.metrics.length; i++) {
            if (provider.metrics[i] !== lead) ordered.push(provider.metrics[i]);
        }
        var budget = root.drawerMetricBudget;
        if (budget <= 0) return { metrics: [], omitted: ordered.length };
        return {
            metrics: ordered.slice(0, budget),
            omitted: Math.max(0, ordered.length - budget)
        };
    }

    // The drawer is cut by what REALLY fits, not by the estimate above alone
    // (T49). The estimate counts metric blocks; it knows nothing about the
    // readings, the counter line or `Collapse`, so near the ceiling the last
    // rows were drawn past the panel's clip — measured: `+N more` lost 4-5 px
    // of its 11 in a side drawer at ceilings 160 and 240, and `Collapse` went
    // first in a `down` one. Here the counter (and `Collapse`, for `down`) are
    // reserved first, metrics take what is left, and the readings come last:
    // they are the only rows that are optional.
    function drawerFit(provider, direction) {
        var base = root.drawerSlice(provider);
        var total = base.metrics.length + base.omitted;
        var meta = drawerMetaMeasure.implicitHeight;
        var gap = root.drawerRowGap;
        var metricHeight = meta + root.s + Math.max(4 * root.s, meta);
        var down = direction === "down";
        var ceiling = down ? root.drawerDownCeiling : root.drawerMaxHeight;
        var fixed = down ? root.drawerDownFixedHeight
                         : root.drawerDownFixedHeight - 22 * root.s - gap;
        var n = base.metrics.length, need = 0;
        for (; n >= 0; n--) {
            need = fixed + n * (metricHeight + gap) + (total - n > 0 ? meta + gap : 0);
            if (need <= ceiling) break;
        }
        if (n < 0) n = 0;
        var readings = 0;
        if (root.showDetail && n > 0)
            readings = root.usageReadings(base.metrics[0], Date.now() / 1000).filter(
                function (r) { return r.kind !== "usage"; }).length;
        var withReadings = need + readings * (meta + gap);
        var show = readings > 0 && withReadings <= ceiling;
        return {
            metrics: base.metrics.slice(0, n),
            omitted: total - n,
            readings: show,
            height: show ? withReadings : need
        };
    }

    // Measure text with the same fonts as the drawer instead of treating the
    // configured ceiling as the content's natural height.
    Text { id: drawerTitleMeasure; visible: false; text: "Ag"; font.family: Theme.font; font.pixelSize: root.fsTitle }
    Text { id: drawerMetaMeasure; visible: false; text: "Ag"; font.family: Theme.mono; font.pixelSize: root.fsMeta }

    readonly property real lateralReservedHeight: {
        var providers = root.visibleSecondaries;
        var largest = 0;
        for (var i = 0; i < providers.length; i++)
            largest = Math.max(largest, root.drawerFit(providers[i], "left").height);
        return Math.min(root.drawerMaxHeight, largest);
    }

    // T39 — the drawer's identity must survive a poll and must NOT migrate.
    // `service.model` is replaced wholesale every poll, so the drawer is reopened
    // by ID, and it closes when the id stops being a visible secondary: it left
    // the report, became the primary, or fell out of `maxSecondary` /
    // `showSecondaries`. It never hands itself to whoever now sits in that cell.
    onModelChanged: root.reconcileDrawer()

    function reconcileDrawer() {
        if (root.openDrawerId === "") return;
        // A hidden section has no visible secondary: the drawer has to close, or
        // turning the section back on would reveal a drawer nobody opened in this
        // view. Contract item 9 names this as one of the three exit paths.
        if (!root.showSecondary) { root.openDrawerId = ""; return; }
        // `visibleSecondaries`, not `secondaryProviders`: a provider cut by
        // `maxSecondary` is just as gone as one that left the report.
        var list = root.visibleSecondaries;
        for (var i = 0; i < list.length; i++) {
            if (list[i] && String(list[i].id) === root.openDrawerId) return;
        }
        root.openDrawerId = "";
    }

    // One line at the top says the situation without walking every bar. It counts
    // QUOTAS, not providers, and it never compares percentages across windows:
    // "exhausted" is `percent >= 100` on that quota's own scale.
    //
    // Three different thresholds live in this round on purpose, and they are not
    // interchangeable:
    //   >= 100  exhausted          (this summary)
    //   >  80   "above 80%"        (this summary — the contract's wording)
    //   >= 85   critical colour    (T26, the bar's colour)
    // Raising the summary's 80 to 85 would hide quotas between 80 and 85; lowering
    // the colour's 85 to 80 would repaint bars the contract fixed. Each stays.
    readonly property int exhaustedThreshold: 100
    readonly property int highWaterThreshold: 80

    // Every quota the summary may count: one entry per (provider, metric label).
    // A provider in `error` contributes NOTHING — its quotas are unknown, and
    // counting them as zero or as exhausted would both be inventions.
    //
    // Deduplication is by `(provider id, metric label)`, never by percentage:
    // three metrics above 80% on one provider are three quotas, but the same two
    // windows listed twice are one each. A provider whose two metrics share a
    // label would collapse to one — that is the only case where the rule bites,
    // and it is the honest reading of "the same window".
    function countableQuotas(model) {
        var out = [];
        if (!model) return out;
        var providers = model.all ? model.all : [];
        var seen = ({});
        for (var i = 0; i < providers.length; i++) {
            var p = providers[i];
            if (!p || p.status === "error") continue;
            var metrics = p.metrics ? p.metrics : [];
            for (var j = 0; j < metrics.length; j++) {
                var m = metrics[j];
                if (!m) continue;
                var label = m.label === null || m.label === undefined ? "" : String(m.label);
                var chave = String(p.id) + "\u0000" + label;
                if (seen[chave]) continue;
                seen[chave] = true;
                out.push({ providerId: p.id, label: label, metric: m });
            }
        }
        return out;
    }

    // The summary as data, so the view only renders and the logic is testable.
    // Segments are omitted when they would say zero — "0 exhausted" is noise, and
    // the contract forbids it.
    function operationalSummary(model, nowEpoch) {
        var quotas = root.countableQuotas(model);
        var exhausted = 0, high = 0;
        var nextReset = null, nextSecs = Number.POSITIVE_INFINITY;
        for (var i = 0; i < quotas.length; i++) {
            var m = quotas[i].metric;
            var pct = m.percent;
            if (pct !== null && pct !== undefined && isFinite(Number(pct))) {
                if (Number(pct) >= root.exhaustedThreshold) exhausted++;
                else if (Number(pct) > root.highWaterThreshold) high++;
            }
            // Only FUTURE resets compete for "next"; a past one is not upcoming.
            var r = root.resetParts(m.reset_at, nowEpoch);
            if (r.valid && r.seconds > 0 && r.seconds < nextSecs) {
                nextSecs = r.seconds;
                nextReset = r;
            }
        }
        return {
            exhausted: exhausted,
            high: high,
            nextResetRelative: nextReset ? nextReset.relative : "",
            nextResetSeconds: nextReset ? nextReset.seconds : null,
            total: quotas.length
        };
    }

    // The rendered segments, already translated. Empty array = nothing to say,
    // and then the header hides itself entirely.
    function operationalSummarySegments(model, nowEpoch) {
        var s = root.operationalSummary(model, nowEpoch);
        var out = [];
        // Singular and plural are separate keys: "1 quotas exhausted" is wrong in
        // every language here, and a translator cannot fix a count that arrives as
        // a number inside a fixed string.
        if (s.exhausted === 1) out.push(root.tr("1 quota exhausted"));
        else if (s.exhausted > 1) out.push(root.tr("%1 quotas exhausted", s.exhausted));
        if (s.high === 1) out.push(root.tr("1 quota above %1%", root.highWaterThreshold));
        else if (s.high > 1) out.push(root.tr("%1 quotas above %2%", s.high, root.highWaterThreshold));
        if (s.nextResetRelative !== "")
            out.push(root.tr("next reset in %1", s.nextResetRelative));
        return out;
    }

    // The bar colour must mean the same thing in every theme. It used to come
    // straight from the host accent, which is the USER'S choice and therefore
    // cannot be trusted to signal danger: with a red accent, low consumption
    // looked alarming and critical looked calm.
    //
    // Thresholds are the ones the round signed off: <60 neutral, 60–84 attention,
    // >=85 critical, >=100 exhausted. Documented contrast (WCAG 2.1) against the
    // popout surface `#1e100d` (F014) and against the track, which is the accent
    // at alpha 0.13 over that surface and is therefore always dark:
    //
    //   colour            vs surface   vs track (worst accent tested)
    //   critical #e2342a      4.19        3.72      (amber accent)
    //   attention #d9a441     8.00        7.22
    //   neutral (accent)      >=4.0       >=3.4   (accent-dependent, see below)
    //
    // All pass SC 1.4.11's 3:1 for non-text contrast. Colour never carries the
    // state alone: the percentage and the metric label already say it (SC 1.4.1).
    //
    // THE SCALE WINS OVER TheACCENT for attention and critical. If the user's
    // accent is itself red, "low consumption" must not read as danger — the
    // semantic reading is not negotiable, so only the NEUTRAL band follows the
    // accent. That is the one place the plugin overrides the host's styling, and
    // it is deliberate.
    readonly property color semanticAttention: Theme.gold      // #d9a441
    readonly property color semanticCritical: Theme.sun        // #e2342a

    // Pure: percent (and the accent for the neutral band) in, colour out. Always
    // returns a VALID colour — a missing or absurd percent falls back to the
    // accent, and an invalid accent falls back to the theme's own accent. The
    // guard matters: returning an invalid colour paints nothing and would leave a
    // metric silently blank.
    function validColour(c) {
        return c !== null && c !== undefined
            && isFinite(c.r) && isFinite(c.g) && isFinite(c.b)
            && (c.a === undefined || (isFinite(c.a) && c.a > 0.05));
    }

    // Does this colour already read as "danger"? A red/orange accent cannot serve
    // as the NEUTRAL band: 30% consumption would look like an alarm, which is
    // precisely the defect this task exists to remove.
    //
    // Detected by HUE plus LIGHTNESS, and the lightness test is essential: this
    // theme's default accent is `#ffb4a8`, a soft peach whose hue is 8° and whose
    // saturation is 1.0 — a saturation-only test called it danger and would have
    // desaturated the plugin's normal look for every user. A pastel red is not an
    // alarm; a saturated dark red is. Measured: `#ffb4a8` L=0.83 (safe, stays),
    // `#e2342a` L=0.53 (danger, neutral band desaturated).
    function isDangerHue(c) {
        if (!root.validColour(c)) return false;
        var deg = c.hslHue * 360;
        var sat = c.hslSaturation;
        var lig = c.hslLightness;
        if (!isFinite(deg) || !isFinite(sat) || !isFinite(lig)) return false;
        var inBand = (deg >= 335 || deg <= 25);
        return inBand && sat >= 0.35 && lig <= 0.65;
    }

    // The neutral band: the accent when it is safe to use, otherwise the SAME
    // hue with the saturation pulled down. Desaturated, not replaced — the plugin
    // stays in the user's colour family while stopping the false alarm.
    function neutralColour(accent) {
        var base = root.validColour(accent) ? accent
                 : (root.validColour(root.accentColor) ? root.accentColor : Theme.bright);
        if (!root.isDangerHue(base)) return base;
        return Qt.hsla(base.hslHue, base.hslSaturation * 0.22,
                       Math.min(0.86, base.hslLightness + 0.18), base.a);
    }

    // Pure: percent (and the accent for the neutral band) in, colour out. Always
    // returns a VALID colour — a missing or absurd percent falls back to the
    // neutral band, and an invalid accent falls back to the theme's own accent.
    // The guard matters: an invalid colour paints nothing and would leave a
    // metric silently blank.
    function usageColour(percent, accent) {
        var neutral = root.neutralColour(accent);
        var p = Number(percent);
        if (percent === null || percent === undefined || !isFinite(p)) return neutral;
        if (p >= 85) return root.semanticCritical;
        if (p >= 60) return root.semanticAttention;
        return neutral;
    }

    // Absolute consumption and pace are DIFFERENT things and used to share one
    // line: "32% elapsed · 68pts ahead" read as a single, ambiguous statement.
    // They are now three labelled readings, and each one is derived in ONE place.
    //
    // Pace exists only when the window length is known. Without `window_secs`
    // there is no elapsed time, so there is NO pace — showing 0 would invent a
    // datum. That is why every function here returns `valid: false` and the view
    // renders an em dash instead of a number.
    //
    // `reset_at` gives the remaining time and `window_secs` the total, so:
    //   elapsed_secs = window_secs - (reset_at - now)
    // which is the same protocol the upstream's own `detail` describes, but
    // DERIVED here instead of parsed from prose.
    function elapsedRatio(metric, nowEpoch) {
        if (!metric) return { valid: false };
        var win = metric.window_secs;
        if (win === null || win === undefined) return { valid: false };
        win = Number(win);
        if (!isFinite(win) || win <= 0) return { valid: false };
        var resetAt = metric.reset_at;
        if (resetAt === null || resetAt === undefined || resetAt === "") return { valid: false };
        var target = Date.parse(resetAt) / 1000;
        var nowS = Number(nowEpoch);
        if (!isFinite(target) || !isFinite(nowS)) return { valid: false };
        var remaining = Math.max(0, target - nowS);
        var elapsed = Math.min(win, Math.max(0, win - remaining));
        return { valid: true, elapsedSecs: elapsed, windowSecs: win,
                 percent: Math.round(elapsed / win * 100) };
    }

    // Pace = usage − elapsed, in percentage points. Positive means burning faster
    // than the window; negative means headroom. `|pace| < 1pp` is "on pace": it
    // absorbs the rounding noise of two independently rounded percentages and
    // avoids claiming a direction that is not really there.
    function pacePoints(usagePercent, elapsedPercent) {
        if (usagePercent === null || usagePercent === undefined) return { valid: false };
        if (elapsedPercent === null || elapsedPercent === undefined) return { valid: false };
        var u = Number(usagePercent), e = Number(elapsedPercent);
        if (!isFinite(u) || !isFinite(e)) return { valid: false };
        var diff = u - e;
        return { valid: true, points: diff, onPace: Math.abs(diff) < 1 };
    }

    // The three labelled lines, ready to draw. `usage` is ALWAYS present when the
    // metric has a percentage (that is the absolute datum); `elapsed` and `pace`
    // appear only when derivable. An em dash is the honest answer for "not
    // derivable", never a zero.
    function usageReadings(metric, nowEpoch) {
        if (!metric) return [];
        var out = [];
        var pct = metric.percent;
        var hasPct = pct !== null && pct !== undefined && isFinite(Number(pct));
        if (hasPct)
            out.push({ kind: "usage", label: root.tr("Usage"),
                       value: root.tr("%1% of the quota", Math.round(Number(pct))) });
        var el = root.elapsedRatio(metric, nowEpoch);
        if (el.valid)
            out.push({ kind: "elapsed", label: root.tr("Elapsed"),
                       value: root.tr("%1% of the window", el.percent) });
        if (hasPct && el.valid) {
            var pc = root.pacePoints(Number(pct), el.percent);
            if (pc.valid) {
                var pts = Math.round(Math.abs(pc.points));
                var value;
                if (pc.onPace) value = root.tr("on pace with the window");
                else if (pc.points > 0) value = root.tr("%1 percentage points above the fair share", pts);
                else value = root.tr("%1 percentage points below the fair share", pts);
                out.push({ kind: "pace", label: root.tr("Pace"), value: value,
                           ahead: pc.points > 0 && !pc.onPace });
            }
        }
        // The upstream `detail` survives ONLY where it is absolute data, not pace
        // prose. The fixture shows both kinds: "0 of 200 used" (absolute, keep)
        // and "61% elapsed · 30pts ahead" (pace prose, replaced above).
        if (!el.valid && metric.detail)
            out.push({ kind: "detail", label: "", value: String(metric.detail) });
        return out;
    }

    // The time pattern follows the ACTIVE LANGUAGE's locale, not the machine's:
    // a user reading the UI in English should not get Portuguese clock rules.
    function clockText(c) {
        if (!c || !c.valid) return "";
        var locName = root.language === "auto" ? "" : root.language;
        var loc = locName === "" ? Qt.locale() : Qt.locale(locName);
        var date = new Date(2000, c.month, c.day, c.hours, c.minutes, 0);
        var time;
        try {
            time = date.toLocaleTimeString(loc, Locale.ShortFormat);
        } catch (e) {
            var hh = String(c.hours).padStart(2, "0");
            var mm = String(c.minutes).padStart(2, "0");
            time = hh + ":" + mm;
        }
        var dayLabel;
        if (c.daysAhead === 0) dayLabel = root.tr("Today");
        else if (c.daysAhead === 1) dayLabel = root.tr("Tomorrow");
        else {
            var monthShort = "?";
            try { monthShort = loc.monthName(c.month, Locale.ShortFormat); } catch (e) {}
            dayLabel = c.day + "/" + monthShort;
        }
        return dayLabel + ", " + time;
    }

    // The one entry point the UI uses. Nothing draws a reset time any other way.
    function resetLabel(resetAt) {
        var p = root.resetParts(resetAt, root.epoch);
        if (!p.valid) return "";
        var label = p.relative === "now"
                  ? root.tr("RESET NOW")
                  : root.tr("RESET IN %1", p.relative);
        // The exact clock is a help, not a substitute. Past a week it stops
        // helping — the relative number is enough and the line stays short.
        var c = root.resetClockParts(resetAt, root.epoch);
        if (c.valid && c.daysAhead >= 0 && c.daysAhead <= 7)
            label += " · " + root.clockText(c);
        return label;
    }

    // Does another provider in `model.all` produce the same base label under the
    // current mode? Only then does the account need to be shown.
    function labelIsAmbiguous(provider, base) {
        var provs = root.model && root.model.all ? root.model.all : [];
        var alvo = String(base).toLowerCase();
        for (var i = 0; i < provs.length; i++) {
            var outro = provs[i];
            if (!outro || outro.id === provider.id) continue;
            var outroBase = outro.display_name || outro.id;
            if (root.secondaryLabelMode === "short" && outro.short_name) outroBase = outro.short_name;
            else if (root.secondaryLabelMode === "plan" && outro.plan)
                outroBase = root.redactText(outro.plan) || outro.display_name || outro.id;
            if (String(outroBase).toLowerCase() === alvo) return true;
        }
        return false;
    }

    function secondaryName(provider) {
        var base;
        if (root.secondaryLabelMode === "short" && provider.short_name) base = provider.short_name;
        else if (root.secondaryLabelMode === "plan" && provider.plan) {
            base = root.redactText(provider.plan) || provider.display_name || provider.id;
        } else base = provider.display_name || provider.id;
        // Two accounts of the same vendor can share `display_name` (both "Beta"),
        // so the name alone cannot tell them apart — the report carries them apart
        // in `account`, and the README promises the panel distinguishes them.
        //
        // Appended ONLY when the label is genuinely ambiguous, i.e. when another
        // provider in the same list produced the SAME base label. Appending always
        // would break the `short` mode, whose whole point is a short code
        // ("ghc" becoming "ghc@work" defeats it). Never appended twice either: a
        // base that already contains the account is left alone.
        var acc = provider.account ? String(provider.account) : "";
        if (acc === "") return base;
        if (String(base).toLowerCase().indexOf(acc.toLowerCase()) >= 0) return base;
        if (!root.labelIsAmbiguous(provider, base)) return base;
        return base + " @" + acc;
    }

    function redactText(value) {
        return String(value || "")
            .replace(/sk-[^\s]+/ig, "[REDACTED]")
            .replace(/(api[_-]?key\s*[:=]\s*)[^\s,;]+/ig, "$1[REDACTED]");
    }

    // Cut at a WORD boundary, for when the text has to be shortened before it
    // reaches the `Text`.
    //
    // Why it exists: truncating with `slice(0, N)` splits words in half.
    // Measured on kiro's real error (102 chars), with N=56:
    //   "credentials error: no Kiro CLI `kirocli:odic:token` entr"
    // — "entry" cut in half. Worse: that `Text` ALREADY has `elide:
    // Text.ElideRight`, so the blind cut PREVENTED the correct elision (the text
    // arrived too short for elide to act, and short in the wrong way).
    //
    // Semantics (T19 contract):
    //   - empty/null -> ""
    //   - fits within the limit -> unchanged, WITHOUT an ellipsis
    //   - does not fit -> longest prefix ending at a word boundary + "…"
    //   - a single word longer than the limit -> cut at the limit (there is no
    //     word boundary to respect); never returns "" and never loops
    //   - limit <= 0 -> ""
    function truncateAtWord(text, limit) {
        var s = String(text === null || text === undefined ? "" : text);
        var n = Math.floor(Number(limit));
        if (!isFinite(n) || n <= 0) return "";
        if (s.length <= n) return s;
        var cut = s.slice(0, n);
        // If the FOLLOWING character ends a word (it is a space, or the text has
        // ended), then the whole prefix ends on a complete word: use all of it.
        // Without this, "alpha beta gamma" with limit 10 — where the prefix
        // "alpha beta" is already whole words — would return only "alpha…",
        // wasting half the width (the same sin as slice, to a lesser degree).
        // Found by joseki-tester as an ambiguity in the contract.
        if (cut.length === n && /^\s/.test(s.slice(n, n + 1))) {
            return cut.replace(/\s+$/, "") + "…";
        }
        var lastSpace = cut.lastIndexOf(" ");
        if (lastSpace > 0) {
            // There is a word boundary within the limit: cut there.
            return cut.slice(0, lastSpace).replace(/\s+$/, "") + "…";
        }
        // No space in the prefix: one giant word. Cutting at the limit is the
        // only way out; returning "" would hide the text entirely.
        return cut + "…";
    }

    // The framePopout sizes the body by doing `implicitWidth/Height * root.s`, so
    // the intrinsic dimensions go in HERE without multiplying by `s`.
    // `widthBudget` arrives from the host already multiplied.
    // (T33) baseWidth itself is derived from `columns` — see the layout block.
    readonly property real available: widthBudget > 0 ? widthBudget : baseWidth * root.s
    readonly property real padX: pad * root.s
    readonly property real padY: Math.round(pad * 0.8) * root.s
    readonly property real contentWidth: Math.max(160 * root.s, available - 2 * padX)
    // Pill width is derived, never constant: with the columns setting the popout
    // widens (baseWidth) and the pills fill it exactly. A floor keeps a 4-column
    // layout from producing unusable slivers on a narrow placement.
    readonly property real pillWidth: Math.max(120 * root.s,
        Math.floor((root.contentWidth - (root.columns - 1) * root.gap * root.s) / root.columns))
    // Two columns: leave approximately half a pill visible beyond the gap.
    readonly property real drawerPanelWidth: Math.max(180 * root.s,
        Math.floor(root.columns === 2
            ? root.contentWidth - root.pillWidth / 2 - root.gap * root.s
            : root.contentWidth * 0.45))

    implicitWidth: baseWidth
    implicitHeight: Math.max(1, (col.implicitHeight + 2 * padY) / Math.max(0.001, root.s))

    // Usage meter: track + severity fill, with the value OUTSIDE the track (on the
    // right) and the track reserving that width. With a full bar the text never
    // lands on top of the fill — white on red is not legibility, and that is the
    // defect the real smoke test called out.
    //
    // T25: a 1–2px vertical tick marks where the ELAPSED TIME sits in the window.
    // The deviation between usage and time becomes visible without reading a
    // number — the fill to the right of the tick means "ahead of schedule". The
    // tick NEVER recolours the bar: bar and tick are separate channels, which is
    // the `meter-quota-rule` pattern (a fixed rule marks a threshold; it does not
    // repaint the value) and what WCAG 1.4.1 asks for (state must not rest on
    // colour alone — and here it does not rest on colour at all).
    component Meter: Item {
        id: med
        property var metric
        property real thickness: 5
        property real valueFontSize: 10
        // Elapsed percentage of the window, or -1 when not derivable. -1 draws
        // no tick at all (a tick at 0% would claim "just started").
        property real elapsedPercent: -1
        // T30: does this metric carry a percentage at all? `0` is a real reading
        // (empty bar); `null`/absent is a different state (no bar, em dash).
        readonly property bool hasPercent: med.metric !== null && med.metric !== undefined
            && med.metric.percent !== null && med.metric.percent !== undefined
            && isFinite(Number(med.metric.percent))
        height: Math.max(thickness, label.implicitHeight)

        Text {
            id: label
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: med.valueFontSize
            text: med.metric ? (med.metric.value || "") : ""
        }
        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - label.implicitWidth - 6 * root.s)
            height: med.thickness
            radius: height / 2
            color: Theme.threadBg
            // T30: `0%` and "no datum" must not look alike. A metric with a
            // percentage draws a track (an empty one at 0%, which reads as "nothing
            // used"). A metric WITHOUT a percentage draws NO track at all — the
            // absence of the bar is the signal, and the view shows an em dash
            // instead. Drawing an empty track for both was the conflation this task
            // removes.
            visible: med.hasPercent
            Rectangle {
                width: {
                    var h = med.metric;
                    return h && h.percent !== null ? parent.width * h.percent / 100 : 0;
                }
                height: parent.height; radius: height / 2
                color: {
                    var h = med.metric;
                    if (!h) return Theme.faint;
                    // T26: the colour comes from the PERCENT through the semantic
                    // scale, not from the upstream's `severity` field. The two
                    // disagree on a real case (89% is `high` upstream, `critical`
                    // by these thresholds) and the signed contract fixes the
                    // thresholds — see the note on `usageColour`.
                    return root.usageColour(h.percent, root.accentColor);
                }
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }
            }
            // The elapsed tick. Drawn last so it sits above the fill; 2px wide,
            // and its colour is the bright ink of the theme so it contrasts with
            // both the track and every severity colour the fill can take.
            //
            // The alpha lives in the COLOUR, not in `opacity`: the design
            // invariant is "one live opaque accent per screen", and an item
            // opacity would still hand an opaque colour to anything inspecting
            // `color.a`. The tick is not a fill, so it must not read as one.
            // `radius: height / 2` is the honest shape — a vertical capsule,
            // 2px across with fully rounded ends.
            Rectangle {
                id: elapsedTick
                visible: med.elapsedPercent >= 0
                width: Math.max(2, Math.round(1.5 * root.s))
                height: parent.height + Math.round(2 * root.s)
                y: -Math.round(1 * root.s)
                x: Math.max(0, Math.min(parent.width - width,
                       parent.width * med.elapsedPercent / 100 - width / 2))
                color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.85)
                radius: height / 2
            }
        }
    }


    // A secondary as a PILL (T34). Two rules shape it:
    //   1. it always carries NAME + BAR + PERCENT. The bar alone does not say
    //      WHICH provider it belongs to, and the percentage is what makes the
    //      reading legible without colour (R11/WCAG SC 1.4.1).
    //   2. its states are words, never colour: ERROR, STALE, NO DATA. `0%` draws
    //      an empty track; a MISSING percentage draws no track and an em dash
    //      (T30 — conflating those two was a real defect).
    component Pill: Rectangle {
        id: pil
        required property var provider
        property bool opened: false

        readonly property var lead: root.leadingMetric(pil.provider ? pil.provider.metrics : null)
        readonly property bool hasMetrics: pil.provider && pil.provider.metrics
                                           && pil.provider.metrics.length > 0
        readonly property bool isError: pil.provider && pil.provider.status === "error"
        readonly property bool isStale: pil.provider && pil.provider.stale === true
        // A provider in `error` has NO usable reading: whatever percentage its
        // metrics still carry is stale noise from before the failure, and drawing
        // a track for it would show a quota bar next to the word ERROR. T34.2 says
        // ERROR takes the bar's place, so the bar and the percentage both go.
        readonly property bool hasPercent: !pil.isError
            && pil.lead !== null && pil.lead !== undefined
            && pil.lead.percent !== null && pil.lead.percent !== undefined
            && isFinite(Number(pil.lead.percent))

        width: root.pillWidth
        // The owner's reference: the height of a Windows action-center button.
        // 44 logical px is the floor that keeps the target comfortable; the scale
        // factor still multiplies it, so it grows with the user's UI scale.
        height: Math.max(44 * root.s, pillCol.implicitHeight + 10 * root.s)
        // A soft corner, not `height / 2`. Copying the popout's own corner radius
        // keeps ONE corner language across the surface: with a capsule pill
        // the popout's rounded card framed fully-round tablets, and the two read
        // as different design systems inside one panel (owner's report,
        // 2026-10-30). `PluginKit`'s Theme exposes no widget radius (its `radius`
        // is 0, the website's brutalist square), and the shell's `radiusWidget`
        // (8) is not reachable from a plugin, so the value is spelled out here
        // with `s` applied. Capped by half the height so a short pill (heavy text
        // scale) still rounds sanely instead of clipping its own curve.
        radius: Math.min(root.pillCorner * root.s, height / 2)
        color: pillMouse.containsMouse || pil.opened ? Theme.threadBg : "transparent"
        border.width: 1
        // `opened` is a STATE, and it is carried by the border plus the caret in
        // the name row — not by colour alone.
        border.color: pil.opened ? Theme.bright : Theme.lineStrong
        opacity: pillMouse.containsMouse ? 1.0 : 0.92

        Column {
            id: pillCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 3 * root.s

            Row {
                width: parent.width
                spacing: 4 * root.s

                Text {
                    id: pillName
                    width: Math.max(0, parent.width - pillState.implicitWidth - parent.spacing)
                    elide: Text.ElideRight
                    // An error comes out in colour AND in a word (never colour alone)
                    color: pil.isError ? Theme.sun : Theme.bright
                    font.family: Theme.font
                    font.pixelSize: root.fsTitle
                    text: pil.provider ? ((pil.isError ? "! " : "")
                                          + root.secondaryName(pil.provider)) : ""
                }
                Text {
                    id: pillState
                    visible: text !== ""
                    color: pil.isError ? Theme.sun : Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: root.fsMeta
                    font.letterSpacing: 0.5 * root.s
                    // Words, not colour: this is the state channel.
                    text: {
                        if (!pil.provider) return "";
                        if (pil.isError) return root.tr("ERROR");
                        if (!pil.hasMetrics) return root.tr("NO DATA");
                        if (pil.isStale) return root.tr("STALE");
                        // The caret says the pill opens a drawer below/beside it.
                        return pil.opened ? "\u25B4" : "\u25BE";
                    }
                }
            }

            // The bar of the LEADING metric, with its percentage outside the track.
            Item {
                width: parent.width
                height: Math.max(root.fsValue, 4 * root.s)

                Text {
                    id: pillPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: root.fsValue
                    // `0%` is a real reading; absence is an em dash. Never the
                    // same glyph for two different states.
                    text: {
                        if (!pil.provider) return "";
                        if (pil.isError || !pil.hasMetrics) return "";
                        return pil.hasPercent ? (Math.round(Number(pil.lead.percent)) + "%")
                                              : "\u2014";
                    }
                }
                Rectangle {
                    id: pillTrack
                    anchors.left: parent.left
                    anchors.right: pillPct.left
                    anchors.rightMargin: 6 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4 * root.s
                    radius: height / 2
                    color: Theme.threadBg
                    visible: pil.hasPercent
                    Rectangle {
                        width: pil.hasPercent
                               ? parent.width * Math.max(0, Math.min(100, Number(pil.lead.percent))) / 100
                               : 0
                        height: parent.height
                        radius: height / 2
                        color: root.usageColour(pil.lead ? pil.lead.percent : null, root.accentColor)
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                    }
                }
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleDrawer(pil.provider)
        }
    }

    Column {
        id: col
        // NO objectName here on purpose: the harness dumps `KIND|<type>(<ptr>)`,
        // and a named widget makes QML's type string carry a memory address, so
        // two runs never compare equal. The measurement that needed a handle was
        // done by counting filled bars instead — see the T28 evidence.
        x: root.padX
        y: root.padY
        width: root.contentWidth
        spacing: root.gap * root.s

        // ---- header: operational summary (T27) ----------------------------
        // ONE line and no controls. The density pair (mode + expand/collapse) is
        // gone with the second format (T36): what is left is the sentence that
        // carries the most urgent news, on its own full-width line. It WRAPS
        // instead of being cut — squeezing it beside a button chopped it exactly
        // where the button started (P6, measured 2026-10-29).
        Column {
            id: headerRow
            width: parent.width
            visible: root.primaryProvider !== null

            Text {
                id: summaryLine
                width: parent.width
                visible: text !== ""
                wrapMode: Text.WordWrap
                // `cream`, not `faint`: `faint` is the timestamp's weight, and using
                // it here made the most important line the quietest thing on screen.
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: root.fsBody
                text: root.operationalSummarySegments(root.model, root.epoch).join("  ·  ")
            }
        }

        // ---- no data, with an error, or loading ---------------------------
        // Three distinct states, discriminated by `errorKind` (not by text): the
        // missing-dependency warning exists because the way out of it belongs to
        // the user — install the binary. An upstream failure has no local way out,
        // so it shows the diagnostic. Neither of them is `LOADING`.
        Column {
            visible: root.primaryProvider === null
            width: parent.width
            spacing: 4 * root.s

            Text {
                width: parent.width
                elide: Text.ElideRight
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: root.fsTitle
                font.letterSpacing: 1.2 * root.s
                text: {
                    if (root.errorKind === "dep-missing") return root.tr("MISSING DEPENDENCY");
                    // The upstream diagnostic is redacted here too. The per-provider
                    // path already did this; leaving the global path raw meant the
                    // SAME kind of text was scrubbed in one place and printed in the
                    // other (found by external review, 2026-10-28).
                    if (root.errorKind === "upstream") return root.tr("NO DATA") + " · " + root.redactText(root.lastError);
                    // LOADING only while a collection is actually in flight. With no
                    // primary and no error and nothing loading, the report simply
                    // has no usable provider — saying "LOADING" then promises an
                    // operation that already finished (same review).
                    if (root.loading) return root.tr("LOADING");
                    return root.tr("NO PROVIDERS");
                }
            }
            // Install command: only in the case it resolves. In mono, so the eye
            // recognises what to copy. `wrapMode` instead of `elide` so the command
            // never appears cut in half.
            Text {
                visible: root.errorKind === "dep-missing"
                width: parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: root.fsTitle
                text: "ai-usagebar " + root.tr("not found. Install it with:") + "\nparu -S ai-usagebar-bin"
            }
        }

        Column {
            visible: root.primaryProvider !== null
            width: parent.width
            spacing: 4 * root.s

            // T36: the primary no longer has an expander — there is only one
            // format, so every metric is always shown below this name.
            Text {
                width: parent.width
                elide: Text.ElideRight
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: root.fsDisplay
                text: root.primaryProvider ? root.primaryProvider.display_name : ""
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                // status + plan in tracked mono: short telemetry (Tactical)
                color: root.primaryProvider && root.primaryProvider.status === "error" ? Theme.sun : Theme.faint
                font.family: Theme.mono
                font.pixelSize: root.fsMeta
                font.letterSpacing: 1 * root.s
                text: {
                    if (!root.primaryProvider) return "";
                    var p = root.primaryProvider;
                    // No blind cut: this Text's `elide` cuts at a word boundary
                    // according to the REAL width, not at 56 characters.
                    if (p.status === "error") return root.tr("ERROR") + " · " + root.redactText(p.error || "no detail");
                    var plan = root.redactText(p.plan);
                    var out = plan ? plan.toUpperCase() : p.id.toUpperCase();
                    if (p.stale) out += " · " + root.tr("STALE");
                    if (p.account) out += " · " + p.account.toUpperCase();
                    return out;
                }
            }
            Repeater {
                // T28: in compact mode only the leading metric shows, unless the
                // user expanded this provider.
                // T36: the primary always shows EVERY metric. The old compact
                // mode hid all but the leading one behind an expander.
                model: root.primaryProvider && root.primaryProvider.metrics
                       ? root.primaryProvider.metrics : []
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 3 * root.s
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: root.fsBody
                        font.letterSpacing: 0.8 * root.s
                        text: modelData.label ? modelData.label.toUpperCase() : root.tr("USAGE")
                    }
                    Meter {
                        width: parent.width
                        thickness: 6 * root.s
                        valueFontSize: root.fsValue
                        metric: modelData
                        elapsedPercent: {
                            var el = root.elapsedRatio(modelData, root.epoch)
                            return el.valid ? el.percent : -1
                        }
                    }
                    // The three readings, one per line, each with its own label.
                    // Never concatenated: that was the ambiguity being removed.
                    //
                    // `showMetricDetail` is labelled "Show primary pace detail",
                    // so it governs the DERIVED lines (elapsed, pace) and the
                    // upstream detail — never `Usage`, which is the absolute datum
                    // the widget exists to show. Hiding it when someone turns off
                    // "pace detail" would empty the metric.
                    // The model is ALWAYS the full list; the setting gates each row's
                    // visibility. Passing `showDetail ? list : []` here deleted
                    // `Usage` along with the rest — the absolute datum vanished with
                    // the pace detail (caught by T9, 2026-10-28).
                    Repeater {
                        model: root.usageReadings(modelData, root.epoch)
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            spacing: 5 * root.s
                            // `usage` is never gated; elapsed/pace/detail are.
                            visible: modelData.kind === "usage" || root.showDetail
                            height: visible ? implicitHeight : 0
                            Text {
                                visible: modelData.label !== ""
                                color: Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: root.fsBody
                                // NO tracking: these labels introduce full
                                // sentences ("61% of the window"), not short
                                // telemetry. Tracked caps is the Tactical rule for
                                // cooldowns, percentages and metric labels only.
                                text: modelData.label ? (modelData.label + ":") : ""
                            }
                            Text {
                                color: modelData.kind === "pace" && modelData.ahead ? Theme.sun : Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: root.fsBody
                                elide: Text.ElideRight
                                text: modelData.value
                            }
                        }
                    }
                    // A metric with no percentage at all says so, with an em dash.
                    // `0%` is a real reading and draws an empty bar; ABSENCE is a
                    // different state and must never look like zero (T30).
                    Text {
                        visible: (modelData.percent === null || modelData.percent === undefined)
                                 && root.showDetail
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: root.fsBody
                        text: "—"
                    }
                    Text {
                        visible: text !== ""
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: root.fsMeta
                        font.letterSpacing: 0.8 * root.s
                        text: root.resetLabel(modelData.reset_at)
                    }
                }
            }
        }

        // ---- separator + list header --------------------------------------
        // The line takes only the space AFTER the label — no mask: `Text` has no
        // `background` (that belongs to `Control`), and using that property killed
        // object creation, so `col` never came to life, contentLoader.item stayed
        // null and the host fell back to 680x520. The result on screen was a huge,
        // empty body.
        Item {
            visible: root.showSecondary && root.visibleSecondaries.length > 0
            width: parent.width
            height: 18 * root.s
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s
                Text {
                    id: sepLabel
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: root.fsTitle
                    font.letterSpacing: 1.4 * root.s
                    text: root.tr("OTHER PROVIDERS") + " " + root.visibleSecondaries.length + "/" + root.totalSecondary
                }
                Item {
                    width: Math.max(0, parent.width - sepLabel.implicitWidth - parent.spacing)
                    height: 1
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.lineStrong
                    }
                }
            }
        }

        // ---- pills area: grid of secondaries + the drawer (T35, T37, T38) ----
        // Down adds a row below the grid. Laterally the grid slides inside a
        // clipped viewport while the drawer enters from the selected side.
        //
        // The order of the pills is `model.secondary` VERBATIM: the five order
        // modes stay in the collector, and the grid never re-sorts (T35).
        Item {
            id: pillsArea
            width: parent.width
            visible: root.showSecondary && root.visibleSecondaries.length > 0
            height: {
                var gridH = pillGrid.implicitHeight;
                if (root.drawerDirection !== "down")
                    return Math.max(gridH, root.lateralReservedHeight);
                if (!drawerPanel.visible) return gridH;
                if (drawerPanel.direction !== "down")
                    return Math.max(gridH, drawerPanel.height);
                // Push the content down while there is room under the grid;
                // past that the drawer overlaps the grid from the base (T48).
                var pushed = gridH + root.gap * root.s + drawerPanel.height;
                // The area itself never outgrows the limit: a drawer taller
                // than grid + room rises above the grid as well (it is anchored
                // to the base and painted over what precedes it).
                var limit = gridH + Math.max(0, root.downRoom);
                return Math.max(gridH, Math.min(pushed, limit));
            }

            // It is a `Grid`, NOT a `Row`: measured in T28 (2026-10-29) that Qt does
            // not re-run a Row's layout when a child's `visible` flips, which is why
            // the old control row landed two buttons on the same x.
            //
            // Keep the grid's columns and shift the whole grid, not individual pills.
            Item {
                id: gridViewport
                width: parent.width
                height: pillGrid.implicitHeight
                y: root.drawerDirection === "down" ? 0 : Math.max(0, parent.height - height)
                clip: true

            Grid {
                id: pillGrid
                columns: root.columns
                columnSpacing: root.gap * root.s
                rowSpacing: root.gap * root.s
                width: parent.width
                x: drawerPanel.open && drawerPanel.direction !== "down"
                   ? (drawerPanel.direction === "left" ? 1 : -1)
                     * (drawerPanel.width + root.gap * root.s)
                   : 0
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }

                Repeater {
                    model: (root.showSecondary && root.visibleSecondaries) ? root.visibleSecondaries : []
                    delegate: Pill {
                        required property var modelData
                        provider: modelData
                        opened: root.isDrawerOpen(modelData)
                    }
                }
            }
            }

            // --- the drawer panel
            Rectangle {
                id: drawerPanel
                readonly property var provider: {
                    var list = root.secondaryProviders;
                    for (var i = 0; i < list.length; i++)
                        if (list[i] && String(list[i].id) === root.openDrawerId) return list[i];
                    return null;
                }
                readonly property bool open: provider !== null && root.openDrawerId !== ""
                readonly property string direction: root.drawerDirection
                readonly property var slice: root.drawerFit(provider, direction)

                visible: open
                // Keep the lateral panel within the host's clipped body and
                // align its base with the displaced grid.
                anchors.bottom: parent.bottom
                width: direction === "down" ? parent.width : Math.min(parent.width, root.drawerPanelWidth)
                x: direction === "down" ? 0
                   : direction === "left" ? (open ? 0 : -width)
                   : (open ? Math.max(0, parent.width - width) : parent.width)
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
                height: Math.min(direction === "down" ? root.drawerDownCeiling : root.drawerMaxHeight,
                                 drawerCol.implicitHeight + 20 * root.s)
                radius: Math.min(root.pillCorner * root.s, height / 2)
                z: 2
                // OPAQUE surface, not `Theme.threadBg`. `threadBg` is
                // `Qt.rgba(accent, 0.13)` — a 13%-opacity tint that is right for a
                // pill's HOVER wash, where the panel behind it should show through.
                // Used as the drawer's fill it let the grid be read straight
                // through the panel: the owner's smoke test saw "OpenRouter 88%"
                // and "SYNTHETIC" printed ON TOP of the drawer's own text. A panel
                // that carries numbers has to sit on an opaque surface; the pill
                // wash is the wrong tool for it.
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.lineStrong
                clip: true

                // A `down` drawer can now sit over the lower pills. Without this
                // a click on the panel fell through to the pill underneath and
                // swapped the provider behind the user's back.
                //
                // Only while the panel really covers pills: with room under the
                // grid nothing is beneath it, and an always-on catcher is one more
                // clickable thing in the drawer for no reason.
                MouseArea {
                    anchors.fill: parent
                    enabled: drawerPanel.direction === "down" && drawerPanel.open
                             && drawerPanel.y < pillGrid.implicitHeight - 0.5
                             && drawerPanel.y + drawerPanel.height > 0
                    visible: enabled
                }

                Column {
                    id: drawerCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10 * root.s
                    anchors.leftMargin: drawerPanel.direction === "right" ? 34 * root.s : 10 * root.s
                    anchors.rightMargin: drawerPanel.direction === "left" ? 34 * root.s : 10 * root.s
                    spacing: 4 * root.s

                    // name + status/plan
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: root.fsTitle
                        text: {
                            var p = drawerPanel.provider;
                            if (!p) return "";
                            return (p.status === "error" ? "! " : "") + root.secondaryName(p);
                        }
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: root.fsMeta
                        font.letterSpacing: 0.6 * root.s
                        text: {
                            var p = drawerPanel.provider;
                            if (!p) return "";
                            if (p.status === "error")
                                return root.redactText(p.error || root.tr("ERROR")).toUpperCase();
                            var plan = root.redactText(p.plan);
                            var base = plan ? plan.toUpperCase() : String(p.id).toUpperCase();
                            if (p.stale) base += " · " + root.tr("STALE");
                            return base;
                        }
                    }

                    // one row per metric that FITS: label, percent, reset + the bar.
                    // Lead metric first — the same rule as the pill (F020).
                    Repeater {
                        model: drawerPanel.slice.metrics
                        delegate: Column {
                            required property var modelData
                            width: parent.width
                            spacing: 1 * root.s

                            Row {
                                width: parent.width
                                spacing: 5 * root.s
                                Text {
                                    width: Math.max(0, parent.width - drawerPct.implicitWidth
                                                    - drawerReset.implicitWidth - 2 * parent.spacing)
                                    elide: Text.ElideRight
                                    color: Theme.faint
                                    font.family: Theme.mono
                                    font.pixelSize: root.fsMeta
                                    font.letterSpacing: 0.5 * root.s
                                    text: modelData.label ? modelData.label.toUpperCase() : root.tr("USAGE")
                                }
                                Text {
                                    id: drawerPct
                                    color: Theme.bright
                                    font.family: Theme.mono
                                    font.pixelSize: root.fsMeta
                                    text: {
                                        var v = modelData.percent;
                                        if (v === null || v === undefined || !isFinite(Number(v)))
                                            return "\u2014";
                                        return Math.round(Number(v)) + "%";
                                    }
                                }
                                Text {
                                    id: drawerReset
                                    color: Theme.faint
                                    font.family: Theme.mono
                                    font.pixelSize: root.fsMeta
                                    text: root.resetLabel(modelData.reset_at)
                                }
                            }
                            Meter {
                                width: parent.width
                                thickness: 4 * root.s
                                valueFontSize: root.fsMeta
                                metric: modelData
                                elapsedPercent: {
                                    var el = root.elapsedRatio(modelData, root.epoch)
                                    return el.valid ? el.percent : -1
                                }
                            }
                        }
                    }

                    // Readings of the LEADING metric only: the three labelled lines
                    // are what made the old detail tall, and the pill already carries
                    // usage. Elapsed and pace stay reachable here (T24 preserved).
                    Repeater {
                        model: (root.showDetail && drawerPanel.slice.metrics.length > 0
                                && drawerPanel.slice.readings)
                               ? root.usageReadings(drawerPanel.slice.metrics[0], root.epoch).filter(
                                     function (r) { return r.kind !== "usage"; })
                               : []
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            spacing: 5 * root.s
                            Text {
                                visible: modelData.label !== ""
                                color: Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: root.fsMeta
                                text: modelData.label ? (modelData.label + ":") : ""
                            }
                            Text {
                                color: modelData.kind === "pace" && modelData.ahead ? Theme.sun : Theme.faint
                                elide: Text.ElideRight
                                font.family: Theme.mono
                                font.pixelSize: root.fsMeta
                                text: modelData.value
                            }
                        }
                    }

                    // The cut is ANNOUNCED in inert text: it is not a control and
                    // must not look like one (D7). It counts METRICS omitted.
                    Text {
                        width: parent.width
                        visible: text !== ""
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: root.fsMeta
                        text: drawerPanel.slice.omitted > 0
                              ? root.tr("+%1 more", drawerPanel.slice.omitted) : ""
                    }

                    // Collapse: a real control — at the FOOT of a downward drawer,
                    // at the END of the expanded side for a lateral one (D6).
                    Item {
                        width: parent.width
                        height: drawerPanel.direction === "down" ? collapseBtn.height : 0
                        visible: drawerPanel.direction === "down"

                        Rectangle {
                            id: collapseBtn
                            width: collapseLabel.implicitWidth + 16 * root.s
                            height: 22 * root.s
                            radius: height / 2
                            color: collapseMouse.containsMouse ? Theme.lineStrong : "transparent"
                            border.width: 1
                            border.color: Theme.lineStrong
                            anchors.right: drawerPanel.direction === "left" ? undefined : parent.right
                            anchors.left: drawerPanel.direction === "left" ? parent.left : undefined

                            Text {
                                id: collapseLabel
                                anchors.centerIn: parent
                                color: collapseMouse.containsMouse ? Theme.bright : Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: root.fsMeta
                                text: root.tr("Collapse")
                            }
                            MouseArea {
                                id: collapseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeDrawer()
                            }
                        }
                    }
                }

                Rectangle {
                    width: 24 * root.s
                    height: parent.height
                    x: drawerPanel.direction === "left" ? parent.width - width : 0
                    visible: drawerPanel.direction !== "down"
                    Accessible.role: Accessible.Button
                    Accessible.name: root.tr("Collapse")
                    color: returnMouse.containsMouse ? Theme.lineStrong : Theme.threadBg
                    Text {
                        anchors.centerIn: parent
                        color: Theme.bright
                        font.pixelSize: root.fsTitle
                        text: drawerPanel.direction === "left" ? "→" : "←"
                    }
                    MouseArea {
                        id: returnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeDrawer()
                    }
                }
            }

            Rectangle {
                z: 3
                visible: drawerPanel.open && drawerPanel.direction !== "down"
                width: 12 * root.s
                height: gridViewport.height
                y: gridViewport.y
                x: drawerPanel.direction === "left" ? parent.width - width : 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: drawerPanel.direction === "left" ? "transparent" : Theme.tileBg }
                    GradientStop { position: 1; color: drawerPanel.direction === "left" ? Theme.tileBg : "transparent" }
                }
            }
        }

        // ---- footer (T30) --------------------------------------------------
        // Only when there is something to say: an age, a problem count, or a
        // refresh in flight. Otherwise it hides rather than drawing a bare rule.
        Item {
            id: footer
            width: parent.width
            height: visible
                    ? 7 * root.s + (root.staleData
                        ? footerText.implicitHeight + staleReason.implicitHeight + 3 * root.s
                        : Math.max(footerText.implicitHeight, refreshButton.height))
                    : 0
            // NOT gated on `primaryProvider`: the footer is exactly what a user
            // needs when there is NO primary — the age of the attempt and the
            // refresh button. Gating it there hid the retry control precisely in
            // the error state (found by external review, 2026-10-28).
            visible: root.errorKind === "" || root.loading
                     ? (root.dataAgeSeconds >= 0 || root.troubledProviders > 0 || root.loading)
                     : true

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1 * root.s
                color: Theme.lineStrong
                opacity: 0.5
            }

            Text {
                id: footerText
                anchors.left: parent.left
                anchors.right: copyButton.left
                anchors.rightMargin: 8 * root.s
                // CENTRE against the buttons' row, not `bottom`. The buttons are
                // 18px tall pill targets while this text is one 8px line (~11px
                // tall): anchoring both to `parent.bottom` left the text sitting
                // lower than the buttons' optical centre, which read as a
                // misalignment in the owner's smoke test (2026-10-30). Anchoring
                // the text's middle to the buttons' middle keeps them on one line
                // whatever the text scale does to either height.
                anchors.verticalCenter: refreshButton.verticalCenter
                elide: Text.ElideRight
                font.family: Theme.mono
                font.pixelSize: root.fsMeta
                // Prose, not short telemetry: no tracking here.
                // A FAILED refresh over kept data is the one case the footer must
                // say out loud: the numbers are real, but they are old.
                color: root.staleData ? Theme.gold : Theme.faint
                text: {
                    var partes = [];
                    if (root.staleData)
                        partes.push(root.tr("refresh failed, showing earlier reading"));
                    if (root.loading) partes.push(root.tr("updating..."));
                    else if (root.dataAgeSeconds >= 0) {
                        var idade = root.ageText(root.dataAgeSeconds);
                        partes.push(idade === "now" ? root.tr("updated just now")
                                                    : root.tr("updated %1 ago", idade));
                    }
                    if (root.troubledProviders === 1)
                        partes.push(root.tr("1 provider with a problem"));
                    else if (root.troubledProviders > 1)
                        partes.push(root.tr("%1 providers with a problem", root.troubledProviders));
                    return partes.join(" · ");
                }
            }

            // WHY it failed, next to the age. Elided, because an upstream message
            // ("network transport error: error sending request for url ...")
            // is long and the beginning is the useful part. Hidden entirely when
            // there is no stale data, so a healthy panel gains no line.
            Text {
                id: staleReason
                visible: root.staleData
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footerText.top
                elide: Text.ElideRight
                color: Theme.gold
                font.family: Theme.mono
                font.pixelSize: root.fsMeta
                text: root.redactText(root.lastError)
            }

            // T44 / decisão 11: the keybind became a COPY button. The old
            // `keybindHint` text field asked the user to retype a command the
            // plugin already knows; this hands over the exact string instead.
            //
            // `Quickshell.clipboardText` was measured on 2026-10-29: writable from
            // inside a plugin popout and it arrives on the Wayland clipboard.
            //
            // The glyph changes for a moment after the click, because a copy
            // with no feedback is indistinguishable from a dead button — and a
            // button you click twice "just in case" is worse than one that says
            // it worked.
            property string copyState: "idle"   // idle | copied
            Timer {
                id: copyReset
                interval: 1400; repeat: false
                onTriggered: footer.copyState = "idle"
            }
            readonly property string keybindCommand: "ryoku-shell plugin ai-usage"

            Rectangle {
                id: copyButton
                anchors.right: refreshButton.left
                anchors.rightMargin: 6 * root.s
                anchors.bottom: parent.bottom
                width: copyLabel.implicitWidth + 12 * root.s
                height: 18 * root.s
                radius: height / 2
                color: copyMouse.containsMouse ? Theme.threadBg : "transparent"
                border.width: 1
                border.color: footer.copyState === "copied" ? Theme.bright : Theme.lineStrong

                Text {
                    id: copyLabel
                    anchors.centerIn: parent
                    color: footer.copyState === "copied" ? Theme.bright : Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: root.fsMeta
                    // Words, not colour: the state channel is the text itself.
                    text: footer.copyState === "copied" ? root.tr("Copied")
                                                      : root.tr("Copy keybind")
                }
                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.clipboardText = footer.keybindCommand;
                        footer.copyState = "copied";
                        copyReset.restart();
                    }
                }
            }

            // The manual refresh. Same MouseArea pattern the density button uses —
            // verified to receive real clicks inside a popout body.
            Rectangle {
                id: refreshButton
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 18 * root.s
                height: 18 * root.s
                radius: height / 2
                color: refreshMouse.containsMouse ? Theme.threadBg : "transparent"
                border.width: 1
                border.color: Theme.lineStrong

                Text {
                    anchors.centerIn: parent
                    color: root.loading ? Theme.faint : Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: root.fsBody
                    // A plain arrow glyph: the kit forbids emoji, and a text glyph
                    // needs no asset and scales with `s`.
                    text: root.loading ? "\u22EF" : "\u21BB"
                }
                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.loading
                    onClicked: root.requestRefresh()
                }
            }
        }

    }
}
