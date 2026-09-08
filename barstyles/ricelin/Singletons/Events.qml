pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Local calendar events, persisted as a plain JSON array beside the session
 * flags (~/.local/state/ricelin/events.json). The in-memory `events` is the
 * source of truth: add/remove mutate it and write the file, which is read back
 * only at startup. The file is deliberately NOT watched — re-reading our own
 * write races the FileView's cached text and dropped the just-added event (it
 * flashed in, then vanished until the next write). The file holds an array
 * of { id, date, endDate, time, endTime, text, recur } with date/endDate as
 * "YYYY-MM-DD". endDate is "" for a single-day entry, otherwise the last day a
 * multi-day span covers. time and endTime may be "" for an all-day or open-ended
 * entry. Because the keys are zero-padded "YYYY-MM-DD", a plain string compare
 * orders and spans dates correctly, so coverage tests need no Date parsing.
 *
 * recur is "" for a one-off, "year" for a yearly entry (a birthday: shows on its
 * month and day in every year, matched on the "MM-DD" tail) or "month" (shows on
 * its day in every month, matched on the "DD" tail). A recurring entry ignores its
 * endDate. Day 31 monthly and Feb 29 yearly only land where the day exists, which
 * is fine for now. On load, entries written before this field are classified once:
 * a birthday-looking title becomes yearly, the legacy yearly flag folds into recur,
 * the rest stay one-off, and the healed list is persisted so it sticks.
 *
 * A bare array is simpler than a JsonAdapter for a growing list: read the text,
 * JSON.parse, mutate the array, JSON.stringify back through setText. Every parse
 * is guarded so a truncated or corrupt file never throws and never wipes the
 * singleton — a bad read just leaves the last good `events` in place.
 *
 * Ids come from a monotonic counter seeded past the highest id already on disk,
 * never Date.now() or Math.random() (both throw in this engine), so every add is
 * uniquely addressable for remove() even within the same minute.
 */
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin"

    property var events: []
    property int nextId: 1

    /**
     * Birthday-looking titles across the languages Erik's contacts use, so a new
     * entry can suggest yearly and old ones get classified on load. Plain substring
     * alternation, case-insensitive; accented forms are caught by a safe stem.
     */
    readonly property var birthdayRe: /geburtstag|geb\.|birthday|b-?day|🎂|cumplea|anniversaire|compleanno|anivers|verjaardag|рожд|誕生|생일|urodziny|do[ğg]um/i

    function isBirthday(t) {
        return root.birthdayRe.test(t || "");
    }

    /**
     * Re-read the file text into `events` and advance the id counter past every
     * id present, so a freshly added event can never collide with one loaded
     * from disk. A FileNotFound or malformed body is treated as an empty list.
     * Entries that predate the recurrence field get classified once and the healed
     * list is written back, so existing birthdays become yearly without a re-entry.
     */
    function reloadEvents() {
        var arr = [];
        try {
            var t = file.text();
            if (t && t.trim().length > 0) {
                var parsed = JSON.parse(t);
                if (Array.isArray(parsed))
                    arr = parsed;
            }
        } catch (e) {
            arr = [];
        }
        var maxId = 0;
        var healed = false;
        for (var i = 0; i < arr.length; i++) {
            var n = Number(arr[i].id);
            if (n > maxId)
                maxId = n;
            var e = arr[i];
            if (e.recur === undefined) {
                e.recur = e.yearly === true ? "year" : (root.isBirthday(e.text) ? "year" : "");
                delete e.yearly;
                healed = true;
            }
        }
        root.nextId = maxId + 1;
        root.events = arr;
        if (healed)
            root.persist();
    }

    function persist() {
        file.setText(JSON.stringify(root.events));
    }

    /** Last day an event covers: its endDate, or its start when single-day. */
    function lastDay(e) {
        return e.endDate && e.endDate.length > 0 ? e.endDate : e.date;
    }

    function covers(e, dateStr) {
        if (e.recur === "year")
            return dateStr.slice(5) === e.date.slice(5);
        if (e.recur === "month")
            return dateStr.slice(8) === e.date.slice(8);
        return dateStr >= e.date && dateStr <= root.lastDay(e);
    }

    /** Events covering `dateStr`, sorted by start time; an empty time sorts first. */
    function forDate(dateStr) {
        var out = root.events.filter(function (e) { return root.covers(e, dateStr); });
        out.sort(function (a, b) {
            var at = a.time || "";
            var bt = b.time || "";
            if (at === bt)
                return 0;
            if (at === "")
                return -1;
            if (bt === "")
                return 1;
            return at < bt ? -1 : 1;
        });
        return out;
    }

    function hasEvents(dateStr) {
        for (var i = 0; i < root.events.length; i++) {
            if (root.covers(root.events[i], dateStr))
                return true;
        }
        return false;
    }

    /** Append an event and persist; reassigns `events` so bindings refresh. */
    function add(dateStr, endDate, time, endTime, text, recur) {
        var next = root.events.slice();
        next.push({
            id: root.nextId,
            date: dateStr,
            endDate: endDate || "",
            time: time || "",
            endTime: endTime || "",
            text: text || "",
            recur: recur || ""
        });
        root.nextId += 1;
        root.events = next;
        root.persist();
    }

    function remove(id) {
        root.events = root.events.filter(function (e) { return e.id !== id; });
        root.persist();
    }

    Component.onCompleted: reloadEvents()

    FileView {
        id: file
        path: root.stateDir + "/events.json"
        blockLoading: true
        printErrors: false

        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound)
                file.setText("[]");
        }
    }
}
