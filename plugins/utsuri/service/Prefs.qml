import QtQuick
import Quickshell.Io
import Ryoku.PluginKit.Singletons
import "themes.js" as Themes

// The Customize page's choices, kept in <dir>/prefs.json: the theme id and the
// option keys turned off (menu.js itemKey). A missing, empty or broken file, an
// unknown theme or a hidden list that is not a list all mean the defaults:
// Transparent with every option on. Nothing here can throw at the views.
//
// _theme and _hidden are the truth. The file is parsed by hand once at start and
// rewritten whole on every change: Quickshell's JsonAdapter hands lists back as
// array-likes that are not JS Arrays and can return stale values right after a
// write, which lost turned-off options on restart and quick toggles on disk.
Item {
    id: prefs

    property string dir: ""                 // the plugin's stateDir

    property string _theme: "transparent"
    property var _hidden: []

    readonly property string themeId: Themes.byId(prefs._theme).id
    // Re-evaluates whenever Ryoku's scheme changes (resolve reads Theme's colours),
    // so Matugen follows the wallpaper live.
    readonly property var look: Themes.resolve(prefs.themeId, Theme)
    readonly property var hidden: prefs._hidden

    // Any array-like of strings -> a plain Array of those strings; anything else -> [].
    function toList(v) {
        if (!v || typeof v === "string" || typeof v.length !== "number")
            return [];
        const out = [];
        for (let i = 0; i < v.length; i++)
            if (typeof v[i] === "string" && out.indexOf(v[i]) === -1)
                out.push(v[i]);
        return out;
    }

    function _save() {
        if (file.path !== "")
            file.setText(JSON.stringify({ theme: prefs._theme, hidden: prefs._hidden }, null, 2) + "\n");
    }
    function setTheme(id) {
        prefs._theme = Themes.byId(id).id;
        prefs._save();
    }
    function isHidden(key) {
        return prefs._hidden.indexOf(key) !== -1;
    }
    function setHidden(key, off) {
        const now = prefs._hidden.filter(k => k !== key);
        if (off)
            now.push(key);
        prefs._hidden = now;
        prefs._save();
    }
    function showAll() {
        prefs._hidden = [];
        prefs._save();
    }

    FileView {
        id: file
        path: prefs.dir !== "" ? prefs.dir + "/prefs.json" : ""
        printErrors: false
        blockLoading: true
        // Read once at start, then only written. Watching it would reload our own
        // writes mid-toggle. Only Utsuri writes it.
        onLoaded: {
            let d = null;
            try {
                d = JSON.parse(file.text());
            } catch (e) {
                d = null;
            }
            prefs._theme = (d && typeof d.theme === "string") ? Themes.byId(d.theme).id : "transparent";
            prefs._hidden = prefs.toList(d ? d.hidden : null);
        }
    }
}
