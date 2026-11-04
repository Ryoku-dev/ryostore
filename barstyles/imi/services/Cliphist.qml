pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../modules/common"
import "../modules/common/functions"
import shell.services as HostServices

// Clipboard history for the launcher and the clipboard island, over the Ryoku
// daemon's clipboard topic. The daemon owns the history; this maps its entries
// into the line format the bar's widgets expect ("id\ttext", images with the
// [[ binary data ... ]] marker) and sends copy/delete/star intents back by id.
Singleton {
    id: root

    // Compatibility for the image-decode call sites (CliphistImage, AiChat): they
    // build a `decode <id>` command from this. The daemon exposes thumbnails but
    // no full-image fetch, so decoding only works where the cliphist binary and
    // its own store happen to exist.
    property string cliphistBinary: "cliphist"

    /**
     * Image entries already decoded to a file, keyed by that file's path.
     *
     * Filled in place by CliphistImage and never reassigned, so nothing re-evaluates
     * when it grows. It lives as long as the files do: the decode directory is emptied
     * when the shell starts, which is also when this is.
     */
    readonly property var decodedImages: ({})

    // Host frames newest-first.
    readonly property var _hostEntries: HostServices.Clipboard.entries || []
    property list<string> entries: root._renderEntries(root._hostEntries)

    readonly property var preparedEntries: entries.slice(0, 150).map(a => ({
        name: Fuzzy.prepare(`${a.replace(/^\s*\S+\s+/, "")}`),
        entry: a
    }))

    // "the history changed" and "the user copied something" are different events;
    // surfaces that notify the user must only hear the second. A bigger id is the
    // only proof a new entry was stored, and the content must differ too: re-offering
    // the same selection (unlocking the session) also re-inserts it.
    signal entryAdded(string entry)

    property int _idWatermark: -1
    property string _lastAnnounced: ""

    readonly property var pinnedEntries: root._hostEntries
        .filter(entry => entry && entry.starred === true)
        .map(entry => root._renderEntry(entry))

    function _renderEntry(entry) {
        if (!entry)
            return "";
        const id = String(entry.id ?? "");
        if (String(entry.kind ?? "") === "image") {
            const w = Number(entry.w) || Number(entry.thumbW) || 0;
            const h = Number(entry.h) || Number(entry.thumbH) || 0;
            return `${id}\t[[ binary data ${entry.mime ?? "image"} ${w}x${h} ]]`;
        }
        if (String(entry.kind ?? "") === "binary")
            return `${id}\t[[ binary data ${entry.mime ?? ""} ${Number(entry.size) || 0} bytes ]]`;
        return `${id}\t${String(entry.preview ?? "")}`;
    }

    function _renderEntries(hostEntries) {
        return (hostEntries || []).map(entry => root._renderEntry(entry));
    }

    function _hostEntryOf(entryString) {
        const id = Number(root.entryKey(entryString));
        if (!isFinite(id) || id <= 0)
            return null;
        return root._hostEntries.find(entry => Number(entry?.id) === id) ?? null;
    }

    on_HostEntriesChanged: root._noteTopEntry()

    function _noteTopEntry() {
        // Read from the frames, not the `entries` binding: the handler can run
        // while that list is still catching up.
        const top = root._renderEntries(root._hostEntries)[0] ?? "";
        const id = Number(root.entryKey(top) || -1);
        if (id < 0)
            return;
        const clean = root._cleanEntry(top);
        const firstRead = root._idWatermark < 0;
        const idGrew = id > root._idWatermark;
        if (idGrew)
            root._idWatermark = id;
        // The first read only seeds the baseline, in silence.
        if (firstRead) {
            root._lastAnnounced = clean;
            return;
        }
        if (!idGrew || clean === root._lastAnnounced)
            return;
        root._lastAnnounced = clean;
        root.entryAdded(top);
    }

    function _cleanEntry(entry) {
        return String(entry ?? "").replace(/^\d+\t/, "");
    }

    function entryKey(entry) {
        return String(entry ?? "").match(/^(\d+)\t/)?.[1] ?? "";
    }

    function entryIsImage(entry) {
        return !!(/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry));
    }

    function isPinned(entry) {
        return root._hostEntryOf(entry)?.starred === true;
    }

    function pin(entry) {
        const hostEntry = root._hostEntryOf(entry);
        if (hostEntry && hostEntry.starred !== true)
            HostServices.Clipboard.star(Number(hostEntry.id), true);
    }

    function unpin(entry) {
        const hostEntry = root._hostEntryOf(entry);
        if (hostEntry && hostEntry.starred === true)
            HostServices.Clipboard.star(Number(hostEntry.id), false);
    }

    /**
     * Classify clipboard entry content for smart rendering.
     * Returns: "hex-color", "url", "email", "phone", "json", "markdown", "filepath", "multiline", "number", or ""
     */
    function classifyEntry(entry) {
        if (!entry) return "";
        // Strip the id prefix
        const content = root._cleanEntry(entry).trim();
        if (content.length === 0) return "";

        const detectors = Config.options?.search?.clipboard?.detectors;

        // Hex color
        if (detectors?.hexColor !== false && /^#([0-9A-Fa-f]{3,4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(content))
            return "hex-color";

        // URL
        if (detectors?.url !== false && /^https?:\/\/\S+/.test(content))
            return "url";

        // Email
        if (detectors?.email !== false && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(content))
            return "email";

        // Phone
        if (detectors?.phone !== false && /^\+?[\d\s\-()]{7,}$/.test(content))
            return "phone";

        // JSON
        if (detectors?.json !== false && (content.startsWith("{") || content.startsWith("["))) {
            try {
                const parsed = JSON.parse(content);
                if (typeof parsed === "object") return "json";
            } catch (e) {}
        }

        // File path
        if (detectors?.filePath !== false && /^(\/|~\/)[^\s]+/.test(content))
            return "filepath";

        // Markdown
        if (detectors?.markdown !== false && /^(#{1,6}\s|>\s|\*\*|__|- \[[ x]\]|- )/.test(content))
            return "markdown";

        // Number
        if (detectors?.number !== false && /^-?[\d,. ]+$/.test(content) && content.replace(/[\s,._]/g, "").length > 0)
            return "number";

        // Multiline
        if (detectors?.multiline !== false) {
            const lineCount = (content.match(/\n/g) || []).length;
            if (lineCount >= 2) return "multiline";
        }

        return "";
    }

    function fuzzyQuery(search: string): var {
        if (search.trim() === "") {
            return entries;
        }
        const results = Fuzzy.go(search, preparedEntries, {
            limit: 100,
            key: "name"
        }).map(r => {
            return r.obj.entry;
        });
        return results;
    }

    // Re-sets the Wayland selection to this entry. Accepts a rendered line, the
    // bare preview text of a pinned entry, or anything carrying a known id.
    function copy(entry) {
        if (!entry) return;
        let hostEntry = root._hostEntryOf(entry);
        if (!hostEntry) {
            const clean = root._cleanEntry(entry);
            hostEntry = root._hostEntries.find(candidate => String(candidate?.preview ?? "") === clean) ?? null;
        }
        if (hostEntry)
            HostServices.Clipboard.copy(Number(hostEntry.id));
        else if (!root.entryIsImage(entry))
            Quickshell.execDetached(["wl-copy", root._cleanEntry(entry)]);
    }

    function deleteEntry(entry) {
        if (!entry) return;
        const hostEntry = root._hostEntryOf(entry);
        if (!hostEntry) return;
        if (hostEntry.starred === true)
            HostServices.Clipboard.star(Number(hostEntry.id), false);
        HostServices.Clipboard.del(Number(hostEntry.id));
    }

    function wipe() {
        HostServices.Clipboard.clear();
    }

    // The daemon cannot type into the focused window, so "paste N" becomes "put
    // the newest N back on the selection in order"; the newest wins and the user
    // pastes normally.
    function superpaste(count, isImage = false) {
        const targetEntries = root._hostEntries.filter(entry => {
            if (!entry) return false;
            if (!isImage) return true;
            return String(entry.kind ?? "") === "image";
        }).slice(0, count);
        for (let i = targetEntries.length - 1; i >= 0; --i)
            HostServices.Clipboard.copy(Number(targetEntries[i].id));
    }
}
