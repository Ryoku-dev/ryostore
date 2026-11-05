pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "menu.js" as M
import "../content/urls.js" as Urls

// DragShift's radial drop menu (radial.py RadialMenu), Wayland-native.
//
// Hyprland sees the global mouse and Shift state that Wayland hides from apps,
// so the trigger lives in ~/.config/hypr/user.lua: Shift while the left button
// is held calls `shift(x, y)` here over IPC. The menu is an overlay layer
// surface at the cursor; its slices are drop targets for the drag in progress.
// The backdrop is captured once as it opens (ScreencopyView) and refracted by
// shaders/glass.frag, exactly as radial.py snapshots and renders it.
Scope {
    id: menu

    property bool heif: true
    signal activated(var item, var files)

    // ---- state ---------------------------------------------------------------
    property bool open: false
    property var screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property int wx: 0                     // window top-left, screen-local
    property int wy: 0
    property var paths: []
    property var files: []
    property string text: ""               // dragged text (a highlight), when no files
    property var rings: []
    property int ringIdx: 0
    property int hover: -1
    property var springs: []
    property string hubText: "Drop here"
    property string unsupported: ""
    property bool gotDrag: false
    property bool hubArmed: false
    property bool captured: false
    property real t: 0
    property real swap: 1

    readonly property var items: rings.length > 0 ? rings[ringIdx].items : []
    readonly property var ringNames: rings.map(r => r.name)
    readonly property int size: 400

    // ---- entry points (IPC) ----------------------------------------------------
    function shift(x, y) {
        if (menu.open)
            nextRing();
        else
            show(x, y);
    }

    function show(x, y) {
        const s = _screenAt(x, y);
        if (!s)
            return;
        menu.screen = s;
        menu.wx = Math.round(Math.min(Math.max(x - s.x - size / 2, 0), s.width - size));
        menu.wy = Math.round(Math.min(Math.max(y - s.y - size / 2, 0), s.height - size));
        menu.paths = [];
        menu.files = [];
        menu.text = "";
        menu.rings = [];
        menu.ringIdx = 0;
        menu.hover = -1;
        menu.springs = [];
        menu.hubText = "Drop here";
        menu.unsupported = "";
        menu.gotDrag = false;
        menu.hubArmed = false;
        menu.captured = false;
        menu.t = 0;
        menu.swap = 1;
        menu.open = true;
        noDrag.restart();
        captureTimeout.restart();
    }

    // The left button came up. A drop on a slice has already been handled by
    // then (the compositor delivers the drop before Hyprland's bind runs).
    function release() {
        if (menu.open)
            closeSoon.restart();
    }

    function close() {
        menu.open = false;
        menu.captured = false;
        hubFlip.stop();
        noDrag.stop();
        closeSoon.stop();
        captureTimeout.stop();
    }

    function nextRing() {
        if (menu.rings.length < 2)
            return;
        menu.ringIdx = (menu.ringIdx + 1) % menu.rings.length;
        menu.hover = -1;
        menu.springs = menu.items.map(() => 0);
        swapAnim.restart();
    }

    // ---- helpers ---------------------------------------------------------------
    function _screenAt(x, y) {
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            const s = list[i];
            if (x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height)
                return s;
        }
        return list.length > 0 ? list[0] : null;
    }

    function _load(paths, kinds) {
        const b = M.build(paths, menu.heif, kinds);
        menu.paths = paths;
        menu.files = b.files;
        menu.rings = b.rings;
        menu.ringIdx = 0;
        menu.hover = -1;
        menu.springs = menu.items.map(() => 0);
        if (b.files.length === 0) {
            const e = M.ext(paths[0]);
            menu.unsupported = e ? "." + e : "this file";
        } else {
            menu.unsupported = "";
        }
        // radial.py describe(): the size for one file, a count for several
        if (paths.length > 1) {
            menu.hubText = paths.length + " files";
        } else {
            menu.hubText = M.archiveSuffix(paths[0]).slice(1).toUpperCase() || M.ext(paths[0]).toUpperCase()
                || (b.category === "folder" ? "Folder" : "1 file");
            if (!kinds) {
                sizeProc.running = false;
                sizeProc.command = ["stat", "-L", "-c", "%F|%s", "--", paths[0]];
                sizeProc.running = true;
            }
        }
    }

    function _loadText(text) {
        const b = M.buildText(text);
        menu.text = text;
        menu.paths = [];
        menu.files = [];
        menu.rings = b.rings;
        menu.ringIdx = 0;
        menu.hover = -1;
        menu.springs = menu.items.map(() => 0);
        menu.unsupported = "";
        const n = M.wordCount(text);
        menu.hubText = n === 1 ? "1 word" : n + " words";
    }

    // radial.py hit(): -2 hub, -1 nothing, else the slice index
    function hit(x, y) {
        const dx = x - size / 2;
        const dy = size / 2 - y;
        const d = Math.sqrt(dx * dx + dy * dy);
        if (d <= 50 + 4)
            return -2;
        const n = menu.items.length;
        if (d > 158 + 30 || n === 0)
            return -1;
        const ang = ((Math.atan2(dy, dx) * 180 / Math.PI) % 360 + 360) % 360;
        const rel = (((90 + 180 / n - ang) % 360) + 360) % 360;
        return Math.floor(rel / (360 / n)) % n;
    }

    function _setHover(h) {
        if (h === menu.hover)
            return;
        menu.hover = h;
        if (h >= 0)
            menu.hubArmed = true;   // visited a slice: the hub may now flip rings
        if (h === -2 && menu.hubArmed && menu.rings.length > 1)
            hubFlip.restart();
        else
            hubFlip.stop();
    }

    Process {
        id: sizeProc
        stdout: StdioCollector {
            // "directory|4096" or "regular file|12345": fixes the folder guess
            // for names like "v1.2" or "Makefile", then shows the size.
            onStreamFinished: {
                const parts = String(text).trim().split("|");
                if (menu.paths.length !== 1 || parts.length !== 2)
                    return;
                const isDir = parts[0] === "directory";
                const kinds = {};
                kinds[menu.paths[0]] = isDir ? "dir" : "file";
                const guess = M.category(menu.paths[0]);
                if (guess !== M.category(menu.paths[0], kinds) && menu.hover < 0)
                    menu._load(menu.paths, kinds);
                const n = parseInt(parts[1]);
                if (isDir)
                    menu.hubText = "Folder";
                else if (!isNaN(n))
                    menu.hubText = M.humanSize(n);
            }
        }
    }

    // ---- timers and animation ------------------------------------------------------
    Timer { id: hubFlip; interval: 420; onTriggered: menu.nextRing() }
    // Shift with the button held but no drag ever arriving (a text selection,
    // a stale button state): go away on its own.
    Timer { id: noDrag; interval: 4000; onTriggered: if (!menu.gotDrag) menu.close() }
    Timer { id: closeSoon; interval: 150; onTriggered: menu.close() }
    // never sit invisible: if the capture fails, show the menu anyway
    Timer { id: captureTimeout; interval: 250; onTriggered: if (menu.open && !menu.captured) { menu.captured = true; popAnim.restart(); } }

    NumberAnimation { id: popAnim; target: menu; property: "t"; from: 0; to: 1; duration: 190; easing.type: Easing.OutBack }
    NumberAnimation { id: swapAnim; target: menu; property: "swap"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }

    // the hover springs, eased every frame (radial.py _tick)
    FrameAnimation {
        running: menu.open
        onTriggered: {
            const n = menu.items.length;
            const s = menu.springs.length === n ? menu.springs.slice() : menu.items.map(() => 0);
            let moved = false;
            for (let i = 0; i < n; i++) {
                const target = i === menu.hover ? 1 : 0;
                let v = s[i] + (target - s[i]) * 0.32;
                if (Math.abs(v - target) < 0.003)
                    v = target;
                if (v !== s[i]) {
                    s[i] = v;
                    moved = true;
                }
            }
            if (moved || menu.springs.length !== n)
                menu.springs = s;
        }
    }

    // ---- the window -------------------------------------------------------------
    PanelWindow {
        id: win
        visible: menu.open
        screen: menu.screen
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "dragshift-menu"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true }
        margins { top: menu.wy; left: menu.wx }
        implicitWidth: menu.size
        implicitHeight: menu.size
        // drops land only on the disc, never on the window's corners
        mask: Region { item: disc; shape: RegionShape.Ellipse }

        Item {
            id: disc
            x: menu.size / 2 - (158 + 30)
            y: x
            width: 2 * (158 + 30)
            height: width
        }

        // A fresh one-shot capture per open; our window is fully transparent until
        // it lands, so it never captures itself.
        Loader {
            id: capLoader
            active: menu.open
            sourceComponent: ScreencopyView {
                captureSource: menu.screen
                live: false
                paintCursor: false
                x: -menu.wx
                y: -menu.wy
                width: menu.screen ? menu.screen.width : 0
                height: menu.screen ? menu.screen.height : 0
                onHasContentChanged: {
                    if (hasContent && menu.open && !menu.captured) {
                        menu.captured = true;
                        captureTimeout.stop();
                        popAnim.restart();
                    }
                }
            }
        }
        ShaderEffectSource {
            id: backdrop
            width: menu.size
            height: menu.size
            visible: false
            sourceItem: capLoader.item
            hideSource: true
            sourceRect: Qt.rect(menu.wx, menu.wy, menu.size, menu.size)
            mipmap: true
        }

        MenuView {
            backdrop: capLoader.item && capLoader.item.hasContent ? backdrop : null
            visible: menu.captured
            items: menu.items
            ringNames: menu.ringNames
            ringIdx: menu.ringIdx
            hover: menu.hover
            springs: menu.springs
            hubText: menu.hubText
            unsupported: menu.unsupported
            t: menu.t
            swap: menu.swap
        }

        DropArea {
            anchors.fill: parent
            // Files, or text highlighted in any app and dragged.
            keys: ["text/uri-list", "text/plain", "text/plain;charset=utf-8"]
            // Always Copy: Shift during a drag means Move, and accepting a move
            // would make the file manager delete the original after our drop.
            onEntered: (drag) => {
                menu.gotDrag = true;
                noDrag.stop();
                closeSoon.stop();
                const p = drag.hasUrls ? Urls.toPaths(drag.urls) : [];
                if (p.length > 0) {
                    if (JSON.stringify(p) !== JSON.stringify(menu.paths))
                        menu._load(p);
                } else if (drag.hasText && drag.text !== menu.text) {
                    menu._loadText(drag.text);
                }
                drag.accept(Qt.CopyAction);
            }
            // Off the slices the drop is refused, so letting go there is a clean
            // cancel for the source app instead of a drop nobody takes.
            onPositionChanged: (drag) => {
                const h = menu.hit(drag.x, drag.y);
                menu._setHover(h);
                if (h >= 0)
                    drag.accept(Qt.CopyAction);
                else
                    drag.accepted = false;
            }
            onExited: menu._setHover(-1)
            onDropped: (drop) => {
                const idx = menu.hit(drop.x, drop.y);
                if (idx >= 0 && idx < menu.items.length) {
                    drop.accept(Qt.CopyAction);
                    const item = menu.items[idx];
                    // Text items carry the dragged text in place of file paths.
                    const files = menu.text !== "" ? [menu.text] : (item.all ? menu.paths : menu.files).slice();
                    // hand the drag back to the file manager first, work after
                    Qt.callLater(() => menu.activated(item, files));
                }
                // Never unmap the window inside the drop handler: Qt would drop the
                // offer before telling the source app the drag is over, and that app
                // then stays stuck in "dragging" until it is restarted.
                menu.hover = -1;
                closeSoon.restart();
            }
        }
    }
}
