pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/binds.js" as Binds

/**
 * 場 SPACES store: the single read/writer of ~/.config/hypr/modules/spaces.lua,
 * the user-defined special workspaces the Workspaces settings page creates. Each
 * entry is { id, name, desc, key, glyph, apps[] }: id is the special-workspace
 * name (a slug of the display name), key a single Super-prefixed letter, glyph an
 * optional GlyphIcon name shown beside the row, apps the window classes that
 * auto-route in. `editing` names the space the SpaceApps surface is currently
 * routing apps into.
 *
 * Every change regenerates the whole lua file through an atomic writer; the write
 * fires a debounced `hyprctl reload` so the new spaces, binds and routing take
 * effect, the same path Stash and the keybinds editor use. The reload only runs
 * when the user edits in-app, never on plain load.
 */
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/modules/spaces.lua"
    readonly property string bindsPath: Quickshell.env("HOME") + "/.config/hypr/modules/binds.lua"

    property var list: []
    property string editing: ""

    readonly property string header:
        "-- User-defined special workspaces. The Settings page rewrites this file, so keep\n"
        + "-- each entry on this shape. id is the special-workspace name, key is a single\n"
        + "-- Super-prefixed letter, glyph an optional GlyphIcon name, apps are window\n"
        + "-- classes that auto-route in.\n"

    /** Slug a display name into a lua-safe special-workspace id: lowercase, only [a-z0-9]. */
    function slug(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    /** Strip characters that would unbalance the lua literal or its brace-walk parse. */
    function clean(s) {
        return String(s).replace(/[{}"\\\n\r]/g, "").trim();
    }

    /** The three built-in special ids a custom space must never shadow. */
    function reserved(id) {
        return id === "stash" || id === "private" || id === "minimized";
    }

    /** Pull the fields out of one `{ ... }` entry block. Null when it has no id. */
    function parseEntry(block) {
        var id = root.field(block, "id");
        if (id.length === 0)
            return null;
        var apps = [];
        var am = block.match(/apps\s*=\s*{([^}]*)}/);
        if (am) {
            var re = /"([^"]*)"/g;
            var m;
            while ((m = re.exec(am[1])) !== null)
                if (m[1].length > 0)
                    apps.push(m[1]);
        }
        return {
            id: id,
            name: root.field(block, "name") || id,
            desc: root.field(block, "desc"),
            key: root.field(block, "key"),
            glyph: root.field(block, "glyph"),
            apps: apps
        };
    }

    function field(block, key) {
        var m = block.match(new RegExp("\\b" + key + "\\s*=\\s*\"([^\"]*)\""));
        return m ? m[1] : "";
    }

    /**
     * Walk the `return { ... }` table brace by brace, slicing every top-level
     * entry block (depth 2) and parsing it. The nested apps `{ ... }` sits at
     * depth 3 so it never opens a spurious entry.
     */
    function parse(text) {
        var ri = text.indexOf("return");
        var body = ri >= 0 ? text.slice(ri) : text;
        var ob = body.indexOf("{");
        if (ob < 0)
            return [];
        var out = [];
        var depth = 0;
        var start = -1;
        for (var i = ob; i < body.length; i++) {
            var c = body[i];
            if (c === "{") {
                depth++;
                if (depth === 2)
                    start = i;
            } else if (c === "}") {
                if (depth === 2 && start >= 0) {
                    var e = root.parseEntry(body.slice(start, i + 1));
                    if (e)
                        out.push(e);
                    start = -1;
                }
                depth--;
                if (depth === 0)
                    break;
            }
        }
        return out;
    }

    function fileText(arr) {
        var body = "return {\n";
        for (var i = 0; i < arr.length; i++) {
            var e = arr[i];
            var apps = "";
            var src = e.apps || [];
            for (var j = 0; j < src.length; j++)
                apps += (j ? ", " : "") + "\"" + src[j] + "\"";
            var appsStr = src.length ? "{ " + apps + " }" : "{}";
            body += "\t{ id = \"" + e.id + "\", name = \"" + e.name + "\", desc = \""
                + (e.desc || "") + "\", key = \"" + (e.key || "") + "\""
                + (e.glyph && e.glyph.length ? ", glyph = \"" + e.glyph + "\"" : "")
                + ", apps = " + appsStr + " },\n";
        }
        body += "}\n";
        return root.header + body;
    }

    function refresh() {
        root.list = root.parse(spacesFile.text());
    }

    function commit(arr) {
        writer.setText(root.fileText(arr));
    }

    function addSpace(name, desc, key) {
        var id = root.slug(name);
        if (id.length === 0 || root.reserved(id))
            return;
        for (var i = 0; i < root.list.length; i++)
            if (root.list[i].id === id)
                return;
        var next = root.list.slice();
        next.push({ id: id, name: root.clean(name), desc: root.clean(desc), key: root.clean(key), glyph: "", apps: [] });
        root.commit(next);
    }

    function removeSpace(id) {
        var next = root.list.filter(function (e) { return e.id !== id; });
        if (next.length !== root.list.length)
            root.commit(next);
    }

    /**
     * Rename a space and set its glyph in place; id, key and apps stay, so the
     * binds and routing spaces-apply regenerates on reload are untouched and the
     * pill's active-space label picks the new name up on the next list refresh.
     * A built-in (stash/private/minimized) has no entry of its own: the first
     * edit creates one holding display data only. Its empty key and apps keep
     * spaces-apply inert for it, so the built-in's own config stays the only
     * source of binds and rules.
     */
    function updateSpace(id, name, glyph) {
        name = root.clean(name);
        if (name.length === 0)
            return;
        var next = root.list.slice();
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                next[i] = { id: id, name: name, desc: next[i].desc, key: next[i].key, glyph: root.clean(glyph), apps: next[i].apps };
                root.commit(next);
                return;
            }
        }
        if (!root.reserved(id))
            return;
        next.push({ id: id, name: name, desc: "", key: "", glyph: root.clean(glyph), apps: [] });
        root.commit(next);
    }

    /**
     * Rebind a custom space's trigger letter; spaces-apply regenerates both the
     * toggle and the send/retrieve bind from it on the reload commit fires.
     * Built-ins are refused: their binds live in binds.lua (the Keybinds surface
     * owns those), and writing a key onto a display-only override would add a
     * second toggle instead of moving the first.
     */
    function updateKey(id, key) {
        key = root.clean(key).toUpperCase();
        if (!/^[A-Z]$/.test(key) || root.reserved(id))
            return;
        var next = root.list.slice();
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                next[i] = { id: next[i].id, name: next[i].name, desc: next[i].desc, key: key, glyph: next[i].glyph, apps: next[i].apps };
                root.commit(next);
                return;
            }
        }
    }

    function addApp(id, cls) {
        cls = root.clean(cls);
        if (cls.length === 0)
            return;
        var next = root.list.slice();
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                var apps = (next[i].apps || []).slice();
                for (var j = 0; j < apps.length; j++)
                    if (apps[j] === cls)
                        return;
                apps.push(cls);
                next[i] = { id: next[i].id, name: next[i].name, desc: next[i].desc, key: next[i].key, glyph: next[i].glyph, apps: apps };
                root.commit(next);
                return;
            }
        }
    }

    function removeApp(id, cls) {
        var next = root.list.slice();
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                var apps = (next[i].apps || []).filter(function (a) { return a !== cls; });
                next[i] = { id: next[i].id, name: next[i].name, desc: next[i].desc, key: next[i].key, glyph: next[i].glyph, apps: apps };
                root.commit(next);
                return;
            }
        }
    }

    /**
     * True when SUPER+key would clash: another space already holds it, it is one
     * of the built-in special keys (S/P/M), or binds.lua already binds it.
     * `exceptId` skips one entry, so re-capturing a row's own key is no clash.
     */
    function keyTaken(key, exceptId) {
        if (!key || key.length === 0)
            return false;
        var k = key.toUpperCase();
        if (k === "S" || k === "P" || k === "M")
            return true;
        for (var i = 0; i < root.list.length; i++)
            if (root.list[i].id !== exceptId && root.list[i].key && root.list[i].key.toUpperCase() === k)
                return true;
        return Binds.inUse(bindsFile.text(), "SUPER + " + k, -1);
    }

    FileView {
        id: spacesFile
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.refresh()
        onFileChanged: reload()
    }

    FileView {
        id: bindsFile
        path: root.bindsPath
        blockLoading: true
        watchChanges: true
        printErrors: false
    }

    FileView {
        id: writer
        path: root.path
        atomicWrites: true
        printErrors: false
        onSaved: {
            reloadProc.running = true;
            spacesFile.reload();
            root.refresh();
        }
        onSaveFailed: (err) => console.log("spaces: write failed: " + err)
    }

    Process {
        id: reloadProc
        command: ["setsid", "-f", "sh", "-c", "sleep 0.4; hyprctl reload"]
    }

    Component.onCompleted: root.refresh()
}
