pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Banners, grouping, the Notification Center and Focus.
//
// Where notifications come from is the platform's business (Platform.qml):
// the standalone build runs its own freedesktop server, the Ryoku bar style
// wraps the shell's. Either way Platform hands each arrival to receive().
Singleton {
    id: root

    // ═══════════════════════ CENTER / FOCUS ══════════════════════
    property bool centerOpen: false
    property string centerScreen: ""

    function toggleCenter(screenName) {
        if (centerOpen) { centerOpen = false; return; }
        Hub.expanded = false;
        centerScreen = screenName || Hub.focusedScreen();
        centerOpen = true;
    }
    readonly property bool dnd: Platform.dnd
    function toggleDnd() {
        const on = !Platform.dnd;
        Platform.setDnd(on);
        Hub.flash("osd", on ? "bedtime" : "bedtime_off", on ? "Do Not Disturb" : "Focus Off", -1, on ? Theme.indigo : null, 1800);
    }

    // ═════════════════════════ ARRIVALS ══════════════════════════
    property var times: ({})
    readonly property var list: Platform.notifList
    readonly property int count: list.length

    // record notifications that were already there when the island loaded,
    // without a banner; `at` is when they really arrived, if known (ms)
    function seed(items, at) {
        const t = Object.assign({}, times);
        for (let i = 0; i < items.length; i++) {
            const n = items[i];
            if (n && !t[n.id]) t[n.id] = Number(at ? at(n) : 0) || Date.now();
        }
        times = t;
    }

    function receive(n) {
        const t = Object.assign({}, times);
        t[n.id] = Date.now();
        times = t;
        if (!Config.s.notifications) return;
        const critical = n.urgency === NotificationUrgency.Critical;
        const silenced = dnd && !(critical && Config.s.dndAllowCritical);
        if (silenced) { if (n.transient) n.expire(); return; }
        pushPopup(n);
        if (Config.s.notifSound) {
            const h = n.hints || {};
            if (!h["suppress-sound"]) {
                const f = h["sound-file"] || Config.s.soundFile;
                if (f) Quickshell.execDetached(["paplay", f]);
            }
        }
    }

    // ═════════════════════════ BANNERS ═══════════════════════════
    property var popups: []         // newest first
    property var expiry: ({})

    // How long a banner stays. Urgent ones get longer, not forever: a banner
    // that never leaves is how "the priority ones don't go away" happened.
    // An app's own expire timeout wins when it sets one.
    function lifetime(n) {
        if (critical(n)) {
            if (Config.s.urgentSticky) return Number.MAX_SAFE_INTEGER;
            return Math.max(4, Config.s.urgentTimeout) * 1000;
        }
        const own = n.expireTimeout;     // seconds
        if (typeof own === "number" && own > 0) return Math.max(2000, Math.min(own * 1000, 60000));
        return Math.max(2, Config.s.bannerTimeout) * 1000;
    }
    function pushPopup(n) {
        popups = [n].concat(popups.filter(p => p && p !== n)).slice(0, 5);
        const e = Object.assign({}, expiry);
        const life = lifetime(n);
        // during a hold, count from when it began: releasing the hold adds the
        // whole hold to every deadline, so this one gets just its own lifetime
        e[n.id] = life === Number.MAX_SAFE_INTEGER ? life : (hold ? holdStart : Date.now()) + life;
        expiry = e;
    }
    function removePopup(n) {
        if (!n) return;
        popups = popups.filter(p => p && p !== n);
        releaseFor(n.id);
        if (n.transient) n.expire();
    }
    function clearPopups() {
        const ps = popups;
        popups = [];
        holds = ({});
        ps.forEach(p => { if (p && p.transient) p.expire(); });
    }

    // ── Holds ──
    // Hovering a banner, typing a reply or opening a banner's menu pauses the
    // countdown. Each surface leases a named hold and drops it when it hides
    // or is destroyed, so a banner that vanished while hovered can't freeze
    // every timer for good.
    property var holds: ({})
    readonly property bool hold: Object.keys(holds).length > 0
    readonly property bool replying: Object.keys(holds).some(k => k.startsWith("reply:"))
    function setHold(key, on) {
        if (!key) return;
        const has = holds[key] === true;
        if (on === has) return;
        const h = Object.assign({}, holds);
        if (on) h[key] = true; else delete h[key];
        holds = h;
    }
    function releaseFor(id) {
        const tail = ":" + id;
        const keys = Object.keys(holds).filter(k => k.endsWith(tail));
        if (keys.length === 0) return;
        const h = Object.assign({}, holds);
        keys.forEach(k => delete h[k]);
        holds = h;
    }
    function endReplies() {
        const keys = Object.keys(holds).filter(k => k.startsWith("reply:"));
        if (keys.length === 0) return;
        const h = Object.assign({}, holds);
        keys.forEach(k => delete h[k]);
        holds = h;
    }
    property real holdStart: 0
    onHoldChanged: {
        if (hold) { holdStart = Date.now(); return; }
        const d = Date.now() - holdStart;
        const e = Object.assign({}, expiry);
        for (const k in e) if (e[k] < Number.MAX_SAFE_INTEGER) e[k] += d;
        expiry = e;
    }
    // Belt and braces: no hold outlives two minutes without being renewed.
    Timer {
        interval: 120000
        running: root.hold && !root.replying
        onTriggered: root.holds = ({})
    }
    Timer {
        interval: 200; repeat: true
        running: root.popups.length > 0 && !root.hold
        onTriggered: {
            const now = Date.now();
            const keep = [], drop = [];
            for (let i = 0; i < root.popups.length; i++) {
                const p = root.popups[i];
                if (!p) continue;
                ((root.expiry[p.id] || 0) > now ? keep : drop).push(p);
            }
            if (drop.length) {
                root.popups = keep;
                drop.forEach(p => { if (p.transient) p.expire(); });
            }
        }
    }
    // Prune banners whose notification was closed elsewhere. Deferred: the
    // list changes before dependent bindings re-evaluate.
    onListChanged: Qt.callLater(root.prunePopups)
    function prunePopups() {
        const l = list;
        const next = popups.filter(p => p && l.indexOf(p) >= 0);
        if (next.length !== popups.length) popups = next;
        const alive = {};
        for (let i = 0; i < l.length; i++) alive[l[i].id] = true;
        let changed = false;
        const t = Object.assign({}, times);
        for (const k in t) if (!alive[k]) { delete t[k]; changed = true; }
        if (changed) times = t;
    }
    onCenterOpenChanged: if (centerOpen) clearPopups()

    // ═════════════════════════ GROUPS ════════════════════════════
    readonly property var groups: {
        const t = times, m = {}, order = [];
        const l = list;
        for (let i = 0; i < l.length; i++) {
            const n = l[i];
            if (n.transient) continue;
            const key = Config.s.groupByApp ? (n.appName || n.desktopEntry || "Notifications") : ("#" + n.id);
            if (!m[key]) { m[key] = { key: key, app: n.appName || "Notifications", items: [], latest: 0 }; order.push(m[key]); }
            m[key].items.push(n);
            m[key].latest = Math.max(m[key].latest, t[n.id] || 0);
        }
        for (let i = 0; i < order.length; i++) order[i].items.sort((a, b) => (t[b.id] || 0) - (t[a.id] || 0));
        order.sort((a, b) => b.latest - a.latest);
        return order;
    }
    readonly property int visibleCount: { let c = 0; for (let i = 0; i < groups.length; i++) c += groups[i].items.length; return c; }

    // ═════════════════════════ HELPERS ═══════════════════════════
    function resolveIcon(s) {
        if (!s) return "";
        if (s.startsWith("/")) return "file://" + s;
        if (s.startsWith("file:") || s.startsWith("image:") || s.startsWith("qrc:")) return s;
        return Quickshell.iconPath(s, true);
    }
    function appIcon(n) {
        if (!n) return "";
        return resolveIcon(n.appIcon) || resolveIcon(n.desktopEntry) || resolveIcon((n.appName || "").toLowerCase().replace(/ /g, "-"));
    }
    function image(n) { return n ? resolveIcon(n.image) : ""; }
    function title(n) { return !n ? "" : (n.summary || n.appName || "Notification"); }
    function body(n) {
        if (!n) return "";
        if (Config.s.previews === "never") return "Notification";
        return (n.body || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'");
    }
    function critical(n) { return n !== null && n !== undefined && n.urgency === NotificationUrgency.Critical; }
    // now · 4m ago · 2h ago · 09:41 · Yesterday · Tuesday · 12/03/26
    function age(n) {
        const t = n ? times[n.id] : undefined;
        if (!t) return "now";
        const now = Hub.now;
        const d = Math.floor((now.getTime() - t) / 60000);
        if (d < 1) return "now";
        if (d < 60) return d + "m ago";
        if (d < 240) return Math.floor(d / 60) + "h ago";
        const then = new Date(t);
        const day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        if (t >= day0) return Hub.fmtClock(then, false, true);
        if (t >= day0 - 86400000) return "Yesterday";
        if (t >= day0 - 6 * 86400000) return Qt.locale().dayName(then.getDay(), Locale.LongFormat);
        return Qt.formatDate(then, Locale.ShortFormat);
    }
    // a messaging-style notification (contact picture + small app badge)
    function isMessage(n) {
        if (!n) return false;
        const h = n.hints || {};
        const cat = String(h.category || "");
        return cat.startsWith("im") || /telegram|signal|whatsapp|discord|slack|messages|element|vesktop|webcord|teams|thunderbird|mail|evolution|geary/i.test(n.appName || "");
    }
    function buttons(n) {
        if (!n) return [];
        const out = [], a = n.actions;
        for (let i = 0; i < a.length; i++) if (a[i].identifier !== "default" && a[i].text !== "") out.push(a[i]);
        return out;
    }
    function activate(n) {
        if (!n) return;
        const a = n.actions;
        for (let i = 0; i < a.length; i++)
            if (a[i].identifier === "default") { a[i].invoke(); removePopup(n); return; }
        // no default action: open the Notification Center
        removePopup(n);
        if (!centerOpen) toggleCenter("");
    }
    function dismiss(n) { if (n) { removePopup(n); n.dismiss(); } }
    // swipe a banner away: it goes quietly to the Notification Center
    function hide(n) { if (n) { popups = popups.filter(p => p && p !== n); releaseFor(n.id); if (n.transient) n.expire(); } }
    function clearGroup(g) { const it = g.items.slice(); for (let i = 0; i < it.length; i++) it[i].dismiss(); }
    function clearAll() {
        const it = list.slice();
        clearPopups();
        for (let i = 0; i < it.length; i++) it[i].dismiss();
    }
    function test() {
        Quickshell.execDetached(["notify-send", "-a", "Island", "-i", "preferences-desktop-notification",
                                 "Hello from Island", "This is what your notifications look like now."]);
    }
    function testUrgent() {
        Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Island", "-i", "dialog-warning",
                                 "Battery at 5%", "Plug in soon. Urgent banners stay a little longer, then tuck away."]);
    }
}
